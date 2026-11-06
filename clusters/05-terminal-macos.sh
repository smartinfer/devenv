#!/usr/bin/env bash
cluster 05-terminal-macos

item name=ghostty \
  supports=darwin \
  desc="Ghostty — native GPU-accelerated macOS terminal with managed config and CLI" \
  check='[ -d "/Applications/Ghostty.app" ] && [ -L "$HOME/.local/bin/ghostty" ] && [ -L "$HOME/.config/ghostty/config.ghostty" ]' \
  version='plutil -extract CFBundleShortVersionString raw -o - "/Applications/Ghostty.app/Contents/Info.plist"' \
  method=manual \
  home='~/.config/ghostty/config.ghostty:symlink to tracked devenv config|~/.local/bin/ghostty:CLI symlink' \
  shell='Ghostty:zsh shell integration enabled by the terminal' \
  network='ghostty.org/download (official signed and notarized DMG)' system='' \
  apps='/Applications/Ghostty.app:native macOS terminal' receipt='' \
  purge='rm -rf "/Applications/Ghostty.app"; rm -f "$HOME/.local/bin/ghostty" "$HOME/.config/ghostty/config.ghostty"' \
  manual='Download the official macOS DMG from https://ghostty.org/download, drag Ghostty.app to /Applications, then re-run: dev install ghostty' \
  install=install_ghostty
install_ghostty() {
  local app="/Applications/Ghostty.app"
  local bin="$app/Contents/MacOS/ghostty"
  local config_dir="$HOME/.config/ghostty"
  local config="$config_dir/config.ghostty"
  local source_config="$DEV_ROOT/terminal/ghostty/config.ghostty"

  if [ ! -x "$bin" ]; then
    warn "Ghostty's official macOS build is a signed, notarized DMG installed manually."
    inf "1. download it from https://ghostty.org/download"
    inf "2. drag Ghostty.app to /Applications"
    inf "3. re-run: dev install ghostty"
    return 1
  fi

  ensure_dirs
  mkdir -p "$config_dir"
  if [ -e "$config" ] && [ ! -L "$config" ]; then
    err "$config already exists and is not managed by devenv"
    inf "Preserve it, or move it aside before re-running this item."
    return 1
  fi
  ln -sf "$bin" "$LOCAL_BIN/ghostty"
  ln -sf "$source_config" "$config"
  return 0
}

item name=zsh-theme \
  supports=darwin \
  desc="Zsh prompt — color, Git state, exit status, path, and time without a framework" \
  check='grep -qF "terminal/zsh-theme.zsh" "$DEV_SHELL/interactive.zsh" 2>/dev/null' \
  version='' method=verify home='' \
  shell='interactive.zsh:source tracked terminal/zsh-theme.zsh' \
  network='' system='' apps='' receipt='' purge=':' \
  manual='Add: [ -r "$DEV_ROOT/terminal/zsh-theme.zsh" ] && source "$DEV_ROOT/terminal/zsh-theme.zsh"' \
  install=install_zsh_theme
install_zsh_theme() {
  shellent_add zsh-theme hook '[ -r "$DEV_ROOT/terminal/zsh-theme.zsh" ] && source "$DEV_ROOT/terminal/zsh-theme.zsh"'
  regen_shell
  return 0
}
