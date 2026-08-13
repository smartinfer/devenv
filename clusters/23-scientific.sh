#!/usr/bin/env bash
cluster 23-scientific

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
