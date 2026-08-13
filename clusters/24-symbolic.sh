#!/usr/bin/env bash
cluster 24-symbolic

item name=sbcl \
  desc="Steel Bank Common Lisp — prebuilt arm64-darwin tarball, not compiled from source" \
  check='command -v sbcl' version='sbcl --version' method=tarball \
  home='~/.local/bin/sbcl:binary|~/.local/lib/sbcl:core + contribs ~60MB' shell='' \
  network='sbcl.org / SourceForge release tarball' system='' apps='' receipt='' \
  purge='rm -rf "$HOME/.local/bin/sbcl" "$HOME/.local/lib/sbcl"' \
  manual='Get the arm64-darwin binary from https://www.sbcl.org/platform-table.html then: tar -xjf sbcl-*.tar.bz2 && cd sbcl-* && INSTALL_ROOT=~/.local sh install.sh' \
  alt="mise's sbcl plugin compiles from source, needs ECL to bootstrap on macOS plus zstd with CPATH/LIBRARY_PATH set — its own README recommends against it" \
  install=install_sbcl

SBCL_VERSION="${SBCL_VERSION:-2.4.10}"
install_sbcl() {
  ensure_dirs
  local tmp url
  url="https://downloads.sourceforge.net/project/sbcl/sbcl/${SBCL_VERSION}/sbcl-${SBCL_VERSION}-arm64-darwin-binary.tar.bz2"
  inf "$url"
  inf "version is pinned by SBCL_VERSION (currently $SBCL_VERSION) — bump it if this 404s"
  tmp=$(mktemp -d)
  run curl -fsSL "$url" -o "$tmp/s.tar.bz2" || { err "download failed; check the version"; rm -rf "$tmp"; return 1; }
  tar -xjf "$tmp/s.tar.bz2" -C "$tmp" >>"$LOGFILE" 2>&1
  local d; d=$(find "$tmp" -maxdepth 1 -type d -name 'sbcl-*' | head -1)
  [ -n "$d" ] || { err "unexpected tarball layout"; rm -rf "$tmp"; return 1; }
  runsh "cd '$d' && INSTALL_ROOT='$LOCAL_PREFIX' sh install.sh"
  rm -rf "$tmp"
  have sbcl
}

item name=quicklisp \
  desc="Quicklisp library manager for Common Lisp" \
  check='[ -d "$HOME/quicklisp" ]' version='' method=script \
  home='~/quicklisp:library cache|~/.sbclrc:+1 load line' shell='' \
  network='https://beta.quicklisp.org/quicklisp.lisp' system='' apps='' receipt='' \
  purge='rm -rf "$HOME/quicklisp"' \
  manual='curl -O https://beta.quicklisp.org/quicklisp.lisp && sbcl --load quicklisp.lisp' \
  install=install_quicklisp

install_quicklisp() {
  have sbcl || { err "sbcl required first"; return 1; }
  run curl -fsSL -o /tmp/ql.lisp https://beta.quicklisp.org/quicklisp.lisp || return 1
  runsh "sbcl --non-interactive --load /tmp/ql.lisp --eval '(quicklisp-quickstart:install)' --eval '(ql:add-to-init-file)'"
  [ -d "$HOME/quicklisp" ]
}

item name=prolog \
  desc="Scryer Prolog — ISO-conforming, written in Rust, no GUI app bundle" \
  check='command -v scryer-prolog || command -v swipl' version='scryer-prolog --version' method=cargo \
  home='~/.cargo/bin/scryer-prolog:binary|~/.cargo/registry:build cache' shell='' \
  network='crates.io' system='' apps='' receipt='' \
  purge='cargo uninstall scryer-prolog 2>/dev/null || rm -f "$HOME/.cargo/bin/scryer-prolog"' \
  manual='cargo install scryer-prolog' \
  alt='SWI-Prolog instead: download the .dmg from swi-prolog.org/download/stable, drag to /Applications, then ln -sf /Applications/SWI-Prolog.app/Contents/MacOS/swipl ~/.local/bin/swipl' \
  install=install_prolog

install_prolog() {
  have cargo || { err "rust required first — run: dev install rust"; return 1; }
  run cargo install scryer-prolog
}
