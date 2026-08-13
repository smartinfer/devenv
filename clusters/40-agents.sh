#!/usr/bin/env bash
cluster 40-agents

item name=claude-code \
  desc="Claude Code — native arm64 binary, no Node runtime, background auto-update" \
  check='command -v claude' version='claude --version' method=script \
  home='~/.local/bin/claude:launcher|~/.local/share/claude:versions|~/.claude:config and sessions' shell='' \
  network='https://claude.ai/install.sh' system='' apps='' receipt='' \
  purge='rm -rf "$HOME/.local/share/claude" "$HOME/.local/bin/claude" "$HOME/.claude"' \
  manual='curl -fsSL https://claude.ai/install.sh | bash' \
  alt='npm install -g @anthropic-ai/claude-code (legacy; the npm copy shadows the native binary on PATH)' \
  install=install_claude_code
install_claude_code() {
  have claude || install_via_script "https://claude.ai/install.sh" || return 1
  if npm ls -g --depth=0 @anthropic-ai/claude-code >/dev/null 2>&1; then
    warn "an npm copy of claude-code exists and will shadow the native binary"
    warn "fix: npm uninstall -g @anthropic-ai/claude-code && hash -r && claude doctor"
  fi
  return 0
}

item name=codex \
  desc="OpenAI Codex CLI — Rust binary via the standalone installer, no Node" \
  check='command -v codex' version='codex --version' method=script \
  home='~/.local/bin/codex:binary|~/.codex:config.toml and auth' shell='' \
  network='https://chatgpt.com/codex/install.sh' system='' apps='' receipt='' \
  purge='rm -rf "$HOME/.local/bin/codex" "$HOME/.codex"' \
  manual='curl -fsSL https://chatgpt.com/codex/install.sh | sh' \
  alt='npm install -g @openai/codex — note the scope; the bare "codex" package is unrelated' \
  install=install_codex
install_codex() {
  have codex && return 0
  install_via_script "https://chatgpt.com/codex/install.sh" && return 0
  warn "standalone installer failed; falling back to the GitHub release binary"
  install_gh_bin openai/codex 'aarch64-apple-darwin' codex
}

item name=gemini-cli \
  desc="Gemini CLI — the only agent here that needs Node at runtime" \
  check='command -v gemini' version='gemini --version' method=npm \
  home='global npm prefix:node_modules/@google|~/.gemini:config' shell='' \
  network='registry.npmjs.org' system='' apps='' receipt='' \
  purge='npm uninstall -g @google/gemini-cli; rm -rf "$HOME/.gemini"' \
  manual='npm install -g @google/gemini-cli' \
  alt='npx @google/gemini-cli for one-off use — nothing installed, but it re-resolves from the registry every run' \
  install=install_gemini
install_gemini() {
  have npm || { err "node missing — run: dev install mise"; return 1; }
  warn "Google retired the hosted CLI for free / AI Pro / AI Ultra accounts on 18 Jun 2026"
  warn "(moved to Antigravity CLI). A paid API key or Vertex AI credentials still work."
  run npm install -g @google/gemini-cli
}
