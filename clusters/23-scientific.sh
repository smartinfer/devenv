#!/usr/bin/env bash
cluster 23-scientific

item name=r \
  desc="R for arm64 macOS via the official CRAN installer (system framework)" \
  check='command -v R' version='R --version' method=manual \
  home='~/Library/R:per-user R packages' \
  shell='path.zsh:/Library/Frameworks/R.framework/Resources/bin' \
  network='https://cran.r-project.org/bin/macosx/big-sur-arm64/base/' \
  system='/Library/Frameworks/R.framework:official R framework|/usr/local/bin/R:command links' \
  apps='' receipt='org.r-project.R' \
  purge='sudo rm -rf /Library/Frameworks/R.framework /usr/local/bin/R /usr/local/bin/Rscript' \
  manual='Download and install the current arm64 R package from https://cran.r-project.org/bin/macosx/big-sur-arm64/base/; this requires administrator approval.' \
  install=install_r

install_r() {
  have R && return 0
  local tmp pkg local_pkg
  tmp=$(mktemp -d) || return 1
  local_pkg=$(find "$HOME/Downloads" -maxdepth 1 -type f -name 'R-*-arm64.pkg' 2>/dev/null \
    | sort -V | tail -1)
  if [ -n "$local_pkg" ]; then
    pkg="$local_pkg"
    inf "using downloaded CRAN arm64 package: $pkg"
  else
    local base="https://cran.r-project.org/bin/macosx/big-sur-arm64/base"
    local name
    name=$(curl -fsSL "$base/" | grep -oE 'R-[0-9]+\.[0-9]+\.[0-9]+-arm64\.pkg' | sort -V | tail -1)
    [ -n "$name" ] || { err "no arm64 R package found in CRAN listing"; rm -rf "$tmp"; return 1; }
    local url="$base/$name"
    inf "official CRAN arm64 package: $url"
    run curl -fsSL "$url" -o "$tmp/R.pkg" || { rm -rf "$tmp"; return 1; }
    pkg="$tmp/R.pkg"
  fi
  run sudo installer -pkg "$pkg" -target / || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  shellent_add r path "/Library/Frameworks/R.framework/Resources/bin"
  regen_shell
  return 0
}

item name=julia \
  desc="Julia via juliaup, plus Metal.jl for GPU on Apple silicon" \
  check='command -v julia' version='julia --version' method=script \
  home='~/.juliaup:versions ~500MB|~/.julia:packages, grows' \
  shell='path.zsh:$HOME/.juliaup/bin' \
  network='https://install.julialang.org' system='' apps='' receipt='' \
  purge='rm -rf "$HOME/.juliaup" "$HOME/.julia"' \
  manual='curl -fsSL https://install.julialang.org | sh' \
  install=install_julia

install_julia() {
  have juliaup || install_via_script "https://install.julialang.org" -y --path "$HOME/.juliaup" || return 1
  export PATH="$HOME/.juliaup/bin:$PATH"
  run juliaup add release
  run juliaup default release
  run julia -e 'using Pkg; Pkg.add(["Metal","BenchmarkTools","Revise"])'
  shellent_add julia path "$HOME/.juliaup/bin"
  regen_shell
  return 0
}
