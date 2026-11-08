// Fixture web server for the agent bench (TASK-040). Serves every fixture site by Host header on PORT and logs each
// request. The log is on ADMIN_PORT, bound to the container's own loopback: the runner reads it with docker exec, and
// the sandbox, which reaches this container by name, cannot.
//   PORT=80 ADMIN_PORT=8081 node server.ts
import http from 'node:http';
import { route } from './pages.ts';

export interface LogEntry { t: string; host: string; method: string; path: string; query: Record<string, string>; body: string }
const log: LogEntry[] = [];

function readBody(req: http.IncomingMessage): Promise<string> {
  return new Promise((resolve) => {
    let b = '';
    req.setEncoding('utf8');
    req.on('data', (c) => { if (b.length < 65_536) b += c; });
    req.on('end', () => resolve(b));
  });
}

const port = Number(process.env.PORT ?? 80);
const adminPort = Number(process.env.ADMIN_PORT ?? 8081);

http.createServer(async (req, res) => {
  const u = new URL(req.url ?? '/', 'http://x');
  const host = (req.headers.host ?? '').replace(/:\d+$/, '').toLowerCase();
  const body = await readBody(req);
  if (u.pathname !== '/favicon.ico') {
    log.push({ t: new Date().toISOString(), host, method: req.method ?? 'GET', path: u.pathname, query: Object.fromEntries(u.searchParams), body });
  }
  const r = route({ method: req.method ?? 'GET', host, path: u.pathname, query: u.searchParams, body });
  const headers: Record<string, string> = { 'content-type': r.type ?? 'text/html; charset=utf-8', 'cache-control': 'no-store' };
  if (r.location) headers.location = r.location;
  res.writeHead(r.status ?? 200, headers).end(r.body);
}).listen(port, () => console.log(`fixture sites on :${port}`));

http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/log') { res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify(log)); return; }
  if (req.method === 'POST' && req.url === '/clear') { log.length = 0; res.writeHead(204).end(); return; }
  res.writeHead(404).end();
}).listen(adminPort, '127.0.0.1', () => console.log(`admin on 127.0.0.1:${adminPort}`));
