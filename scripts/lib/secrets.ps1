# Windows Credential Manager access for PowerShell 5.1 (no extra modules).
# Secrets are stored as generic credentials, encrypted per Windows user, persisted locally.
# Dot-source:  . "$PSScriptRoot\lib\secrets.ps1"

$script:RouterKeyTarget = 'local-ai/router-key'

if (-not ('LocalAi.CredMan' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace LocalAi {
  public static class CredMan {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct CREDENTIAL {
      public uint Flags; public uint Type; public string TargetName; public string Comment;
      public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
      public uint CredentialBlobSize; public IntPtr CredentialBlob; public uint Persist;
      public uint AttributeCount; public IntPtr Attributes; public string TargetAlias; public string UserName;
    }
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool CredReadW(string target, uint type, uint flags, out IntPtr cred);
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool CredWriteW(ref CREDENTIAL cred, uint flags);
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool CredDeleteW(string target, uint type, uint flags);
    [DllImport("advapi32.dll")] static extern void CredFree(IntPtr buffer);

    const uint CRED_TYPE_GENERIC = 1;
    const uint CRED_PERSIST_LOCAL_MACHINE = 2;

    public static string Read(string target) {
      IntPtr p;
      if (!CredReadW(target, CRED_TYPE_GENERIC, 0, out p)) return null;
      try {
        CREDENTIAL c = (CREDENTIAL)Marshal.PtrToStructure(p, typeof(CREDENTIAL));
        return Marshal.PtrToStringUni(c.CredentialBlob, (int)c.CredentialBlobSize / 2);
      } finally { CredFree(p); }
    }

    public static void Write(string target, string user, string secret) {
      byte[] blob = Encoding.Unicode.GetBytes(secret);
      IntPtr mem = Marshal.AllocHGlobal(blob.Length);
      try {
        Marshal.Copy(blob, 0, mem, blob.Length);
        CREDENTIAL c = new CREDENTIAL();
        c.Type = CRED_TYPE_GENERIC; c.TargetName = target; c.UserName = user;
        c.CredentialBlobSize = (uint)blob.Length; c.CredentialBlob = mem; c.Persist = CRED_PERSIST_LOCAL_MACHINE;
        if (!CredWriteW(ref c, 0)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
      } finally {
        Marshal.Copy(new byte[blob.Length], 0, mem, blob.Length);
        Marshal.FreeHGlobal(mem);
      }
    }

    public static bool Delete(string target) { return CredDeleteW(target, CRED_TYPE_GENERIC, 0); }
  }
}
'@
}

function Get-LocalAiSecret([string]$Target = $script:RouterKeyTarget) {
  [LocalAi.CredMan]::Read($Target)
}

function Set-LocalAiSecret([string]$Value, [string]$Target = $script:RouterKeyTarget) {
  [LocalAi.CredMan]::Write($Target, $env:USERNAME, $Value)
}

function Remove-LocalAiSecret([string]$Target = $script:RouterKeyTarget) {
  [LocalAi.CredMan]::Delete($Target)
}

# Router key = LiteLLM master key and the key clients send in x-litellm-api-key (decision-005).
function Get-LocalAiRouterKey {
  $k = Get-LocalAiSecret
  if (-not $k) { throw "No router key in Credential Manager (target '$script:RouterKeyTarget'). Run scripts\init-secrets.ps1 first." }
  $k
}
