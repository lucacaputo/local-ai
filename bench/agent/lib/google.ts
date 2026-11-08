// Google API access for the bench's test account (TASK-040): the desktop OAuth client and the refresh token live in
// Credential Manager (google/consent.ts stores them). Every call checks that the token belongs to the test account,
// since reset wipes mail, calendar and Drive.
import { readSecret } from './secrets.ts';

export const CLIENT_TARGET = 'local-ai/bench-google-client';
export const TOKEN_TARGET = 'local-ai/bench-google-token';
export const SCOPES = [
  'https://mail.google.com/', // full Gmail: reset deletes messages for good
  'https://www.googleapis.com/auth/calendar',
  'https://www.googleapis.com/auth/drive', // also covers the Sheets and Docs APIs
];

export interface Client { client_id: string; client_secret: string }
export interface Token { account: string; refresh_token: string }

export function loadClient(): Client {
  const raw = readSecret(CLIENT_TARGET);
  if (!raw) throw new Error(`No OAuth client in Credential Manager (${CLIENT_TARGET}); run google/consent.ts --client <json>`);
  return JSON.parse(raw);
}

export class Google {
  account = '';
  private access = '';
  private expires = 0;
  private client: Client;
  private token: Token;

  constructor(client?: Client, token?: Token) {
    this.client = client ?? loadClient();
    if (!token) {
      const raw = readSecret(TOKEN_TARGET);
      if (!raw) throw new Error(`No refresh token in Credential Manager (${TOKEN_TARGET}); run google/consent.ts`);
      token = JSON.parse(raw) as Token;
    }
    this.token = token;
    this.account = token.account;
  }

  private async accessToken(): Promise<string> {
    if (this.access && Date.now() < this.expires - 60_000) return this.access;
    const r = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      body: new URLSearchParams({
        client_id: this.client.client_id,
        client_secret: this.client.client_secret,
        refresh_token: this.token.refresh_token,
        grant_type: 'refresh_token',
      }),
    });
    const j = (await r.json()) as { access_token?: string; expires_in?: number; error?: string };
    if (!j.access_token) throw new Error(`token refresh failed: ${j.error ?? r.status}`);
    this.access = j.access_token;
    this.expires = Date.now() + (j.expires_in ?? 3600) * 1000;
    return this.access;
  }

  // JSON call; body is sent as JSON unless it is a string or a Uint8Array (then contentType applies)
  async call<T = any>(method: string, url: string, body?: unknown, contentType = 'application/json'): Promise<T> {
    for (let attempt = 0; ; attempt++) {
      const headers: Record<string, string> = { authorization: `Bearer ${await this.accessToken()}` };
      let payload: BodyInit | undefined;
      if (body !== undefined) {
        headers['content-type'] = contentType;
        payload = typeof body === 'string' || body instanceof Uint8Array ? (body as BodyInit) : JSON.stringify(body);
      }
      const r = await fetch(url, { method, headers, body: payload });
      if ((r.status === 429 || r.status >= 500) && attempt < 4) {
        await new Promise((res) => setTimeout(res, 1000 * 2 ** attempt));
        continue;
      }
      const text = await r.text();
      if (!r.ok) throw new Error(`${method} ${url}: ${r.status} ${text.slice(0, 300)}`);
      return (text ? JSON.parse(text) : {}) as T;
    }
  }

  // Refuses to go on unless the token's mailbox is the test account it was stored for.
  async assertAccount(): Promise<void> {
    const p = await this.call<{ emailAddress: string }>('GET', 'https://gmail.googleapis.com/gmail/v1/users/me/profile');
    if (p.emailAddress.toLowerCase() !== this.account.toLowerCase()) {
      throw new Error(`token is for ${p.emailAddress}, expected the test account ${this.account}`);
    }
  }
}
