#!/usr/bin/env bash
cluster 21-python

item name=python-runtimes \
  desc="CPython 3.12 and 3.13 managed by uv — never Apple's /usr/bin/python3" \
  check='uv python list --only-installed 2>/dev/null | grep -q 3.12' \
  version='uv --version' method=uv \
  home='~/.local/share/uv/python:2 interpreters ~200MB' \
  shell='env.zsh:HF_HOME, HF_HUB_ENABLE_HF_TRANSFER, TOKENIZERS_PARALLELISM, PYTORCH_ENABLE_MPS_FALLBACK' \
  network='python-build-standalone releases, via uv' system='' apps='' receipt='' \
  purge='rm -rf "$HOME/.local/share/uv/python"' \
  manual='uv python install 3.12 3.13' \
  install=install_python_runtimes

install_python_runtimes() {
  have uv || { err "uv missing — run: dev install uv"; return 1; }
  run uv python install 3.12 3.13 || return 1
  shellent_add python-runtimes env 'export HF_HOME="$HOME/.cache/huggingface"'
  shellent_add python-runtimes env 'export HF_HUB_ENABLE_HF_TRANSFER=1'
  shellent_add python-runtimes env 'export TOKENIZERS_PARALLELISM=false'
  shellent_add python-runtimes env 'export PYTORCH_ENABLE_MPS_FALLBACK=1'
  regen_shell
  return 0
}

item name=python-tools \
  desc="Global Python CLIs, each in its own uv-managed venv: ruff, mypy, ipython, jupyterlab, hf, mlx-lm" \
  check='command -v ruff >/dev/null && command -v ipython' version='ruff --version' method=uv \
  home='~/.local/share/uv/tools:one venv per tool|~/.local/bin:shims' shell='' \
  network='pypi.org' system='' apps='' receipt='' \
  purge='for t in ruff mypy ipython pre-commit jupyterlab httpie huggingface_hub mlx-lm; do uv tool uninstall "$t" 2>/dev/null; done' \
  manual='uv tool install ruff; uv tool install mypy; uv tool install ipython' \
  install=install_python_tools

install_python_tools() {
  have uv || { err "uv missing"; return 1; }
  local t
  for t in ruff mypy ipython pre-commit jupyterlab httpie; do
    run uv tool install --python 3.12 "$t" || warn "uv tool $t failed"
  done
  run uv tool install --python 3.12 "huggingface_hub[cli,hf_transfer]" || warn "huggingface_hub failed"
  run uv tool install --python 3.12 mlx-lm || warn "mlx-lm failed"
  return 0
}
