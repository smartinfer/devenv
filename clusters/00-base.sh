#!/usr/bin/env bash
cluster 00-base

item name=clt \
  desc="Apple Command Line Tools — clang, ld, make, git, and the macOS SDK" \
  check='xcode-select -p >/dev/null 2>&1' \
  version='clang --version' \
  method=verify \
  home='' \
  shell='' \
  network='Apple softwareupdate (GUI installer)' \
  system='/Library/Developer/CommandLineTools:~1.5GB, clang + SDK + headers' \
  apps='' \
  receipt='pkgutil receipt com.apple.pkg.CLTools_Executables' \
  purge='sudo rm -rf /Library/Developer/CommandLineTools' \
  manual='xcode-select --install    # then finish the GUI installer' \
  alt='Full Xcode (~15GB) only if you compile Metal shaders or build for iOS' \
  install=install_clt

install_clt() {
  xcode-select -p >/dev/null 2>&1 && return 0
  warn "Apple opens its own GUI installer. Finish it, then re-run this item."
  run xcode-select --install
  return 1
}

item name=shellwiring \
  desc="Three source lines in ~/.zshenv, ~/.zprofile, ~/.zshrc pointing at devenv/shell/" \
  check='grep -q "devenv" "$HOME/.zprofile" 2>/dev/null' \
  version='' \
  method=verify \
  home='~/.zshenv:+3 lines|~/.zprofile:+3 lines|~/.zshrc:+3 lines' \
  shell='env.zsh, path.zsh, interactive.zsh:generated in devenv/shell/' \
  network='' system='' apps='' receipt='' \
  purge='devenv_unwire_shell' \
  manual='Add to .zshenv/.zprofile/.zshrc respectively: source ~/tools/devenv/shell/{env,path,interactive}.zsh' \
  install=install_shellwiring

install_shellwiring() {
  local m="# >>> devenv >>>" e="# <<< devenv <<<" f line
  touch "$HOME/.zshenv" "$HOME/.zprofile" "$HOME/.zshrc"
  for f in zshenv zprofile zshrc; do
    case "$f" in
      zshenv)   line="[ -f \"$DEV_SHELL/env.zsh\" ] && source \"$DEV_SHELL/env.zsh\"" ;;
      zprofile) line="[ -f \"$DEV_SHELL/path.zsh\" ] && source \"$DEV_SHELL/path.zsh\"" ;;
      zshrc)    line="[ -f \"$DEV_SHELL/interactive.zsh\" ] && source \"$DEV_SHELL/interactive.zsh\"" ;;
    esac
    if grep -qF "$m" "$HOME/.$f" 2>/dev/null; then
      ok ".$f already wired"
    else
      printf '\n%s\n%s\n%s\n' "$m" "$line" "$e" >> "$HOME/.$f"
      ok "wired .$f"
    fi
  done
  shellent_add shellwiring path "$LOCAL_BIN"
  shellent_add shellwiring env  'export XDG_DATA_HOME="$HOME/.local/share"'
  shellent_add shellwiring env  'export XDG_CACHE_HOME="$HOME/.cache"'
  regen_shell
  return 0
}
