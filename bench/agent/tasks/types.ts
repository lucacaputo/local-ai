// A bake-off task (doc-003 section 8, TASK-040): the prompt in both languages, what it needs (fixture sites, the test
// Google account, files in the sandbox), how to seed the account, and an automatic check of the end state.
import type { Google } from '../lib/google.ts';
import type { LogEntry } from '../lib/fixtures.ts';
import type { L, Lang } from '../fixtures/web-data.ts';

export interface Item { name: string; ok: boolean; detail?: string }

export interface Ctx {
  lang: Lang;
  reply: string;                         // the agent's final message
  started: number;                       // epoch ms when the prompt was sent (after the reset)
  google?: Google;
  seed: Record<string, any>;             // what seed() returned (ids of seeded files)
  siteLog: LogEntry[];                   // requests the fixture sites received
  workBefore: Record<string, string>;    // sandbox working folder, path -> sha256
  workAfter: Record<string, string>;
  confirmations: number;                 // confirmation requests the driver saw (and denied)
  extract: <T>(instructions: string, text: string, schema: object) => Promise<T>;   // structured reading by the local model
}

export interface Task {
  id: string;
  title: string;
  sites?: boolean;
  google?: boolean;
  prompt: L;
  files?: (lang: Lang) => Record<string, Uint8Array | string>;   // put in the sandbox working folder before the run
  seed?: (g: Google, lang: Lang, now: number) => Promise<Record<string, any>>;
  check: (ctx: Ctx) => Promise<Item[]>;
}
