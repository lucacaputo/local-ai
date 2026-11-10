// TASK-043 trial, route (a): the Google relay. gog in the sandbox runs with GOG_GOOGLE_API_BASE_URL pointing here and
// attaches no credentials; this relay holds the account's refresh token, adds a fresh access token to each call and
// sends it to Google through the gate. The sandbox never sees a Google token, and this is the one place a rule can
// stop an action whatever the agent runs (TASK-044 builds the confirmations on it; the trial only refuses).
//
// Runs in the gate image (Node 22), on the sandbox network only, as "google":
//   /secrets/relay.json  {client_id, client_secret, refresh_token}   (read-only volume, written by trial.ps1)
//   RELAY_PORT (8080), RELAY_PROXY (gate:3128)
import fs from 'node:fs';
import http from 'node:http';
import https from 'node:https';
import tls from 'node:tls';

const port = Number(process.env.RELAY_PORT ?? 8080);
const [phost, pport] = (process.env.RELAY_PROXY ?? 'gate:3128').split(':');
const secrets = JSON.parse(fs.readFileSync('/secrets/relay.json', 'utf8')) as { client_id: string; client_secret: string; refresh_token: string };
const say = (o: object) => console.log(JSON.stringify({ t: new Date().toISOString(), ...o }));

// A TLS connection to host:443 through the gate's CONNECT.
function viaGate(host: string): Promise<tls.TLSSocket> {
  return new Promise((resolve, reject) => {
    const req = http.request({ host: phost, port: Number(pport), method: 'CONNECT', path: `${host}:443` });
    req.on('connect', (res, sock) => {
      if (res.statusCode !== 200) { sock.destroy(); reject(new Error(`gate refused ${host}: ${res.statusCode}`)); return; }
      const t = tls.connect({ socket: sock, servername: host }, () => resolve(t));
      t.on('error', reject);
    });
    req.on('error', reject);
    req.end();
  });
}
function upstream(host: string, opts: https.RequestOptions, cb: (r: http.IncomingMessage) => void): http.ClientRequest {
  // createConnection may hand the socket back later through its callback
  return https.request({ ...opts, host, port: 443, defaultPort: 443, servername: host,
    createConnection: ((_o: unknown, done: (e: Error | null, s?: tls.TLSSocket) => void) => { viaGate(host).then((s) => done(null, s), (e) => done(e)); return undefined; }) as never,
  }, cb);
}

let cached: { token: string; until: number } | undefined;
async function accessToken(): Promise<string> {
  if (cached && Date.now() < cached.until) return cached.token;
  const body = new URLSearchParams({ client_id: secrets.client_id, client_secret: secrets.client_secret, refresh_token: secrets.refresh_token, grant_type: 'refresh_token' }).toString();
  const res = await new Promise<{ status: number; text: string }>((resolve, reject) => {
    const r = upstream('oauth2.googleapis.com', { method: 'POST', path: '/token', headers: { 'content-type': 'application/x-www-form-urlencoded', 'content-length': Buffer.byteLength(body) } }, (m) => {
      let t = ''; m.on('data', (c) => { t += c; }); m.on('end', () => resolve({ status: m.statusCode ?? 0, text: t }));
    });
    r.on('error', reject);
    r.end(body);
  });
  if (res.status !== 200) {
    // invalid_grant here is what an expired or revoked sign-in looks like (the 7-day Testing limit, D1)
    say({ token: 'refresh failed', status: res.status, error: (() => { try { return JSON.parse(res.text).error; } catch { return 'unreadable'; } })() });
    throw new Error(`token refresh failed (${res.status})`);
  }
  const j = JSON.parse(res.text) as { access_token: string; expires_in: number };
  cached = { token: j.access_token, until: Date.now() + (j.expires_in - 120) * 1000 };
  say({ token: 'refreshed', expiresIn: j.expires_in });
  return cached.token;
}

// The trial's rules: what the agent may not do on its own. Matched on method and path, which gog keeps as Google's.
const RULES: { why: string; test: (m: string, host: string, path: string) => boolean }[] = [
  { why: 'sending mail needs your confirmation', test: (m, _h, p) => m === 'POST' && /\/gmail\/v1\/users\/[^/]+\/(messages|drafts)\/send$/.test(p) },
  { why: 'deleting needs your confirmation', test: (m, _h, p) => m === 'DELETE' || /\/(trash|batchDelete)$/.test(p) },
  { why: 'sharing needs your confirmation', test: (m, _h, p) => m === 'POST' && /\/drive\/v3\/files\/[^/]+\/permissions$/.test(p) },
];
const HOST = /^([a-z0-9-]+\.)*googleapis\.com$/;
const HOP = ['connection', 'proxy-connection', 'keep-alive', 'te', 'trailer', 'transfer-encoding', 'upgrade', 'host', 'authorization', 'x-forwarded-host', 'x-goog-api-key'];

http.createServer(async (req, res) => {
  const fail = (code: number, message: string) => { res.writeHead(code, { 'content-type': 'application/json' }).end(JSON.stringify({ error: { code, message: `relay: ${message}` } })); };
  const host = String(req.headers['x-forwarded-host'] ?? '').toLowerCase();
  const url = new URL(req.url ?? '/', 'http://relay');
  const method = req.method ?? 'GET';
  if (!HOST.test(host)) { say({ method, host, ok: false, why: 'not a Google API host' }); fail(400, 'only Google API hosts'); return; }
  const rule = RULES.find((r) => r.test(method, host, url.pathname.replace(/^\/upload/, '')));
  if (rule) { say({ method, host, path: url.pathname, ok: false, why: rule.why }); fail(403, `${rule.why}; ask the user to do it themselves`); return; }
  // Some actions are in the body, not the path: Drive moves a file to the trash with PATCH {"trashed": true}.
  // Those small metadata requests are read whole and checked before anything goes on.
  let body: Buffer | undefined;
  if (method === 'PATCH' && /^\/drive\/v[23]\/files\/[^/]+$/.test(url.pathname)) {
    const chunks: Buffer[] = []; let size = 0;
    for await (const c of req) { size += (c as Buffer).length; if (size > 1 << 20) { fail(413, 'metadata request too large'); return; } chunks.push(c as Buffer); }
    body = Buffer.concat(chunks);
    let trashed = false;
    try { trashed = JSON.parse(body.toString('utf8') || '{}').trashed === true; } catch { fail(400, 'unreadable metadata request'); return; }
    if (trashed) { say({ method, host, path: url.pathname, ok: false, why: 'deleting needs your confirmation' }); fail(403, 'deleting needs your confirmation; ask the user to do it themselves'); return; }
  }
  let token: string;
  try { token = await accessToken(); } catch (e) { fail(502, (e as Error).message); return; }
  const headers: http.OutgoingHttpHeaders = { ...req.headers };
  for (const k of HOP) delete headers[k];
  headers.authorization = `Bearer ${token}`;
  if (body) { headers['content-length'] = body.length; } else if (req.headers['transfer-encoding']) headers['transfer-encoding'] = req.headers['transfer-encoding'];
  const up = upstream(host, { method, path: url.pathname + url.search, headers }, (r) => {
    say({ method, host, path: url.pathname, status: r.statusCode });
    const h = { ...r.headers }; delete h.connection; delete h['transfer-encoding'];
    res.writeHead(r.statusCode ?? 502, h);
    r.pipe(res);
  });
  up.on('error', (e) => { say({ method, host, path: url.pathname, error: e.message }); if (res.headersSent) res.destroy(); else fail(502, 'Google unreachable'); });
  if (body) up.end(body); else req.pipe(up);
}).listen(port, () => say({ relay: port, proxy: `${phost}:${pport}` }));
for (const sig of ['SIGTERM', 'SIGINT']) process.on(sig, () => process.exit(0));
