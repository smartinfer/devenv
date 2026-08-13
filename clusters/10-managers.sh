#!/usr/bin/env bash
cluster 10-managers

item name=mise \
  desc="mise — declarative runtime manager for node, go, jvm (reads ~/.mac-env/mise.toml)" \
  check='command -v mise' version='mise --version' method=script \
  home='~/.local/bin/mise:binary|~/.local/share/mise:runtimes ~600MB|~/.config/mise:symlink to config|~/.mac-env:your mise.toml' \
  shell='interactive.zsh:eval mise activate zsh' \
  network='https://mise.run' system='' apps='' receipt='' \
  purge='rm -rf "$HOME/.local/share/mise" "$HOME/.config/mise" "$HOME/.local/bin/mise" "$HOME/.mac-env/mise.toml"' \
  manual='curl -fsSL https://mise.run | sh' \
  install=install_mise

install_mise() {
  ensure_dirs
  have mise || install_via_script "https://mise.run" || return 1
  mkdir -p "$HOME/.mac-env" "$HOME/.config/mise"
  [ -f "$HOME/.mac-env/mise.toml" ] || cp "$DEV_ROOT/mise.toml" "$HOME/.mac-env/mise.toml"
  ln -sf "$HOME/.mac-env/mise.toml" "$HOME/.config/mise/config.toml"
  shellent_add mise hook 'eval "$($HOME/.local/bin/mise activate zsh)"'
  regen_shell
  inf "reconciling runtimes declared in ~/.mac-env/mise.toml"
  run "$LOCAL_BIN/mise" install -y || warn "mise install returned nonzero — check the toml"
  return 0
}

item name=uv \
  desc="uv — sole owner of Python: interpreters, venvs, tools, and cache" \
  check='command -v uv' version='uv --version' method=script \
  home='~/.local/bin/uv:binary|~/.local/share/uv:interpreters and tools|~/.cache/uv:package cache' \
  shell='env.zsh:UV_PYTHON_PREFERENCE=only-managed' \
  network='https://astral.sh/uv/install.sh' system='' apps='' receipt='' \
  purge='rm -rf "$HOME/.local/share/uv" "$HOME/.cache/uv" "$HOME/.local/bin/uv" "$HOME/.local/bin/uvx"' \
  manual='curl -LsSf https://astral.sh/uv/install.sh | sh' \
  install=install_uv

install_uv() {
  ensure_dirs
  have uv || install_via_script "https://astral.sh/uv/install.sh" || return 1
  shellent_add uv env 'export UV_PYTHON_PREFERENCE=only-managed'
  regen_shell
  return 0
}
