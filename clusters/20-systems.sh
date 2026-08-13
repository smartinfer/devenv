#!/usr/bin/env bash
cluster 20-systems

item name=rust \
  desc="Rust via rustup — rustc, cargo, clippy, rustfmt, rust-analyzer" \
  check='command -v rustc' version='rustc --version' method=script \
  home='~/.rustup:toolchains ~380MB|~/.cargo:cargo home and bin ~70MB' \
  shell='path.zsh:$HOME/.cargo/bin' \
  network='https://sh.rustup.rs' system='' apps='' receipt='' \
  purge='rustup self uninstall -y 2>/dev/null || rm -rf "$HOME/.rustup" "$HOME/.cargo"' \
  manual='curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y' \
  install=install_rust

install_rust() {
  have rustup || install_via_script "https://sh.rustup.rs" -y --no-modify-path || return 1
  . "$HOME/.cargo/env" 2>/dev/null
  run rustup default stable
  run rustup component add clippy rustfmt rust-analyzer rust-src
  shellent_add rust path "$HOME/.cargo/bin"
  regen_shell
  return 0
}

item name=ninja \
  desc="Ninja build system" \
  check='command -v ninja' version='ninja --version' method=gh-binary \
  home='~/.local/bin/ninja:~200KB' shell='' \
  network='github.com/ninja-build/ninja releases' system='' apps='' receipt='' \
  purge='rm -f "$HOME/.local/bin/ninja"' \
  manual='Download ninja-mac.zip from github.com/ninja-build/ninja/releases, unzip into ~/.local/bin' \
  install=install_ninja
install_ninja() { install_gh_bin ninja-build/ninja 'mac' ninja; }

item name=cmake \
  desc="CMake — cmake, ctest, cpack" \
  check='command -v cmake' version='cmake --version' method=tarball \
  home='~/.local/opt/cmake:~120MB|~/.local/bin:3 symlinks' shell='' \
  network='github.com/Kitware/CMake releases' system='' apps='' receipt='' \
  purge='rm -rf "$HOME/.local/opt/cmake" "$HOME/.local/bin/cmake" "$HOME/.local/bin/ctest" "$HOME/.local/bin/cpack"' \
  manual='Download the macOS tarball from cmake.org/download and extract into ~/.local/opt/cmake' \
  install=install_cmake

install_cmake() {
  ensure_dirs
  local url tmp app b
  url=$(gh_asset_url Kitware/CMake 'macos.*\.tar\.gz')
  [ -n "$url" ] || { err "no CMake macOS tarball in latest release"; return 1; }
  inf "$url"
  tmp=$(mktemp -d); run curl -fsSL "$url" -o "$tmp/c.tgz" || { rm -rf "$tmp"; return 1; }
  tar -xzf "$tmp/c.tgz" -C "$tmp" >>"$LOGFILE" 2>&1
  app=$(find "$tmp" -maxdepth 2 -name 'CMake.app' 2>/dev/null | head -1)
  [ -n "$app" ] || { err "CMake.app not found inside tarball"; rm -rf "$tmp"; return 1; }
  rm -rf "$LOCAL_OPT/cmake"; mkdir -p "$LOCAL_OPT/cmake"; cp -R "$app" "$LOCAL_OPT/cmake/"
  for b in cmake ctest cpack; do ln -sf "$LOCAL_OPT/cmake/CMake.app/Contents/bin/$b" "$LOCAL_BIN/$b"; done
  rm -rf "$tmp"; return 0
}
