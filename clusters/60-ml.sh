#!/usr/bin/env bash
cluster 60-ml

item name=mlx-check \
  desc="Verify MLX runs on the GPU — installs nothing globally, uses an ephemeral uv env" \
  check='false' version='' method=verify \
  home='~/.cache/uv:ephemeral env, cached' shell='' \
  network='pypi.org (via uvx)' system='' apps='' receipt='' \
  purge='true  # nothing installed' \
  manual='uvx --with mlx python -c "import mlx.core as mx; print(mx.default_device())"' \
  install=install_mlx_check

install_mlx_check() {
  have uv || { err "uv missing — run: dev install uv"; return 1; }
  local osv; osv=$(sw_vers -productVersion 2>/dev/null || echo 0)
  if [ "$(printf '%s\n26.2\n' "$osv" | sort -V | head -1)" != "26.2" ]; then
    warn "macOS $osv is below 26.2 — MLX will not use the M5 Neural Accelerators"
    warn "(you keep the memory-bandwidth gain but lose the ~4x prefill speedup)"
  fi
  runsh "uvx --with mlx python -c \"
import mlx.core as mx
a = mx.random.normal((4096,4096)); mx.eval(a @ a.T)
print('mlx', mx.__version__, 'device', mx.default_device(), 'matmul OK')\""
  local rc=$?
  cat <<'NOTE'

    No ML packages are installed globally. That is deliberate.

    Throwaway experiment, no venv at all (PEP 723 inline metadata):
        # /// script
        # dependencies = ["mlx-lm", "numpy"]
        # ///
      then:  uv run experiment.py

    Real project:
        mkdir ft && cd ft && uv init && uv add mlx mlx-lm transformers
        uv run python train.py

    uv hardlinks from one global cache, so N venvs sharing torch cost ~1 copy.

    CUDA-only, never installable here — keep behind a [cuda] extra and run on
    GCP: vllm, triton, flash-attn, bitsandbytes, autoawq, deepspeed, faiss-gpu.

    GPU wired-memory ceiling (default is ~75% of RAM):
        sudo sysctl iogpu.wired_limit_mb=122880    # ~120GB of 128GB
    Resets on reboot. Never use 131072 — starving the OS hard-hangs the Mac.
NOTE
  return $rc
}
