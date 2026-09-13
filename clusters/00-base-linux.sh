#!/usr/bin/env bash
cluster 00-base

item name=build-tools \
  supports=linux \
  desc="Linux native build prerequisites — compiler, make, git, curl, archives, and TLS headers" \
  check='dpkg-query -W build-essential curl git unzip zip ca-certificates pkg-config libssl-dev zsh >/dev/null 2>&1' \
  version='cc --version' \
  method=system \
  home='' shell='' \
  network='Ubuntu package repositories via apt' \
  system='/usr/bin:distribution-owned build tools and utilities|/usr/include:development headers' \
  apps='' receipt='apt/dpkg package database; pre-existing packages are not owned by devenv' \
  purge='true  # system prerequisites are shared and intentionally not removed' \
  manual='sudo apt-get update && sudo apt-get install build-essential curl git unzip zip ca-certificates pkg-config libssl-dev zsh' \
  alt='On a non-Debian distribution, install equivalent compiler, TLS, archive, Git, curl, and zsh packages manually' \
  install=install_linux_build_tools

install_linux_build_tools() {
  [ "$DEV_PLATFORM" = linux ] || return 1
  case "$DEV_DISTRO" in
    ubuntu|debian|linuxmint|pop)
      run sudo apt-get update || return 1
      run sudo apt-get install -y build-essential curl git unzip zip ca-certificates pkg-config libssl-dev zsh
      ;;
    *)
      err "automatic base install currently supports Debian/Ubuntu-family Linux only"
      inf "use the manual command shown by: dev status --commands"
      return 1
      ;;
  esac
}
