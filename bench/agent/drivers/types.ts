// What the runner needs from an agent: a sandbox to prepare, one prompt to run, and the working folder to compare.
export interface ToolCall { name: string; ok: boolean }
export interface Turn {
  reply: string;
  toolCalls: ToolCall[];
  confirmations: number;   // confirmation requests seen, all denied (TASK-044 wires the real mechanism)
  raw?: unknown;           // the agent's own record of the turn, saved next to the results
}
export interface Driver {
  name: string;
  // fresh: a new, empty sandbox; used: the existing one, with its history, logins and files
  prepare(sandbox: 'fresh' | 'used', files: Record<string, Uint8Array | string>): Promise<void>;
  send(prompt: string, timeoutMs: number): Promise<Turn>;
  workFiles(): Promise<Record<string, string>>;   // working folder: relative path -> sha256
  // test drivers only: what the run seeded, before send()
  bind?(run: { task: string; lang: 'it' | 'en'; google?: import('../lib/google.ts').Google; seed: Record<string, any> }): void;
}
