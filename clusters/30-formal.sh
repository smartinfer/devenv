#!/usr/bin/env bash
cluster 30-formal

item name=quint \
  desc="Quint — executable specification language (Informal Systems)" \
  check='command -v quint' version='quint --version' method=npm \
  home='~/.local/share/mise/installs/node:global npm prefix' shell='' \
  network='registry.npmjs.org' system='' apps='' receipt='' \
  purge='npm uninstall -g @informalsystems/quint' \
  manual='npm install -g @informalsystems/quint' \
  install=install_quint
install_quint() {
  have npm || { err "node missing — run: dev install mise"; return 1; }
  run npm install -g @informalsystems/quint
}

item name=apalache \
  desc="Apalache — symbolic model checker, the verification backend behind Quint" \
  check='command -v apalache-mc' version='apalache-mc version' method=gh-tree \
  home='~/.local/opt/apalache:~150MB|~/.local/bin:symlinks' shell='' \
  network='github.com/apalache-mc/apalache releases' system='' apps='' receipt='' \
  purge='rm -rf "$HOME/.local/opt/apalache" "$HOME/.local/bin/apalache-mc"' \
  manual='Download apalache.tgz from github.com/apalache-mc/apalache/releases and extract to ~/.local/opt/apalache' \
  install=install_apalache
install_apalache() {
  have java || warn "no JVM found — apalache needs one (mise installs temurin-21)"
  install_gh_tree apalache-mc/apalache '\.tgz$' apalache bin
}

item name=lean \
  desc="Lean 4 via elan — theorem prover and its toolchain manager" \
  check='command -v lean' version='lean --version' method=script \
  home='~/.elan:toolchains ~2GB' \
  shell='path.zsh:$HOME/.elan/bin' \
  network='raw.githubusercontent.com/leanprover/elan' system='' apps='' receipt='' \
  purge='elan self uninstall -y 2>/dev/null || rm -rf "$HOME/.elan"' \
  manual='curl -fsSL https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y' \
  install=install_lean
install_lean() {
  have elan || install_via_script \
    "https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh" \
    -y --no-modify-path || return 1
  export PATH="$HOME/.elan/bin:$PATH"
  run elan default stable
  shellent_add lean path "$HOME/.elan/bin"
  regen_shell
  return 0
}

item name=z3 \
  desc="Z3 SMT solver" \
  check='command -v z3' version='z3 --version' method=gh-binary \
  home='~/.local/bin/z3:~30MB' shell='' \
  network='github.com/Z3Prover/z3 releases' system='' apps='' receipt='' \
  purge='rm -f "$HOME/.local/bin/z3"' \
  manual='Download the arm64-osx zip from github.com/Z3Prover/z3/releases and copy bin/z3 into ~/.local/bin' \
  install=install_z3
install_z3() { install_gh_bin Z3Prover/z3 'arm64-osx' z3; }

item name=alloy \
  desc="Alloy 6 — relational model finder (jar; needs the JVM)" \
  check='[ -f "$HOME/.local/opt/jars/alloy.jar" ]' version='' method=manual \
  home='~/.local/opt/jars/alloy.jar:~40MB' \
  shell='interactive.zsh:alias alloy' \
  network='github.com/AlloyTools/org.alloytools.alloy releases' system='' apps='' receipt='' \
  purge='rm -f "$HOME/.local/opt/jars/alloy.jar"' \
  manual='Download the jar from https://alloytools.org/download.html into ~/.local/opt/jars/alloy.jar' \
  install=install_alloy
install_alloy() {
  mkdir -p "$LOCAL_OPT/jars"
  local url; url=$(gh_asset_url AlloyTools/org.alloytools.alloy '\.jar$')
  [ -n "$url" ] || { err "no alloy jar in latest release — see alloytools.org"; return 1; }
  inf "$url"
  run curl -fsSL "$url" -o "$LOCAL_OPT/jars/alloy.jar" || return 1
  shellent_add alloy hook "alias alloy='java -jar $LOCAL_OPT/jars/alloy.jar'"
  regen_shell
  return 0
}

item name=tlaplus \
  desc="TLA+ tools (tla2tools.jar) — TLC model checker" \
  check='[ -f "$HOME/.local/opt/jars/tla2tools.jar" ]' version='' method=manual \
  home='~/.local/opt/jars/tla2tools.jar:~10MB' \
  shell='interactive.zsh:alias tlc' \
  network='github.com/tlaplus/tlaplus releases' system='' apps='' receipt='' \
  purge='rm -f "$HOME/.local/opt/jars/tla2tools.jar"' \
  manual='curl -fsSL -o ~/.local/opt/jars/tla2tools.jar https://github.com/tlaplus/tlaplus/releases/latest/download/tla2tools.jar' \
  install=install_tlaplus
install_tlaplus() {
  mkdir -p "$LOCAL_OPT/jars"
  run curl -fsSL -o "$LOCAL_OPT/jars/tla2tools.jar" \
    https://github.com/tlaplus/tlaplus/releases/latest/download/tla2tools.jar || return 1
  shellent_add tlaplus hook "alias tlc='java -cp $LOCAL_OPT/jars/tla2tools.jar tlc2.TLC'"
  regen_shell
  return 0
}
