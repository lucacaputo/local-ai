// One-time consent for the bench's test Google account (TASK-040). Stores the desktop OAuth client and the refresh
// token in Credential Manager; the downloaded client JSON can be deleted afterwards.
//   node bench\agent\google\consent.ts --account <test address> [--client <client_secret_....json>]
import http from 'node:http';
import crypto from 'node:crypto';
import fs from 'node:fs';
import { execFile } from 'node:child_process';
import { parseArgs } from 'node:util';
import { writeSecret } from '../lib/secrets.ts';
import { CLIENT_TARGET, Google, SCOPES, TOKEN_TARGET, loadClient, type Client } from '../lib/google.ts';

const { values } = parseArgs({ options: { account: { type: 'string' }, client: { type: 'string' } } });
if (!values.account) throw new Error('--account <test address> is required');
const account = values.account;

let client: Client;
if (values.client) {
  const j = JSON.parse(fs.readFileSync(values.client, 'utf8'));
  const c = j.installed;
  if (!c?.client_id || !c?.client_secret) throw new Error('not a desktop-app client JSON (no "installed" section)');
  client = { client_id: c.client_id, client_secret: c.client_secret };
  writeSecret(CLIENT_TARGET, JSON.stringify(client));
  console.log(`OAuth client stored in Credential Manager (${CLIENT_TARGET}); the JSON file can be deleted.`);
} else {
  client = loadClient();
}

const verifier = crypto.randomBytes(32).toString('base64url');
const challenge = crypto.createHash('sha256').update(verifier).digest('base64url');
const state = crypto.randomBytes(16).toString('hex');

const code = await new Promise<{ code: string; redirect: string }>((resolve, reject) => {
  const server = http.createServer((req, res) => {
    const u = new URL(req.url ?? '/', 'http://127.0.0.1');
    if (u.pathname !== '/') { res.writeHead(404).end(); return; }
    const err = u.searchParams.get('error');
    const got = u.searchParams.get('code');
    const ok = !err && got && u.searchParams.get('state') === state;
    res.writeHead(ok ? 200 : 400, { 'content-type': 'text/plain; charset=utf-8' });
    res.end(ok ? 'Done: you can close this tab.' : `Consent failed: ${err ?? 'bad state'}`);
    server.close();
    if (ok) resolve({ code: got!, redirect }); else reject(new Error(`consent failed: ${err ?? 'bad state'}`));
  });
  let redirect = '';
  server.listen(0, '127.0.0.1', () => {
    redirect = `http://127.0.0.1:${(server.address() as { port: number }).port}/`;
    const url = 'https://accounts.google.com/o/oauth2/v2/auth?' + new URLSearchParams({
      client_id: client.client_id,
      redirect_uri: redirect,
      response_type: 'code',
      scope: SCOPES.join(' '),
      access_type: 'offline',
      prompt: 'consent',
      login_hint: account,
      state,
      code_challenge: challenge,
      code_challenge_method: 'S256',
    });
    console.log(`Opening the consent page; sign in as ${account}. If no browser opens, visit:\n${url}`);
    execFile('powershell.exe', ['-NoProfile', '-Command', `Start-Process '${url}'`]);
  });
  setTimeout(() => { server.close(); reject(new Error('no consent within 10 minutes')); }, 600_000).unref();
});

const r = await fetch('https://oauth2.googleapis.com/token', {
  method: 'POST',
  body: new URLSearchParams({
    client_id: client.client_id,
    client_secret: client.client_secret,
    code: code.code,
    code_verifier: verifier,
    redirect_uri: code.redirect,
    grant_type: 'authorization_code',
  }),
});
const t = (await r.json()) as { refresh_token?: string; scope?: string; error?: string };
if (!t.refresh_token) throw new Error(`no refresh token: ${t.error ?? r.status}`);
const missing = SCOPES.filter((s) => !t.scope?.split(' ').includes(s));
if (missing.length) throw new Error(`consent is missing scopes (tick every box): ${missing.join(', ')}`);

const g = new Google(client, { account, refresh_token: t.refresh_token });
await g.assertAccount();   // a different signed-in account must not be stored as the test account
writeSecret(TOKEN_TARGET, JSON.stringify({ account, refresh_token: t.refresh_token }));
console.log(`Refresh token for ${account} stored in Credential Manager (${TOKEN_TARGET}).`);
