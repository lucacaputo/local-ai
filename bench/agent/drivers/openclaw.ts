// OpenClaw in the owner's sandbox container (decision-010, decision-011). Sends one turn with
// `openclaw agent --message ... --json` through docker exec. The container, its volume and the reset come from
// TASK-041; this driver is finished and verified there (TASK-040 AC5).
import { execFile } from 'node:child_process';
import { docker } from '../lib/fixtures.ts';
import type { Driver, Turn } from './types.ts';

export class OpenClawDriver implements Driver {
  name = 'openclaw';
  private container: string;
  private workDir: string;
  constructor(container: string, workDir = '/home/agent/work') { this.container = container; this.workDir = workDir; }

  async prepare(sandbox: 'fresh' | 'used', files: Record<string, Uint8Array | string>): Promise<void> {
    if (sandbox === 'fresh') throw new Error('fresh sandbox: the reset script comes with TASK-041');
    for (const [p, data] of Object.entries(files)) {
      const target = `${this.workDir}/${p}`;
      docker(['exec', '-i', this.container, 'sh', '-c', `mkdir -p "$(dirname '${target}')" && cat > '${target}'`], data);
    }
  }

  send(prompt: string, timeoutMs: number): Promise<Turn> {
    return new Promise((resolve, reject) => {
      execFile('docker', ['exec', this.container, 'openclaw', 'agent', '--message', prompt, '--json'],
        { timeout: timeoutMs, maxBuffer: 64 * 1024 * 1024, encoding: 'utf8' }, (err, stdout) => {
          if (err) { reject(err); return; }
          const raw = JSON.parse(stdout);
          // field names to confirm against the pinned OpenClaw version in TASK-041
          resolve({ reply: String(raw.reply ?? raw.text ?? raw.payload?.text ?? ''), toolCalls: [], confirmations: 0, raw });
        });
    });
  }

  async workFiles(): Promise<Record<string, string>> {
    const out = docker(['exec', this.container, 'sh', '-c', `cd '${this.workDir}' 2>/dev/null && find . -type f -exec sha256sum {} +`]);
    return Object.fromEntries(out.trim().split('\n').filter(Boolean).map((l) => {
      const [hash, ...name] = l.split(/\s+/);
      return [name.join(' ').replace(/^\.\//, ''), hash];
    }));
  }
}
