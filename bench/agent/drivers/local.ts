// Drivers without an agent, for testing the bench itself: the working folder is a local directory. "idle" does
// nothing and answers with an empty reply, so every task must fail with it.
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import type { Driver, Turn } from './types.ts';

export class LocalDriver implements Driver {
  name = 'idle';
  protected work: string;
  constructor(work: string) { this.work = work; }

  async prepare(sandbox: 'fresh' | 'used', files: Record<string, Uint8Array | string>): Promise<void> {
    if (sandbox === 'fresh') fs.rmSync(this.work, { recursive: true, force: true });
    for (const [p, data] of Object.entries(files)) {
      const f = path.join(this.work, p);
      fs.mkdirSync(path.dirname(f), { recursive: true });
      fs.writeFileSync(f, data);
    }
    fs.mkdirSync(this.work, { recursive: true });
  }

  async send(_prompt: string, _timeoutMs: number): Promise<Turn> {
    return { reply: '', toolCalls: [], confirmations: 0 };
  }

  async workFiles(): Promise<Record<string, string>> {
    const out: Record<string, string> = {};
    const walk = (dir: string) => {
      for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        const f = path.join(dir, e.name);
        if (e.isDirectory()) walk(f);
        else out[path.relative(this.work, f).replace(/\\/g, '/')] = crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
      }
    };
    if (fs.existsSync(this.work)) walk(this.work);
    return out;
  }
}
