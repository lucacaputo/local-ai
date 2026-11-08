// Agent bake-off runner (doc-003 section 8, TASK-040): one task, one language, one run. Starts the fixture sites
// with an empty log, wipes and seeds the test Google account, prepares the sandbox, sends the prompt, then checks
// the end state. One summary line per run goes to <out>\results.jsonl, as bench\quality does.
//   node bench\agent\run.ts --task B2 --lang it [--sandbox fresh|used] [--driver openclaw|oracle|idle] [--rep 1]
//                           [--user owner] [--out D:\local-ai\scratch\agent-bench\runs] [--timeout-min 20]
import fs from 'node:fs';
import path from 'node:path';
import { parseArgs } from 'node:util';
import { LocalDriver } from './drivers/local.ts';
import { OpenClawDriver } from './drivers/openclaw.ts';
import type { Driver } from './drivers/types.ts';
import type { Lang } from './fixtures/web-data.ts';
import { extract } from './lib/extract.ts';
import * as fixtures from './lib/fixtures.ts';
import { Google } from './lib/google.ts';
import { wipe } from './lib/gworkspace.ts';
import { task as findTask } from './tasks/index.ts';
import type { Ctx } from './tasks/types.ts';

const { values: a } = parseArgs({
  options: {
    task: { type: 'string' }, lang: { type: 'string', default: 'it' }, sandbox: { type: 'string', default: 'used' },
    driver: { type: 'string', default: 'openclaw' }, rep: { type: 'string', default: '1' }, user: { type: 'string', default: 'owner' },
    out: { type: 'string', default: 'D:\\local-ai\\scratch\\agent-bench\\runs' }, 'timeout-min': { type: 'string', default: '20' }, tag: { type: 'string' },
  },
});
if (!a.task) throw new Error('--task is required');
const task = findTask(a.task);
const lang = a.lang as Lang;
if (lang !== 'it' && lang !== 'en') throw new Error('--lang is it or en');
const sandbox = a.sandbox as 'fresh' | 'used';
if (sandbox !== 'fresh' && sandbox !== 'used') throw new Error('--sandbox is fresh or used');

const name = [a.driver, task.id, lang, sandbox, a.tag, `r${a.rep}`].filter(Boolean).join('-');
const dir = path.join(a.out!, name);
if (fs.existsSync(dir)) throw new Error(`${dir} exists; pick another --rep or remove it`);
fs.mkdirSync(dir, { recursive: true });

async function driverFor(kind: string): Promise<Driver> {
  if (kind === 'openclaw') return new OpenClawDriver(a.user!);
  if (kind === 'idle') return new LocalDriver(path.join(dir, 'work'));
  if (kind === 'oracle') {
    const { OracleDriver } = await import('./test/oracle.ts');
    return new OracleDriver(path.join(dir, 'work'));
  }
  throw new Error(`unknown driver ${kind}`);
}
const driver = await driverFor(a.driver!);

const log = (s: string) => console.log(`[${name}] ${s}`);
if (task.sites) { log('fixture sites'); await fixtures.up(); }
let google: Google | undefined;
let seed: Record<string, any> = {};
if (task.google) {
  google = new Google();
  log(`reset ${google.account}`);
  await wipe(google);
  seed = (await task.seed?.(google, lang, Date.now())) ?? {};
}
await driver.prepare(sandbox, task.files?.(lang) ?? {});
driver.bind?.({ task: task.id, lang, google, seed });
const workBefore = await driver.workFiles();

log('prompt sent');
const started = Date.now();
let turn;
let error: string | undefined;
try {
  turn = await driver.send(task.prompt[lang], Number(a['timeout-min']) * 60_000);
} catch (e) {
  error = String((e as Error).message ?? e);
  turn = { reply: '', toolCalls: [], confirmations: 0 };
}
const seconds = Math.round((Date.now() - started) / 100) / 10;
log(`answered in ${seconds} s${error ? ` (error: ${error})` : ''}`);

const ctx: Ctx = {
  lang, reply: turn.reply, started, google, seed,
  siteLog: task.sites ? fixtures.log() : [],
  workBefore, workAfter: await driver.workFiles(),
  confirmations: turn.confirmations,
  extract,
};
const items = await task.check(ctx);
const pass = !error && items.every((i) => i.ok);

fs.writeFileSync(path.join(dir, 'reply.md'), turn.reply);
fs.writeFileSync(path.join(dir, 'turn.json'), JSON.stringify({ ...turn, error }, null, 2));
fs.writeFileSync(path.join(dir, 'check.json'), JSON.stringify(items, null, 2));
if (task.sites) fs.writeFileSync(path.join(dir, 'site-log.json'), JSON.stringify(ctx.siteLog, null, 2));
const summary = {
  run: name, task: task.id, lang, sandbox, driver: driver.name, at: new Date(started).toISOString(), seconds,
  tool_calls: turn.toolCalls.length, tool_errors: turn.toolCalls.filter((t) => !t.ok).length,
  tools: turn.toolNames ?? [...new Set(turn.toolCalls.map((t) => t.name))], confirmations: turn.confirmations,
  pass, failed: items.filter((i) => !i.ok).map((i) => i.name), error,
};
fs.appendFileSync(path.join(a.out!, 'results.jsonl'), JSON.stringify(summary) + '\n');
for (const i of items) console.log(`  ${i.ok ? 'ok  ' : 'FAIL'} ${i.name}${!i.ok && i.detail ? ` — ${i.detail}` : ''}`);
log(pass ? 'PASS' : 'FAIL');
