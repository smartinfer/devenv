#!/usr/bin/env bash
# lib/platform.sh — normalized host platform and login-shell information.
# DEVENV_PLATFORM/DEVENV_ARCH/DEVENV_SHELL_KIND may be overridden by hermetic
# tests only.

shell_label() { printf '%s (shell/*.%s)' "$DEV_SHELL_KIND" "$DEV_SHELL_EXT"; }

detect_platform() {
  local raw_os raw_arch
  raw_os="${DEVENV_PLATFORM:-$(uname -s 2>/dev/null)}"
  raw_arch="${DEVENV_ARCH:-$(uname -m 2>/dev/null)}"

  case "$raw_os" in
    Darwin|darwin|macos) DEV_PLATFORM=darwin ;;
    Linux|linux)         DEV_PLATFORM=linux ;;
    *)                   DEV_PLATFORM=unsupported ;;
  esac
  case "$raw_arch" in
    arm64|aarch64) DEV_ARCH=arm64 ;;
    x86_64|amd64)  DEV_ARCH=x86_64 ;;
    *)             DEV_ARCH="$raw_arch" ;;
  esac

  DEV_DISTRO=""
  if [ "$DEV_PLATFORM" = linux ]; then
    if [ -n "${DEVENV_DISTRO:-}" ]; then
      DEV_DISTRO="$DEVENV_DISTRO"
    elif [ -r /etc/os-release ]; then
      DEV_DISTRO=$(sed -n 's/^ID=//p' /etc/os-release | head -1 | tr -d '"')
    fi
  fi
  if [ "$DEV_PLATFORM" = darwin ]; then
    DEV_CONFIG_DIR="$HOME/.mac-env"
  else
    DEV_CONFIG_DIR="$HOME/.devenv"
  fi
  export DEV_PLATFORM DEV_ARCH DEV_DISTRO DEV_CONFIG_DIR
}

# Which shell family devenv generates files for, and the extension it uses.
#
# macOS is pinned to zsh: it is the system default there, and the whole
# ~/.zprofile-after-path_helper ordering this repo documents only makes sense
# for zsh. On Linux the login shell decides, because Debian-family systems
# ship bash and wiring the zsh dotfiles there generates files no shell reads.
detect_shell_kind() {
  local raw="${DEVENV_SHELL_KIND:-}" login
  if [ -z "$raw" ] && [ "$DEV_PLATFORM" = darwin ]; then raw=zsh; fi
  if [ -z "$raw" ]; then
    login="${SHELL:-}"
    case "$login" in
      */zsh|zsh|*/bash|bash) : ;;
      # $SHELL is unset or something unexpected (cron, a container, an
      # editor's task runner). The passwd entry is the durable answer.
      *) login=$(getent passwd "$(id -un 2>/dev/null)" 2>/dev/null | awk -F: '{print $7}') ;;
    esac
    case "$login" in
      */zsh|zsh) raw=zsh ;;
      *)         raw=bash ;;
    esac
  fi
  case "$raw" in
    zsh) DEV_SHELL_KIND=zsh;  DEV_SHELL_EXT=zsh ;;
    *)   DEV_SHELL_KIND=bash; DEV_SHELL_EXT=sh ;;
  esac
  # Generated-file names, so cluster files can disclose the real filename
  # without every item repeating the extension logic.
  DEV_F_ENV="env.$DEV_SHELL_EXT"
  DEV_F_PATH="path.$DEV_SHELL_EXT"
  DEV_F_INT="interactive.$DEV_SHELL_EXT"
  export DEV_SHELL_KIND DEV_SHELL_EXT DEV_F_ENV DEV_F_PATH DEV_F_INT
}

# The wiring plan: which dotfile sources which generated file(s).
# Rows are "<dotfile>:<generated>[,<generated>...]".
shellwire_plan() {
  if [ "$DEV_SHELL_KIND" = zsh ]; then
    printf '%s\n' \
      '.zshenv:env.zsh' \
      '.zprofile:path.zsh' \
      '.zshrc:interactive.zsh'
  else
    # bash has no ~/.zshenv equivalent — no file it reads for every shell.
    # ~/.profile carries env and PATH into the login session, which on a
    # desktop is inherited by every terminal and agent spawned from it;
    # ~/.bashrc repeats it for non-login interactive shells and adds hooks.
    # Repeating is safe: env entries are plain exports and path.sh
    # de-duplicates before it prepends.
    # A bash login reads ~/.bash_profile instead of ~/.profile when it
    # exists, so wire whichever one bash will actually read. Neither is
    # ever created as a side effect beyond the one chosen here.
    printf '%s\n' \
      "$(bash_login_file):env.sh" \
      '.bashrc:env.sh,interactive.sh'
  fi
}

bash_login_file() {
  if [ -f "$HOME/.bash_profile" ]; then printf '.bash_profile'; else printf '.profile'; fi
}

# The dotfile whose marker block means "shell wiring is installed".
shellwire_primary() {
  if [ "$DEV_SHELL_KIND" = zsh ]; then printf '.zprofile'; else bash_login_file; fi
}

# Every dotfile devenv may have written a marker block into, either family.
# Purge has to clean up after a login-shell change, so it is not filtered.
shellwire_all_dotfiles() { printf '%s\n' .zshenv .zprofile .zshrc .profile .bash_profile .bashrc; }

platform_supported() {
  case "$DEV_PLATFORM" in darwin|linux) return 0 ;; *) return 1 ;; esac
}

platform_label() {
  if [ "$DEV_PLATFORM" = linux ] && [ -n "$DEV_DISTRO" ]; then
    printf '%s/%s (%s)' "$DEV_PLATFORM" "$DEV_DISTRO" "$DEV_ARCH"
  else
    printf '%s (%s)' "$DEV_PLATFORM" "$DEV_ARCH"
  fi
}

supports_platform() { # comma-separated platform list
  case ",${1:-darwin,linux}," in *",$DEV_PLATFORM,"*) return 0 ;; *) return 1 ;; esac
}

detect_platform
detect_shell_kind
