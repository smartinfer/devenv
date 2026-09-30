#!/usr/bin/env bash
cluster 60-ml-inf

item name=inference-cli \
  desc="local-llm — one status and serve command for MLX-LM, vLLM, and llama.cpp" \
  check='[ -x "$LOCAL_BIN/local-llm" ] && { [ ! -x /usr/lib/wsl/lib/nvidia-smi ] || grep -q "/usr/lib/wsl/lib" "$DEV_SHELL/path.zsh" 2>/dev/null; }' \
  version='"$LOCAL_BIN/local-llm" --version' method=verify \
  home='~/.local/bin/local-llm:symlink to the devenv launcher' \
  shell='path.zsh:/usr/lib/wsl/lib when WSL exposes the NVIDIA driver there' \
  network='' system='' apps='' receipt='' \
  purge='rm -f "$HOME/.local/bin/local-llm"' \
  manual='ln -sf "$DEV_ROOT/local-llm" "$HOME/.local/bin/local-llm"' \
  install=install_inference_cli

install_inference_cli() {
  ensure_dirs
  chmod +x "$DEV_ROOT/local-llm"
  ln -sf "$DEV_ROOT/local-llm" "$LOCAL_BIN/local-llm"
  if [ "$DEV_PLATFORM" = linux ] && [ -x /usr/lib/wsl/lib/nvidia-smi ]; then
    shellent_add inference-cli path /usr/lib/wsl/lib
    regen_shell
  fi
}

item name=mlx-inference \
  supports=darwin \
  desc="MLX-LM — Apple Silicon inference and an OpenAI-compatible local server" \
  check='[ -x "$LOCAL_BIN/mlx_lm.server" ] && "$LOCAL_BIN/mlx_lm.server" --help >/dev/null 2>&1' \
  version='"$LOCAL_BIN/uv" tool list 2>/dev/null | sed -n "s/^mlx-lm \([^ ]*\).*/\1/p"' method=uv \
  home='~/.local/share/uv/tools/mlx-lm:isolated MLX-LM environment|~/.cache/huggingface:model cache, populated only on request' \
  shell='' network='pypi.org; huggingface.co only when a model is explicitly served' \
  system='' apps='' receipt='' \
  purge='uv tool uninstall mlx-lm 2>/dev/null || true' \
  manual='uv tool install --python 3.12 mlx-lm' \
  alt='llama.cpp is installed by the same pack for local GGUF models' \
  install=install_mlx_inference

install_mlx_inference() {
  local uv_bin
  [ "$DEV_PLATFORM" = darwin ] && [ "$DEV_ARCH" = arm64 ] || {
    err "MLX-LM requires Apple Silicon"; return 1;
  }
  uv_bin=$(command -v uv 2>/dev/null || true)
  [ -n "$uv_bin" ] || { [ -x "$LOCAL_BIN/uv" ] && uv_bin="$LOCAL_BIN/uv"; }
  [ -n "$uv_bin" ] || { err "uv missing — run: dev install uv"; return 1; }
  run "$uv_bin" tool install --python 3.12 mlx-lm
}

item name=vllm-inference \
  supports=linux \
  desc="vLLM — isolated NVIDIA inference server with an OpenAI-compatible API" \
  check='[ -x "$LOCAL_OPT/vllm/bin/vllm" ] && "$LOCAL_OPT/vllm/bin/python" -c "import torch, vllm; assert torch.cuda.is_available()" >/dev/null 2>&1' \
  version='"$LOCAL_OPT/vllm/bin/python" -c "import vllm; print(vllm.__version__)"' method=uv \
  home='~/.local/opt/vllm:isolated vLLM, PyTorch, and CUDA user-space libraries (several GB)|~/.local/bin/vllm:launcher symlink|~/.cache/huggingface:model cache, populated only on request' \
  shell='' network='pypi.org; download.pytorch.org; huggingface.co only when a model is explicitly served' \
  system='' apps='' receipt='' \
  purge='rm -rf "$HOME/.local/opt/vllm" "$HOME/.local/bin/vllm"' \
  manual='uv venv --python 3.12 --seed --managed-python ~/.local/opt/vllm && uv pip install --python ~/.local/opt/vllm/bin/python vllm --torch-backend=auto' \
  alt='Requires a supported NVIDIA GPU visible through nvidia-smi; never install a Linux NVIDIA driver inside WSL' \
  install=install_vllm_inference

install_vllm_inference() {
  local uv_bin smi caps
  [ "$DEV_PLATFORM" = linux ] || { err "vLLM requires Linux or WSL"; return 1; }
  uv_bin=$(command -v uv 2>/dev/null || true)
  [ -n "$uv_bin" ] || { [ -x "$LOCAL_BIN/uv" ] && uv_bin="$LOCAL_BIN/uv"; }
  [ -n "$uv_bin" ] || { err "uv missing — run: dev install uv"; return 1; }
  if have nvidia-smi; then
    smi=$(command -v nvidia-smi)
  elif [ -x /usr/lib/wsl/lib/nvidia-smi ]; then
    smi=/usr/lib/wsl/lib/nvidia-smi
  else
    err "nvidia-smi is missing — install/update the NVIDIA driver on Windows, not inside WSL"
    return 1
  fi
  "$smi" >/dev/null 2>&1 || {
    err "the NVIDIA GPU is not accessible inside Linux/WSL"
    return 1
  }

  caps=$("$smi" --query-gpu=compute_cap --format=csv,noheader 2>/dev/null || true)
  if [ -n "$caps" ] && ! printf '%s\n' "$caps" | awk '$1+0 >= 7.5 {ok=1} END{exit !ok}'; then
    err "vLLM requires at least one NVIDIA GPU with compute capability 7.5"
    return 1
  fi

  ensure_dirs
  rm -rf "${LOCAL_OPT:?}/vllm"
  run "$uv_bin" venv --python 3.12 --seed --managed-python "$LOCAL_OPT/vllm" || return 1
  run "$uv_bin" pip install --python "$LOCAL_OPT/vllm/bin/python" vllm --torch-backend=auto || return 1
  ln -sf "$LOCAL_OPT/vllm/bin/vllm" "$LOCAL_BIN/vllm"
  "$LOCAL_OPT/vllm/bin/python" -c 'import torch, vllm; assert torch.cuda.is_available(); print("vLLM", vllm.__version__, "CUDA ready")' \
    >>"$LOGFILE" 2>&1 || return 1
}

item name=llama-cpp \
  desc="llama.cpp server — portable CPU/GGUF fallback (Metal-enabled release on Apple Silicon)" \
  check='[ -x "$LOCAL_BIN/llama-server" ] && "$LOCAL_BIN/llama-server" --version >/dev/null 2>&1' \
  version='"$LOCAL_BIN/llama-server" --version' method=gh-tree \
  home='~/.local/opt/llama.cpp:prebuilt server and shared libraries|~/.local/bin/llama-server:launcher symlink' \
  shell='' network='api.github.com and github.com/ggml-org/llama.cpp releases' \
  system='' apps='' receipt='' \
  purge='rm -rf "$HOME/.local/opt/llama.cpp" "$HOME/.local/bin/llama-server"' \
  manual='Download the matching llama.cpp release archive and link llama-server into ~/.local/bin' \
  alt='Use MLX-LM on Apple Silicon or vLLM with NVIDIA for the primary high-throughput backend' \
  install=install_llama_cpp

install_llama_cpp() {
  ensure_dirs
  local pat url tmp found
  case "$DEV_PLATFORM:$DEV_ARCH" in
    darwin:arm64) pat='bin-macos-arm64\.tar\.gz' ;;
    darwin:x86_64) pat='bin-macos-x64\.tar\.gz' ;;
    linux:arm64) pat='bin-ubuntu-arm64\.tar\.gz' ;;
    linux:x86_64) pat='bin-ubuntu-x64\.tar\.gz' ;;
    *) err "no llama.cpp release asset for $(platform_label)"; return 1 ;;
  esac
  url=$(gh_asset_url ggml-org/llama.cpp "$pat")
  [ -n "$url" ] || url=$(gh_recent_asset_url ggml-org/llama.cpp "$pat")
  [ -n "$url" ] || { err "no llama.cpp release asset matching $pat"; return 1; }
  inf "$url"
  tmp=$(mktemp -d) || return 1
  run curl -fsSL "$url" -o "$tmp/pkg" || { rm -rf "$tmp"; return 1; }
  unpack_into "$tmp/pkg" "$tmp/x" >>"$LOGFILE" 2>&1 || { rm -rf "$tmp"; return 1; }
  found=$(find "$tmp/x" -type f -name llama-server 2>/dev/null | head -1)
  [ -n "$found" ] || { err "llama-server not found in the release archive"; rm -rf "$tmp"; return 1; }
  rm -rf "${LOCAL_OPT:?}/llama.cpp"
  mkdir -p "$LOCAL_OPT/llama.cpp"
  cp -R "$tmp/x"/. "$LOCAL_OPT/llama.cpp/"
  found=$(find "$LOCAL_OPT/llama.cpp" -type f -name llama-server 2>/dev/null | head -1)
  chmod +x "$found"
  ln -sf "$found" "$LOCAL_BIN/llama-server"
  rm -rf "$tmp"
}
