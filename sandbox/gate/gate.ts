// Sandbox gate (TASK-042, decision-015). A sandbox sits on an internal Docker network with no route out; this is
// the one container that joins both that network and the default bridge, so it is the only way in or out.
//   - Forward proxy (HTTP with absolute URLs, and CONNECT): public destinations on the allowed ports only. The gate
//     resolves the name itself, refuses it when any address is not public, and connects to the address it checked,
//     so a second DNS answer cannot point the connection somewhere else.
//   - The router's address is private, so the proxy never connects to it. The gate passes it on itself instead,
//     in the clear, on a port of its own and through the proxy as gate:4000 (OpenClaw sends all non-loopback traffic
//     to the proxy, as CONNECT tunnels; a tunnel to gate:4000 ends at that same port, which reads every request), so it can drop identity and forwarding headers (the router lets a Tailscale login
//     header in, and a sandbox could set one itself) and mark each request as coming from a sandbox. What a sandbox
//     may do there is the router's call (config/custom_auth.py: its own key, local models only).
//   - TCP forwards from the gate's published ports into the sandbox (the Control UI).
//   - DNS for the sandbox that never looks anything up: every name gets one placeholder address (FAKE_IP). OpenClaw
//     checks a name before its browser opens it; the browser then hands the name to the proxy, which resolves it
//     for real. No query leaves the gate, so DNS is no way out either.
// Logs one JSON line per proxied connection: destination, verdict, reason; for the router, method, path and status.
// Never headers, bodies or the paths of other sites.
import dgram from 'node:dgram';
import dns from 'node:dns/promises';
import http from 'node:http';
import net from 'node:net';

const blocked = new net.BlockList();
// IPv4 and IPv6 ranges that are not the public internet: this host, private and carrier-grade NAT (the tailnet),
// link-local, documentation and benchmark ranges, multicast, reserved; Docker Desktop's 192.168.65.0/24 is private.
// IPv6 forms that embed an IPv4 address (mapped, NAT64, 6to4, Teredo) are refused outright.
for (const [a, p] of [['0.0.0.0', 8], ['10.0.0.0', 8], ['100.64.0.0', 10], ['127.0.0.0', 8], ['169.254.0.0', 16],
  ['172.16.0.0', 12], ['192.0.0.0', 24], ['192.0.2.0', 24], ['192.88.99.0', 24], ['192.168.0.0', 16], ['198.18.0.0', 15],
  ['198.51.100.0', 24], ['203.0.113.0', 24], ['224.0.0.0', 4], ['240.0.0.0', 4]] as const) blocked.addSubnet(a, p, 'ipv4');
for (const [a, p] of [['::', 127], ['64:ff9b::', 96], ['64:ff9b:1::', 48], ['100::', 64],
  ['2001::', 32], ['2001:db8::', 32], ['2002::', 16], ['fc00::', 7], ['fe80::', 10], ['fec0::', 10], ['ff00::', 8]] as const) blocked.addSubnet(a, p, 'ipv6');

// Kept apart: BlockList also checks IPv4 addresses against IPv4-mapped IPv6 rules, so this one would block all of IPv4.
const mapped = new net.BlockList();
mapped.addSubnet('::ffff:0:0', 96, 'ipv6');

export function isPublic(ip: string): boolean {
  const v = net.isIP(ip);
  if (v === 4) return !blocked.check(ip, 'ipv4');
  return v === 6 && !mapped.check(ip, 'ipv6') && !blocked.check(ip, 'ipv6');
}

export async function resolveAll(host: string): Promise<string[]> {
  return (await dns.lookup(host, { all: true, order: 'ipv4first' })).map((a) => a.address);
}

export interface Verdict { ok: boolean; ip?: string; reason: string }
export interface LogEvent { via: 'http' | 'connect'; host: string; port: number; ok: boolean; reason: string }
export interface GateOptions {
  ports?: number[];
  // the gate's own router pass, asked for through the proxy: absolute URLs go to handle, tunnels to 127.0.0.1:tunnelTo
  local?: { hosts: string[]; port: number; handle: RouterHandler; tunnelTo: number };                                  // destination ports allowed on the internet
  // named containers on the sandbox network the sandbox may reach through the proxy, "host:port" (TASK-043: the
  // Google relay and MCP server); private addresses are fine for these exact pairs and nothing else
  services?: string[];
  resolve?: (host: string) => Promise<string[]>;
  isPublic?: (ip: string) => boolean;
  log?: (e: LogEvent) => void;
}

// hop-by-hop headers are the proxy's own business and are not passed on
const HOP = ['connection', 'proxy-connection', 'keep-alive', 'proxy-authorization', 'proxy-authenticate', 'te', 'trailer', 'transfer-encoding', 'upgrade'];
function endToEnd(h: http.IncomingHttpHeaders): http.OutgoingHttpHeaders {
  const out: http.OutgoingHttpHeaders = { ...h };
  for (const k of HOP) delete out[k];
  return out;
}

export function createGate(o: GateOptions): http.Server {
  const ports = o.ports ?? [80, 443];
  const services = new Set((o.services ?? []).map((x) => x.toLowerCase()));
  const resolve = o.resolve ?? resolveAll;
  const pub = o.isPublic ?? isPublic;
  const log = o.log ?? ((e: LogEvent) => console.log(JSON.stringify({ t: new Date().toISOString(), ...e })));

  async function decide(rawHost: string, port: number): Promise<Verdict> {
    const host = rawHost.toLowerCase().replace(/^\[|\]$/g, '').replace(/\.$/, '');
    let ips: string[];
    if (services.has(`${host}:${port}`)) {
      try { ips = await resolve(host); } catch { return { ok: false, reason: 'no address' }; }
      return ips.length ? { ok: true, ip: ips[0], reason: 'service' } : { ok: false, reason: 'no address' };
    }
    if (!ports.includes(port)) return { ok: false, reason: `port ${port} not allowed` };
    try { ips = net.isIP(host) ? [host] : await resolve(host); } catch { return { ok: false, reason: 'no address' }; }
    if (ips.length === 0) return { ok: false, reason: 'no address' };
    const bad = ips.find((ip) => !pub(ip));
    if (bad) return { ok: false, reason: `not public: ${bad}` };
    return { ok: true, ip: ips[0], reason: 'public' };
  }

  // Generations through the router can take many minutes: no request timeout, only one for the headers.
  const server = http.createServer({ requestTimeout: 0, headersTimeout: 60_000 });

  server.on('request', async (req, res) => {
    const deny = (code: number, why: string) => { res.writeHead(code, { 'content-type': 'text/plain', connection: 'close' }).end(`gate: ${why}\n`); };
    let url: URL;
    try { url = new URL(req.url ?? ''); } catch { deny(400, 'this is a proxy: send absolute URLs'); return; }
    if (url.protocol !== 'http:') { deny(400, `${url.protocol} is not proxied in the clear: use CONNECT`); return; }
    const port = Number(url.port || 80);
    if (o.local && port === o.local.port && o.local.hosts.includes(url.hostname.toLowerCase())) { o.local.handle(req, res, url.pathname + url.search); return; }
    const v = await decide(url.hostname, port);
    log({ via: 'http', host: url.hostname, port, ok: v.ok, reason: v.reason });
    if (!v.ok) { deny(403, v.reason); return; }
    const up = http.request({ host: v.ip, port, method: req.method, path: url.pathname + url.search, headers: endToEnd(req.headers), setHost: false }, (r) => {
      res.writeHead(r.statusCode ?? 502, r.statusMessage, endToEnd(r.headers));
      r.pipe(res);
    });
    up.on('error', () => { if (res.headersSent) res.destroy(); else deny(502, 'upstream unreachable'); });
    req.on('error', () => up.destroy());
    res.on('close', () => up.destroy());
    req.pipe(up);
  });

  server.on('connect', async (req: http.IncomingMessage, socket: net.Socket, head: Buffer) => {
    socket.on('error', () => {});
    const m = /^(\[[^\]]+\]|[^:]+):(\d+)$/.exec(req.url ?? '');
    if (!m) { socket.end('HTTP/1.1 400 Bad Request\r\nconnection: close\r\n\r\n'); return; }
    const port = Number(m[2]);
    const isLocal = !!o.local && port === o.local.port && o.local.hosts.includes(m[1].toLowerCase());
    const v: Verdict = isLocal ? { ok: true, ip: '127.0.0.1', reason: 'router pass' } : await decide(m[1], port);
    log({ via: 'connect', host: m[1], port, ok: v.ok, reason: v.reason });
    if (!v.ok) { socket.end(`HTTP/1.1 403 Forbidden\r\ncontent-type: text/plain\r\nconnection: close\r\n\r\ngate: ${v.reason}\n`); return; }
    const up = net.connect(isLocal ? o.local!.tunnelTo : port, v.ip!, () => {
      socket.write('HTTP/1.1 200 Connection Established\r\n\r\n');
      if (head.length) up.write(head);
      up.pipe(socket);
      socket.pipe(up);
    });
    up.on('error', () => { if (up.connecting) socket.end('HTTP/1.1 502 Bad Gateway\r\nconnection: close\r\n\r\n'); else socket.destroy(); });
    socket.on('close', () => up.destroy());
  });

  return server;
}

// The router, for a sandbox: /v1/ paths only, without identity or forwarding headers, marked as from a sandbox.
export const SANDBOX_MARK = 'x-local-ai-sandbox';
const DROP = /^(tailscale-|x-forwarded-|forwarded$|x-real-ip$|x-local-ai-)/;
export interface RouterLogEvent { via: 'router'; method: string; path: string; status: number }
export type RouterHandler = (req: http.IncomingMessage, res: http.ServerResponse, path: string) => void;
export function routerHandler(o: { target: { host: string; port: number }; log?: (e: RouterLogEvent) => void }): RouterHandler {
  const log = o.log ?? ((e: RouterLogEvent) => console.log(JSON.stringify({ t: new Date().toISOString(), ...e })));
  return (req, res, path) => {
    const deny = (code: number, why: string) => {
      log({ via: 'router', method: req.method ?? '', path: path.slice(0, 200), status: code });
      res.writeHead(code, { 'content-type': 'text/plain', connection: 'close' }).end(`gate: ${why}\n`);
    };
    // dot segments, encoded or doubled slashes and backslashes could be read as another route by the router
    if (!path.startsWith('/v1/') || /\.\.|%2e|%2f|%5c|\\|\/\//i.test(path)) { deny(403, 'only /v1/ paths'); return; }
    const headers = endToEnd(req.headers);
    for (const k of Object.keys(headers)) if (DROP.test(k)) delete headers[k];
    headers.host = `${o.target.host}:${o.target.port}`;
    headers[SANDBOX_MARK] = '1';
    const up = http.request({ host: o.target.host, port: o.target.port, method: req.method, path, headers }, (r) => {
      log({ via: 'router', method: req.method ?? '', path: path.split('?')[0], status: r.statusCode ?? 0 });
      res.writeHead(r.statusCode ?? 502, r.statusMessage, endToEnd(r.headers));
      r.pipe(res);
    });
    up.on('error', () => { if (res.headersSent) res.destroy(); else deny(502, 'router unreachable'); });
    req.on('error', () => up.destroy());
    res.on('close', () => up.destroy());
    req.pipe(up);
  };
}
export function createRouterPass(handle: RouterHandler): http.Server {
  const server = http.createServer({ requestTimeout: 0, headersTimeout: 60_000 });
  server.on('request', (req, res) => handle(req, res, req.url ?? ''));
  return server;
}

// RFC 2544 benchmark range: never a real destination, and refused by the proxy if anything connects to it directly
export const FAKE_IP = '198.18.0.1';

// The answer to one DNS query: the first question echoed, an A record with FAKE_IP for A questions, no records
// (NOERROR) for any other type. Undefined for anything that is not a well-formed standard query.
export function fakeDnsAnswer(q: Buffer): Buffer | undefined {
  if (q.length < 12 || (q[2] & 0xf8) !== 0 || q.readUInt16BE(4) < 1) return undefined;   // a query, opcode 0, >= 1 question
  let i = 12;
  while (i < q.length && q[i] !== 0) { if ((q[i] & 0xc0) !== 0) return undefined; i += q[i] + 1; }
  if (i + 5 > q.length) return undefined;
  const qtype = q.readUInt16BE(i + 1);
  const question = q.subarray(12, i + 5);
  const head = Buffer.alloc(12);
  head.writeUInt16BE(q.readUInt16BE(0), 0);                // same id
  head.writeUInt16BE(0x8000 | (q[2] & 0x01) << 8 | 0x80, 2);   // response, recursion desired as asked, available, NOERROR
  head.writeUInt16BE(1, 4);                                // one question
  if (qtype !== 1) return Buffer.concat([head, question]);
  head.writeUInt16BE(1, 6);                                // one answer
  const answer = Buffer.from([0xc0, 0x0c, 0, 1, 0, 1, 0, 0, 0, 60, 0, 4, ...FAKE_IP.split('.').map(Number)]);
  return Buffer.concat([head, question, answer]);
}

export function createFakeDns(): dgram.Socket {
  const sock = dgram.createSocket('udp4');
  sock.on('message', (msg, from) => { const a = fakeDnsAnswer(msg); if (a) sock.send(a, from.port, from.address); });
  return sock;
}

// Plain TCP into the sandbox network, whatever the protocol (HTTP and WebSocket for the Control UI).
export function createForward(target: { host: string; port: number }): net.Server {
  return net.createServer((client) => {
    const up = net.connect(target.port, target.host);
    client.pipe(up);
    up.pipe(client);
    client.on('error', () => up.destroy());
    up.on('error', () => client.destroy());
    client.on('close', () => up.destroy());
    up.on('close', () => client.destroy());
  });
}

// "18789=openclaw-owner:18789,18790=openclaw-alice:18789"
export function parseForwards(spec: string): { listen: number; host: string; port: number }[] {
  return spec.split(',').map((s) => s.trim()).filter(Boolean).map((s) => {
    const m = /^(\d+)=([a-z0-9.-]+):(\d+)$/i.exec(s);
    if (!m) throw new Error(`bad forward "${s}": use <listen port>=<host>:<port>`);
    return { listen: Number(m[1]), host: m[2], port: Number(m[3]) };
  });
}
