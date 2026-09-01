#!/usr/bin/env bash
cluster 21-python

item name=python-runtimes \
  desc="CPython 3.12 and 3.13 managed by uv — never Apple's /usr/bin/python3" \
  check='uv python list --only-installed 2>/dev/null | grep -q 3.12' \
  version='uv --version' method=uv \
  home='~/.local/share/uv/python:2 interpreters ~200MB' \
  shell='env.zsh:TOKENIZERS_PARALLELISM, PYTORCH_ENABLE_MPS_FALLBACK' \
  network='python-build-standalone releases, via uv' system='' apps='' receipt='' \
  purge='rm -rf "$HOME/.local/share/uv/python"' \
  manual='uv python install 3.12 3.13' \
  install=install_python_runtimes

install_python_runtimes() {
  have uv || { err "uv missing — run: dev install uv"; return 1; }
  run uv python install 3.12 3.13 || return 1
  shellent_add python-runtimes env 'export TOKENIZERS_PARALLELISM=false'
  shellent_add python-runtimes env 'export PYTORCH_ENABLE_MPS_FALLBACK=1'
  regen_shell
  return 0
}

item name=python-tools \
  desc="Global Python CLIs, each in its own uv-managed venv: ruff, mypy, ipython, jupyterlab, mlx-lm" \
  check='command -v ruff >/dev/null && command -v ipython' version='ruff --version' method=uv \
  home='~/.local/share/uv/tools:one venv per tool|~/.local/bin:shims' shell='' \
  network='pypi.org' system='' apps='' receipt='' \
  purge='for t in ruff mypy ipython pre-commit jupyterlab httpie mlx-lm; do uv tool uninstall "$t" 2>/dev/null; done' \
  manual='uv tool install ruff; uv tool install mypy; uv tool install ipython' \
  install=install_python_tools

install_python_tools() {
  have uv || { err "uv missing"; return 1; }
  local t
  for t in ruff mypy ipython pre-commit jupyterlab httpie; do
    run uv tool install --python 3.12 "$t" || warn "uv tool $t failed"
  done
  run uv tool install --python 3.12 mlx-lm || warn "mlx-lm failed"
  return 0
}

item name=huggingface \
  desc="Hugging Face Hub CLI and Python library — models, datasets, Spaces, Jobs, and cache management" \
  check='command -v hf >/dev/null && grep -q "HF_XET_HIGH_PERFORMANCE" "$DEV_SHELL/env.zsh" 2>/dev/null && grep -q "unset HF_HUB_ENABLE_HF_TRANSFER" "$DEV_SHELL/env.zsh" 2>/dev/null' \
  version='hf version' method=uv \
  home='~/.local/share/uv/tools/huggingface-hub:isolated CLI/library environment|~/.cache/huggingface:models, datasets, Hub and Xet caches (can grow very large)' \
  shell='env.zsh:HF_HOME and HF_XET_HIGH_PERFORMANCE' \
  network='pypi.org; huggingface.co Hub, model, dataset, Space, and Jobs APIs' \
  system='' apps='' receipt='' \
  purge='uv tool uninstall huggingface-hub; rm -rf "$HOME/.cache/huggingface"' \
  manual='uv tool install --python 3.12 huggingface_hub' \
  alt='Use uvx hf for occasional commands; the managed install is preferred here because Hugging Face is a default AI/data tool' \
  install=install_huggingface

install_huggingface() {
  have uv || { err "uv missing — run: dev install uv"; return 1; }
  run uv tool install --python 3.12 huggingface_hub || return 1

  # Migrate HF settings formerly owned by python-runtimes. Rebuild that
  # item's remaining entries so existing machines lose the deprecated
  # HF_HUB_ENABLE_HF_TRANSFER setting without losing unrelated ML settings.
  shellent_del_item python-runtimes
  shellent_add python-runtimes env 'export TOKENIZERS_PARALLELISM=false'
  shellent_add python-runtimes env 'export PYTORCH_ENABLE_MPS_FALLBACK=1'
  shellent_add huggingface env 'export HF_HOME="$HOME/.cache/huggingface"'
  shellent_add huggingface env 'export HF_XET_HIGH_PERFORMANCE=1'
  shellent_add huggingface env 'unset HF_HUB_ENABLE_HF_TRANSFER'
  regen_shell
  return 0
}
