// Gate tests on loopback: a fake resolver names the destinations, and the test's own servers stand in for the
// internet (127.0.0.1 counts as "public" here) and for the router.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import net from 'node:net';
import type { AddressInfo } from 'node:net';
import { FAKE_IP, SANDBOX_MARK, createFakeDns, createForward, fakeDnsAnswer, createGate, createRouterPass, isPublic, parseForwards, routerHandler } from './gate.ts';
import type { LogEvent, RouterLogEvent } from './gate.ts';

const listen = (s: net.Server) => new Promise<number>((r) => s.listen(0, '127.0.0.1', () => r((s.address() as AddressInfo).port)));
// echoes what reached it: method, path, the Host header and whether a proxy credential leaked through
const echo = http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => { body += c; });
  req.on('end', () => res.end(JSON.stringify({ method: req.method, url: req.url, host: req.headers.host, proxyAuth: req.headers['proxy-authorization'] ?? null, body })));
});
// the router stand-in answers with the path and the headers that reached it
const routerSrv = http.createServer((req, res) => res.end(JSON.stringify({ url: req.url, headers: req.headers })));
const logs: LogEvent[] = [];
const routerLogs: RouterLogEvent[] = [];
let web = 0, router = 0, proxy = 0, pass = 0;
let gate: http.Server, routerPass: http.Server;

const NAMES: Record<string, string[]> = {
  'public.example': ['127.0.0.1'], 'lan.example': ['192.168.1.1'], 'mixed.example': ['127.0.0.1', '10.0.0.5'],
};

before(async () => {
  web = await listen(echo);
  router = await listen(routerSrv);
  const toRouter = routerHandler({ target: { host: '127.0.0.1', port: router }, log: (e) => routerLogs.push(e) });
  routerPass = createRouterPass(toRouter);
  pass = await listen(routerPass);
  gate = createGate({
    ports: [web], local: { hosts: ['gate'], port: 4000, handle: toRouter, tunnelTo: pass },
    resolve: async (h) => { if (!NAMES[h]) throw new Error('ENOTFOUND'); return NAMES[h]; },
    isPublic: (ip) => ip === '127.0.0.1', log: (e) => logs.push(e),
  });
  proxy = await listen(gate);
});
after(() => { gate.close(); routerPass.close(); echo.close(); routerSrv.close(); });

// one request through the proxy with an absolute URL
function viaProxy(url: string, init: { method?: string; body?: string; headers?: Record<string, string> } = {}) {
  return new Promise<{ status: number; body: string }>((resolve, reject) => {
    const req = http.request({ host: '127.0.0.1', port: proxy, path: url, method: init.method ?? 'GET', headers: { host: new URL(url).host, ...init.headers } }, (res) => {
      let b = ''; res.on('data', (c) => { b += c; }); res.on('end', () => resolve({ status: res.statusCode ?? 0, body: b }));
    });
    req.on('error', reject);
    req.end(init.body);
  });
}
// CONNECT, then (when let through) a plain HTTP GET inside the tunnel
function tunnel(target: string, inner = `GET /in-tunnel HTTP/1.1\r\nhost: ${target}\r\nconnection: close\r\n\r\n`) {
  return new Promise<{ status: number; inner?: string }>((resolve, reject) => {
    const req = http.request({ host: '127.0.0.1', port: proxy, method: 'CONNECT', path: target });
    req.on('connect', (res, sock) => {
      if (res.statusCode !== 200) { sock.destroy(); resolve({ status: res.statusCode ?? 0 }); return; }
      let b = '';
      sock.on('data', (c) => { b += c; });
      sock.on('end', () => resolve({ status: 200, inner: b }));
      sock.write(inner);
    });
    req.on('error', reject);
    req.end();
  });
}

test('which addresses count as public', () => {
  for (const ip of ['93.184.215.14', '1.1.1.1', '2606:4700:4700::1111']) assert.equal(isPublic(ip), true, ip);
  for (const ip of ['127.0.0.1', '10.1.2.3', '172.17.0.1', '192.168.65.254', '192.168.1.1', '100.101.127.111', '169.254.169.254',
    '0.0.0.0', '224.0.0.1', '::1', '::', 'fd7a:115c:a1e0::1', 'fe80::1', '::ffff:127.0.0.1', '64:ff9b::a00:1', '2002:c0a8:101::1', 'not-an-ip'])
    assert.equal(isPublic(ip), false, ip);
});

test('HTTP: a public site is reached, with its Host and without the proxy credential', async () => {
  const r = await viaProxy(`http://public.example:${web}/page?q=1`, { method: 'POST', body: 'hello', headers: { 'proxy-authorization': 'Basic eDp5' } });
  assert.equal(r.status, 200);
  assert.deepEqual(JSON.parse(r.body), { method: 'POST', url: '/page?q=1', host: `public.example:${web}`, proxyAuth: null, body: 'hello' });
});

test('HTTP: private names and addresses, other ports and unknown names are refused', async () => {
  for (const [url, why] of [
    [`http://lan.example:${web}/`, 'not public: 192.168.1.1'], [`http://mixed.example:${web}/`, 'not public: 10.0.0.5'],
    [`http://10.0.0.5:${web}/`, 'not public: 10.0.0.5'], [`http://[::1]:${web}/`, 'not public: ::1'],
    [`http://public.example:${router}/`, `port ${router} not allowed`], [`http://nowhere.example:${web}/`, 'no address'],
  ]) {
    const r = await viaProxy(url);
    assert.equal(r.status, 403, url);
    assert.equal(r.body, `gate: ${why}\n`, url);
  }
});

// one request straight to the router port, with a raw path
function toRouter(path: string, headers: Record<string, string> = {}) {
  return new Promise<{ status: number; body: string }>((resolve, reject) => {
    const req = http.request({ host: '127.0.0.1', port: pass, path, method: 'POST', headers }, (res) => {
      let b = ''; res.on('data', (c) => { b += c; }); res.on('end', () => resolve({ status: res.statusCode ?? 0, body: b }));
    });
    req.on('error', reject);
    req.end('{}');
  });
}

test('router: /v1/ is passed on, marked, without identity or forwarding headers', async () => {
  const r = await toRouter('/v1/chat/completions', {
    authorization: 'Bearer sandbox-key', 'tailscale-user-login': 'owner@example.com', 'Tailscale-User-Name': 'Owner',
    'x-forwarded-for': '1.2.3.4', forwarded: 'for=1.2.3.4', 'x-real-ip': '1.2.3.4', [SANDBOX_MARK]: '0', 'x-local-ai-other': 'x',
  });
  assert.equal(r.status, 200);
  const seen = JSON.parse(r.body);
  assert.equal(seen.url, '/v1/chat/completions');
  assert.equal(seen.headers.authorization, 'Bearer sandbox-key');
  assert.equal(seen.headers[SANDBOX_MARK], '1');
  assert.equal(seen.headers.host, `127.0.0.1:${router}`);
  for (const h of ['tailscale-user-login', 'tailscale-user-name', 'x-forwarded-for', 'forwarded', 'x-real-ip', 'x-local-ai-other'])
    assert.equal(seen.headers[h], undefined, h);
});

test('router: other paths and tricks to reach them are refused', async () => {
  for (const p of ['/', '/key/generate', '/health/liveliness', '/v1/../key/generate', '/v1/%2e%2e/key/generate', '/v1//x', '/v1/%2fkey', '/v1/\\x', 'http://127.0.0.1/v1/models'])
    assert.equal((await toRouter(p)).status, 403, p);
  assert.ok(routerLogs.some((e) => e.path === '/v1/chat/completions' && e.status === 200));
});

test('proxy: gate:4000 is the router pass, by absolute URL or tunnel, with the same rules', async () => {
  const r = await viaProxy('http://gate:4000/v1/models', { headers: { 'tailscale-user-login': 'owner@example.com' } });
  assert.equal(r.status, 200);
  const seen = JSON.parse(r.body);
  assert.equal(seen.url, '/v1/models');
  assert.equal(seen.headers[SANDBOX_MARK], '1');
  assert.equal(seen.headers['tailscale-user-login'], undefined);
  assert.equal((await viaProxy('http://gate:4000/key/generate')).status, 403);
  assert.equal((await viaProxy('http://gate:4001/v1/models')).status, 403);
  const t = await tunnel('gate:4000', 'GET /v1/models HTTP/1.1\r\nhost: gate:4000\r\ntailscale-user-login: owner@example.com\r\nconnection: close\r\n\r\n');
  assert.equal(t.status, 200);
  const inner = JSON.parse(t.inner!.slice(t.inner!.indexOf('\r\n\r\n') + 4));
  assert.equal(inner.headers[SANDBOX_MARK], '1');
  assert.equal(inner.headers['tailscale-user-login'], undefined);
  assert.match((await tunnel('gate:4000', 'GET /key/generate HTTP/1.1\r\nhost: gate\r\nconnection: close\r\n\r\n')).inner ?? '', /^HTTP\/1\.1 403/);
  assert.equal((await tunnel('gate:4001')).status, 403);
});

test('a request that is not a proxy request is refused', async () => {
  const r = await new Promise<number>((resolve) => http.get({ host: '127.0.0.1', port: proxy, path: '/' }, (res) => { res.resume(); resolve(res.statusCode ?? 0); }));
  assert.equal(r, 400);
});

test('CONNECT: tunnels to public destinations only', async () => {
  const ok = await tunnel(`public.example:${web}`);
  assert.equal(ok.status, 200);
  assert.match(ok.inner ?? '', /"url":"\/in-tunnel"/);
  assert.equal((await tunnel(`lan.example:${web}`)).status, 403);
  assert.equal((await tunnel(`[fe80::1]:${web}`)).status, 403);
  assert.equal((await tunnel(`public.example:${router}`)).status, 403);
});

test('the log has destinations and verdicts, never paths', () => {
  assert.ok(logs.some((e) => e.host === 'lan.example' && !e.ok));
  assert.ok(logs.every((e) => !JSON.stringify(e).includes('/page')));
});

test('forwards: TCP into the sandbox, and the spec format', async () => {
  const fwd = createForward({ host: '127.0.0.1', port: web });
  const port = await listen(fwd);
  const body = await new Promise<string>((resolve) => http.get({ host: '127.0.0.1', port, path: '/ui' }, (res) => { let b = ''; res.on('data', (c) => { b += c; }); res.on('end', () => resolve(b)); }));
  assert.equal(JSON.parse(body).url, '/ui');
  fwd.close();
  assert.deepEqual(parseForwards('18789=openclaw-owner:18789, 18790=openclaw-a:18789'), [
    { listen: 18789, host: 'openclaw-owner', port: 18789 }, { listen: 18790, host: 'openclaw-a', port: 18789 }]);
  assert.throws(() => parseForwards('18789=bad host:1'));
});

// a DNS query as a resolver sends it: id 0x1234, recursion desired, one question
function query(name: string, qtype: number): Buffer {
  const labels = name.split('.').flatMap((l) => [l.length, ...Buffer.from(l)]);
  return Buffer.from([0x12, 0x34, 0x01, 0x00, 0, 1, 0, 0, 0, 0, 0, 0, ...labels, 0, qtype >> 8, qtype & 0xff, 0, 1]);
}

test('DNS: every A question gets the placeholder, other types no records, junk no answer', async () => {
  const a = fakeDnsAnswer(query('en.wikipedia.org', 1))!;
  assert.equal(a.readUInt16BE(0), 0x1234);
  assert.equal(a[3] & 0x0f, 0);                  // NOERROR
  assert.equal(a.readUInt16BE(6), 1);            // one answer
  assert.deepEqual([...a.subarray(-4)], FAKE_IP.split('.').map(Number));
  const aaaa = fakeDnsAnswer(query('en.wikipedia.org', 28))!;
  assert.equal(aaaa.readUInt16BE(6), 0);
  assert.equal(fakeDnsAnswer(Buffer.from([1, 2, 3])), undefined);
  assert.equal(fakeDnsAnswer(Buffer.from([0x12, 0x34, 0x81, 0x80, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1])), undefined);   // a response
  assert.equal(isPublic(FAKE_IP), false);         // the proxy never connects to it
  // and over UDP, with Node's own resolver
  const dnsSock = createFakeDns();
  await new Promise<void>((r) => dnsSock.bind(0, '127.0.0.1', r));
  const { Resolver } = await import('node:dns/promises');
  const res = new Resolver();
  res.setServers([`127.0.0.1:${dnsSock.address().port}`]);
  assert.deepEqual(await res.resolve4('anything.example'), [FAKE_IP]);
  dnsSock.close();
});
