// OpenClaw in a user's sandbox container (decision-010, decision-011, TASK-041). One turn per run, in a new session,
// with `openclaw agent --message ... --json` through docker exec. A fresh sandbox is a reset and a new start through
// scripts\sandbox.ps1; the container joins the fixture network so the .test sites resolve.
import { execFile, execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { NETWORK, docker } from '../lib/fixtures.ts';
import type { Driver, ToolCall, Turn } from './types.ts';

const repo = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const WORK = '/home/node/work';
// OpenClaw's own files in the workspace (persona, first-run ritual, memory, git); the agent may edit them by design
const OWN = /^(AGENTS|SOUL|IDENTITY|USER|BOOTSTRAP|MEMORY|HEARTBEAT|TOOLS)\.md$|^(memory|\.git|\.openclaw)\//;

export class OpenClawDriver implements Driver {
  name = 'openclaw';
  private user: string;
  private container: string;
  constructor(user = 'owner') { this.user = user; this.container = `openclaw-${user}`; }

  private sandbox(action: 'reset' | 'start') {
    execFileSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(repo, 'scripts', 'sandbox.ps1'), action, '-User', this.user], { stdio: 'inherit' });
  }

  async prepare(sandbox: 'fresh' | 'used', files: Record<string, Uint8Array | string>): Promise<void> {
    if (sandbox === 'fresh') { this.sandbox('reset'); this.sandbox('start'); }
    else if (docker(['inspect', '-f', '{{.State.Status}}', this.container]).trim() !== 'running') this.sandbox('start');
    // a used sandbox keeps logins and history, not the last run's open tabs (they would show the old fixture state)
    else docker(['exec', this.container, 'node', '/app/openclaw.mjs', 'browser', 'stop']);
    const nets = docker(['inspect', '-f', '{{json .NetworkSettings.Networks}}', this.container]);
    if (!nets.includes(`"${NETWORK}"`)) docker(['network', 'connect', NETWORK, this.container]);
    for (const [p, data] of Object.entries(files)) {
      const target = `${WORK}/${p}`;
      docker(['exec', '-i', this.container, 'sh', '-c', `mkdir -p "$(dirname '${target}')" && cat > '${target}'`], data);
    }
  }

  send(prompt: string, timeoutMs: number): Promise<Turn> {
    const session = `agent:main:bench-${crypto.randomUUID()}`;
    const args = ['exec', this.container, 'node', '/app/openclaw.mjs', 'agent', '--agent', 'main', '--session-key', session,
      '--message', prompt, '--json', '--timeout', String(Math.round(timeoutMs / 1000))];
    let confirmations = 0;
    const answered = new Set<string>();
    // The bench never confirms: every question the agent asks in this session (ask_user) gets "no"
    const poll = setInterval(() => {
      execFile('docker', [...this.gateway('question.list', {})], { encoding: 'utf8' }, (err, out) => {
        if (err) return;
        for (const q of (JSON.parse(out).questions ?? []) as Question[]) {
          if (q.sessionKey !== session || q.status !== 'pending' || answered.has(q.id)) continue;
          answered.add(q.id);
          confirmations++;
          execFile('docker', [...this.gateway('question.resolve', deny(q))], () => {});
        }
      });
    }, 3000);
    return new Promise<Turn>((resolve, reject) => {
      execFile('docker', args, { timeout: timeoutMs + 60_000, maxBuffer: 256 * 1024 * 1024, encoding: 'utf8' }, (err, stdout, stderr) => {
        if (err && !stdout) { reject(new Error(`${err.message}\n${stderr.slice(-2000)}`)); return; }
        let raw: any;
        try { raw = JSON.parse(stdout); } catch { reject(new Error(`not JSON: ${stdout.slice(0, 500)}`)); return; }
        const meta = raw.result?.meta ?? {};
        const reply = meta.finalAssistantVisibleText ?? (raw.result?.payloads ?? []).map((p: any) => p.text).filter(Boolean).join('\n') ?? '';
        // toolSummary counts the calls and failures and names the tools used, not each call's tool
        const sum = meta.toolSummary ?? { calls: 0, failures: 0, tools: [] };
        const toolCalls: ToolCall[] = Array.from({ length: sum.calls }, (_, i) => ({ name: '?', ok: i >= (sum.failures ?? 0) }));
        resolve({ reply, toolCalls, toolNames: sum.tools ?? [], confirmations, raw });
      });
    }).finally(() => clearInterval(poll));
  }

  private gateway(method: string, params: object): string[] {
    return ['exec', this.container, 'node', '/app/openclaw.mjs', 'gateway', 'call', method, '--json', '--params', JSON.stringify(params)];
  }

  async workFiles(): Promise<Record<string, string>> {
    const out = docker(['exec', this.container, 'sh', '-c', `cd '${WORK}' && find . -type f -exec sha256sum {} +`]);
    return Object.fromEntries(out.trim().split('\n').filter(Boolean).map((l) => {
      const [hash, ...name] = l.split(/\s+/);
      return [name.join(' ').replace(/^\.\//, ''), hash] as [string, string];
    }).filter(([p]) => !OWN.test(p)));
  }
}

interface Question { id: string; sessionKey: string; status: string; questions: { questionId: string; options?: { label: string }[]; isOther?: boolean }[] }
const NO = /^\s*(no\b|non\b|annulla|ferma|stop|cancel|don'?t|do not)/i;

// question.resolve params: the option that says no for each question, free text when allowed, else cancel
function deny(q: Question): object {
  const answers: Record<string, string[]> = {};
  for (const x of q.questions) {
    const no = x.options?.find((o) => NO.test(o.label));
    if (no) answers[x.questionId] = [no.label];
    else if (x.isOther) answers[x.questionId] = ['No, do not proceed / No, non procedere'];
    else return { id: q.id, cancel: true };
  }
  return { id: q.id, answers: { answers } };
}
