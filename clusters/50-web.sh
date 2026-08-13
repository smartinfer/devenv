#!/usr/bin/env bash
cluster 50-web

item name=frankenphp \
  desc="FrankenPHP — one static binary containing the PHP runtime and a web server" \
  check='command -v frankenphp' version='frankenphp version' method=gh-binary \
  home='~/.local/bin/frankenphp:~50MB' shell='' \
  network='github.com/php/frankenphp releases' system='' apps='' receipt='' \
  purge='rm -f "$HOME/.local/bin/frankenphp"' \
  manual='Download the mac-arm64 binary from github.com/php/frankenphp/releases into ~/.local/bin' \
  alt='macOS stopped bundling PHP in Monterey; building php from source without a package manager means extension hell' \
  install=install_frankenphp
install_frankenphp() { install_gh_bin php/frankenphp 'mac-arm64' frankenphp; }

item name=composer \
  desc="Composer — PHP dependency manager (single .phar)" \
  check='command -v composer' version='composer --version' method=phar \
  home='~/.local/bin/composer:~3MB|~/.composer:cache' shell='' \
  network='getcomposer.org' system='' apps='' receipt='' \
  purge='rm -rf "$HOME/.local/bin/composer" "$HOME/.composer"' \
  manual='curl -fsSL https://getcomposer.org/composer-stable.phar -o ~/.local/bin/composer && chmod +x ~/.local/bin/composer' \
  install=install_composer
install_composer() {
  ensure_dirs
  run curl -fsSL https://getcomposer.org/composer-stable.phar -o "$LOCAL_BIN/composer" || return 1
  chmod +x "$LOCAL_BIN/composer"
}

item name=caddy \
  desc="Caddy — static file server and reverse proxy, single Go binary" \
  check='command -v caddy' version='caddy version' method=gh-binary \
  home='~/.local/bin/caddy:~45MB' shell='' \
  network='github.com/caddyserver/caddy releases' system='' apps='' receipt='' \
  purge='rm -f "$HOME/.local/bin/caddy"' \
  manual='Download the mac_arm64 tarball from github.com/caddyserver/caddy/releases into ~/.local/bin' \
  install=install_caddy
install_caddy() { install_gh_bin caddyserver/caddy 'mac_arm64' caddy; }
