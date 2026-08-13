#!/usr/bin/env bash
cluster 41-editors

item name=vscode \
  desc="Visual Studio Code (arm64) + the 'code' shell command" \
  check='[ -d "/Applications/Visual Studio Code.app" ]' version='' method=dmg \
  home='~/Library/Application Support/Code:settings and state|~/.vscode:extensions' \
  shell='path.zsh:symlink code into ~/.local/bin' \
  network='update.code.visualstudio.com' system='' \
  apps='/Applications/Visual Studio Code.app:~350MB' receipt='' \
  purge='rm -rf "/Applications/Visual Studio Code.app" "$HOME/Library/Application Support/Code" "$HOME/.vscode" "$HOME/.local/bin/code"' \
  manual='Download from https://code.visualstudio.com/download (Apple silicon), drag to /Applications' \
  install=install_vscode
install_vscode() {
  local tmp; tmp=$(mktemp -d)
  run curl -fsSL "https://update.code.visualstudio.com/latest/darwin-arm64/stable" -o "$tmp/v.zip" || { rm -rf "$tmp"; return 1; }
  unzip -q "$tmp/v.zip" -d "$tmp" >>"$LOGFILE" 2>&1
  cp -R "$tmp/Visual Studio Code.app" /Applications/ || { rm -rf "$tmp"; return 1; }
  ln -sf "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" "$LOCAL_BIN/code"
  rm -rf "$tmp"; return 0
}

item name=cursor \
  desc="Cursor editor + the 'cursor' shell command (manual download)" \
  check='[ -d "/Applications/Cursor.app" ]' version='' method=manual \
  home='~/Library/Application Support/Cursor:settings|~/.cursor:extensions' \
  shell='path.zsh:symlink cursor into ~/.local/bin' \
  network='cursor.com/download (manual)' system='' \
  apps='/Applications/Cursor.app:~400MB' receipt='' \
  purge='rm -rf "/Applications/Cursor.app" "$HOME/Library/Application Support/Cursor" "$HOME/.cursor" "$HOME/.local/bin/cursor"' \
  manual='Download the Apple silicon .dmg from https://cursor.com/download, drag Cursor.app to /Applications, then: ln -sf "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" ~/.local/bin/cursor' \
  install=install_cursor
install_cursor() {
  if [ -d "/Applications/Cursor.app" ]; then
    ln -sf "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" "$LOCAL_BIN/cursor"
    return 0
  fi
  warn "Cursor has no stable direct-download URL, so this step is manual."
  inf "1. open https://cursor.com/download  (Apple silicon)"
  inf "2. drag Cursor.app to /Applications"
  inf "3. re-run: dev install cursor"
  return 1
}
