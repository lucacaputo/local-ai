// The fixture-site container (TASK-040): on its own internal Docker network, agent-bench, with one network alias per
// site, so a sandbox joined to that network reaches the sites by name and nothing else on it reaches the host or the
// internet. The request log is read with docker exec from the container's loopback (fixtures/sites/server.ts).
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { HOSTS } from '../fixtures/sites/pages.ts';
import type { LogEntry } from '../fixtures/sites/server.ts';

export type { LogEntry };
export const NETWORK = 'agent-bench';
export const CONTAINER = 'agent-fixtures';
export const IMAGE = 'local-ai/agent-fixtures';
const context = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'fixtures');

export function docker(args: string[], input?: string | Uint8Array): string {
  return execFileSync('docker', args, { encoding: 'utf8', input, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
}

function exists(kind: 'network' | 'container', name: string): boolean {
  try { docker([kind, 'inspect', name]); return true; } catch { return false; }
}

// Builds the image (cached when nothing changed) and starts a new container, so every run starts with an empty log.
export async function up(): Promise<void> {
  docker(['build', '-q', '-t', IMAGE, context]);
  if (!exists('network', NETWORK)) docker(['network', 'create', '--internal', NETWORK]);
  if (exists('container', CONTAINER)) docker(['rm', '-f', CONTAINER]);
  docker([
    'run', '-d', '--name', CONTAINER, '--network', NETWORK, ...HOSTS.flatMap((h) => ['--network-alias', h]),
    '--sysctl', 'net.ipv4.ip_unprivileged_port_start=0', '--read-only', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges',
    IMAGE,
  ]);
  for (let i = 0; i < 50; i++) {
    try { log(); return; } catch { await new Promise((r) => setTimeout(r, 200)); }
  }
  throw new Error(`fixture container did not start: ${docker(['logs', CONTAINER])}`);
}

export function log(): LogEntry[] {
  return JSON.parse(docker(['exec', CONTAINER, 'wget', '-qO-', 'http://127.0.0.1:8081/log']));
}

export function down(): void {
  if (exists('container', CONTAINER)) docker(['rm', '-f', CONTAINER]);
}
