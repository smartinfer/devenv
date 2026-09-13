#!/usr/bin/env bash
# lib/platform.sh — normalized host platform information.
# DEVENV_PLATFORM/DEVENV_ARCH may be overridden by hermetic tests only.

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
