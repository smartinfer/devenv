#!/usr/bin/env bash
cluster 22-functional

item name=ocaml \
  desc="OCaml 5.x via opam — dune, merlin, ocaml-lsp, ocamlformat, utop" \
  check='command -v ocaml' version='ocaml -version' method=script \
  home='~/.opam:switch + packages ~1.2GB|~/.local/bin/opam:binary' \
  shell='interactive.zsh:eval opam env' \
  network='https://opam.ocaml.org/install.sh' system='' apps='' receipt='' \
  purge='rm -rf "$HOME/.opam" "$HOME/.local/bin/opam"' \
  manual='See https://opam.ocaml.org/doc/Install.html then: opam init --bare; opam switch create 5.2.0' \
  install=install_ocaml

install_ocaml() {
  ensure_dirs
  if ! have opam; then
    # Resolve the asset from the API. Never hardcode a version under
    # /latest/download/ — the filename will not match the newest release.
    local url
    url=$(gh_asset_url ocaml/opam 'macos-arm64$')
    [ -n "$url" ] || url=$(gh_asset_url ocaml/opam 'arm64.*macos|macos.*arm64')
    if [ -n "$url" ]; then
      inf "$url"
      run curl -fsSL "$url" -o "$LOCAL_BIN/opam" && chmod +x "$LOCAL_BIN/opam"
    else
      install_via_script "https://opam.ocaml.org/install.sh" || return 1
    fi
  fi
  have opam || { err "opam not on PATH after install"; return 1; }
  [ -d "$HOME/.opam" ] || run opam init --bare --disable-sandboxing -y
  eval "$(opam env 2>/dev/null)"
  opam switch list --short 2>/dev/null | grep -q '^5\.' || run opam switch create 5.2.0 -y
  eval "$(opam env 2>/dev/null)"
  run opam install -y dune merlin ocaml-lsp-server ocamlformat utop odoc zarith menhir alcotest qcheck
  shellent_add ocaml hook 'eval "$(opam env 2>/dev/null)"'
  regen_shell
  return 0
}

item name=haskell \
  desc="GHC + cabal + stack + HLS via GHCup" \
  check='command -v ghc' version='ghc --version' method=script \
  home='~/.ghcup:compilers ~3GB|~/.cabal:package db ~500MB' \
  shell='path.zsh:$HOME/.ghcup/bin|interactive.zsh:source ghcup env' \
  network='https://get-ghcup.haskell.org' system='' apps='' receipt='' \
  purge='ghcup nuke 2>/dev/null; rm -rf "$HOME/.ghcup" "$HOME/.cabal"' \
  manual='curl --proto "=https" --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh' \
  install=install_haskell

install_haskell() {
  if ! have ghcup; then
    BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
    BOOTSTRAP_HASKELL_INSTALL_HLS=1 \
    BOOTSTRAP_HASKELL_ADJUST_BASHRC=0 \
    install_via_script "https://get-ghcup.haskell.org" || return 1
  fi
  [ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env"
  run ghcup install ghc recommended --set
  run ghcup install cabal recommended --set
  run cabal update
  shellent_add haskell path "$HOME/.ghcup/bin"
  regen_shell
  return 0
}
