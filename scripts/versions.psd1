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
  Model   = @{
    File   = 'Qwen3.6-27B-Q4_K_M.gguf'
    Url    = 'https://huggingface.co/unsloth/Qwen3.6-27B-GGUF/resolve/main/Qwen3.6-27B-Q4_K_M.gguf'
    Size   = 16817244384
    Sha256 = '5ed60d0af4650a854b1755bd392f9aef4872643dc25a254bc68043fa638392a0'
  }
  MinCudaVersion = '12.8'
  MinComputeCapability = '12.0'   # Blackwell (sm_120)
}
