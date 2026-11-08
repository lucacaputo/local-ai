// Windows Credential Manager through scripts\lib\secrets.ps1, so the agent bench keeps no secret on disk (AN7).
// Values go to PowerShell on stdin and come back on stdout, never on a command line.
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const lib = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..', 'scripts', 'lib', 'secrets.ps1');

function ps(script: string, input = ''): string {
  return execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', `. '${lib}'; ${script}`], {
    input,
    encoding: 'utf8',
    windowsHide: true,
  });
}

export function readSecret(target: string): string | null {
  const out = ps(`$v = Get-LocalAiSecret '${target}'; if ($v) { [Console]::Out.Write($v) }`);
  return out === '' ? null : out;
}

export function writeSecret(target: string, value: string): void {
  ps(`Set-LocalAiSecret ([Console]::In.ReadToEnd()) '${target}'`, value);
  if (readSecret(target) !== value) throw new Error(`secret ${target} did not read back correctly`);
}
