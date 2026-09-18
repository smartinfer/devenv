#!/usr/bin/env bash
cluster 00-base

item name=clt \
  supports=darwin \
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

# The dotfiles, generated files, and disclosure text all follow the login
# shell — zsh on macOS, whatever the passwd entry says on Linux. See
# shellwire_plan() in lib/platform.sh for why bash needs a different map.
item name=shellwiring \
  desc="Source lines in $(shellwire_plan | cut -d: -f1 | sed 's|^|~/|' | paste -sd', ' -) pointing at devenv/shell/" \
  check="grep -q 'devenv' \"\$HOME/$(shellwire_primary)\" 2>/dev/null" \
  version='' \
  method=verify \
  home="$(shellwire_plan | cut -d: -f1 | sed 's|^|~/|;s|$|:+3 lines|' | paste -sd'|' -)" \
  shell="$(shellwire_plan | cut -d: -f2 | tr ',' '\n' | sort -u | paste -sd', ' -):generated in devenv/shell/" \
  network='' system='' apps='' receipt='' \
  purge='devenv_unwire_shell' \
  manual="Add to $(shellwire_plan | sed 's|:| <- |' | paste -sd'; ' -) respectively: source ~/tools/devenv/shell/<file>" \
  install=install_shellwiring

install_shellwiring() {
  local m="# >>> devenv >>>" e="# <<< devenv <<<" row f gen line block oldifs
  # Generate first: the dotfiles are about to source these, and a login in
  # another terminal should never find a source line pointing at nothing.
  shellent_add shellwiring path "$LOCAL_BIN"
  shellent_add shellwiring env  'export XDG_DATA_HOME="$HOME/.local/share"'
  shellent_add shellwiring env  'export XDG_CACHE_HOME="$HOME/.cache"'
  regen_shell

  for row in $(shellwire_plan); do
    f="${row%%:*}"
    touch "$HOME/$f"
    if grep -qF "$m" "$HOME/$f" 2>/dev/null; then
      ok "$f already wired"
      continue
    fi
    block=""
    oldifs=$IFS; IFS=','; set -- ${row#*:}; IFS=$oldifs
    for gen in "$@"; do
      line="[ -f \"$DEV_SHELL/$gen\" ] && . \"$DEV_SHELL/$gen\""
      block="${block}${line}
"
    done
    printf '\n%s\n%s%s\n' "$m" "$block" "$e" >> "$HOME/$f"
    ok "wired $f"
  done
  return 0
}
