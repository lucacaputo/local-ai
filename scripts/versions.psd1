# Pinned versions for the local AI stack (backlog decision-002). Used by scripts\install.ps1.
# Bump deliberately: change the version AND the hash, then rerun install.ps1.
@{
  LlamaCpp = @{
    Build   = 'b11719'
    Archive = 'llama-b11719-bin-win-cuda-13.4-x64.zip'
    Sha256  = '926257ef2132133e7630e7062e28a6f13e621f17a36770b04c695c0d14e27578'
    Url     = 'https://github.com/ggml-org/llama.cpp/releases/download/b11719/llama-b11719-bin-win-cuda-13.4-x64.zip'
    CudaRt  = @{
      Archive = 'cudart-llama-bin-win-cuda-13.4-x64.zip'
      Sha256  = '738f8c251ac22b70c3ae6f83a10cf222725df0395246a2cf58f32bdb85fbe668'
      Url     = 'https://github.com/ggml-org/llama.cpp/releases/download/b11719/cudart-llama-bin-win-cuda-13.4-x64.zip'
    }
    Dir     = 'llama.cpp-b11719'   # config\llama-swap.yaml refers to this folder
  }
  LlamaSwap = @{
    Version = 'v265'
    Archive = 'llama-swap_265_windows_amd64.zip'
    Sha256  = '80b61f4e980a11e659d5c8973f8b72f22cc5f68eaa33e28645ff67c16763bcc9'
    Url     = 'https://github.com/mostlygeek/llama-swap/releases/download/v265/llama-swap_265_windows_amd64.zip'
    Dir     = 'llama-swap-v265'
  }
  LiteLlm = @{ Version = '1.106.0'; Python = '3.12'; VenvDir = 'litellm-venv' }
  Uv      = @{ Version = '0.13.1'; WingetId = 'astral-sh.uv' }
  Tailscale = @{ Version = '1.104.1'; WingetId = 'Tailscale.Tailscale' }
  # Client for local models (TASK-035, TASK-038); installed with npm, so Node.js is a prerequisite. Same pin on the Mac.
  OpenCode = @{ Version = '1.19.3'; Npm = 'opencode-ai' }
  # One entry per model file; Name is the llama-swap / LiteLLM model that serves it (config\llama-swap.yaml).
  Models  = @(
    @{
      Name   = 'local-coder'   # also serves local-light (alias); carries the MTP head (blk.64.nextn.*), TASK-033/036
      File   = 'Qwen3.8-27B-UD-Q6_K.gguf'
      Url    = 'https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/main/Qwen3.8-27B-UD-Q6_K.gguf'
      Size   = 21983677344
      Sha256 = 'c9c206812fbe4ac7b76a729e25928b63f2ae89d37f69da7a71c20aec763cd436'
    }
  )
  MinCudaVersion = '12.8'
  MinComputeCapability = '12.0'   # Blackwell (sm_120)
}
