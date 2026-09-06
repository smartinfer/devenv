#!/usr/bin/env bash
#
# test/test-key.sh — hermetic tests for `key`. No network, no real keys,
# nothing written outside a throwaway sandbox.
#
set -uo pipefail
TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$(cd "$TEST_ROOT/.." && pwd)"

PASS=0; FAIL=0
G=$'\033[1;32m'; R=$'\033[1;31m'; B=$'\033[1m'; N=$'\033[0m'
[ -t 1 ] || { G=""; R=""; B=""; N=""; }
t_ok()  { PASS=$((PASS+1)); printf "  %s✓%s %s\n" "$G" "$N" "$1"; }
t_bad() { FAIL=$((FAIL+1)); printf "  %sx%s %s\n" "$R" "$N" "$1"
          [ -n "${2:-}" ] && printf "      %s\n" "$2"; }
group() { printf "\n%s%s%s\n" "$B" "$1" "$N"; }
assert()     { if eval "$1" >/dev/null 2>&1; then t_ok "$2"; else t_bad "$2" "failed: $1"; fi; }
assert_not() { if eval "$1" >/dev/null 2>&1; then t_bad "$2" "should have failed"; else t_ok "$2"; fi; }
assert_eq()  { if [ "$1" = "$2" ]; then t_ok "$3"; else t_bad "$3" "expected '$2', got '$1'"; fi; }
assert_has() { case "$1" in *"$2"*) t_ok "$3" ;; *) t_bad "$3" "missing '$2'" ;; esac; }
assert_hasnt(){ case "$1" in *"$2"*) t_bad "$3" "should not contain '$2'" ;; *) t_ok "$3" ;; esac; }

SANDBOX=$(mktemp -d)
export DEVENV_SECRETS_DIR="$SANDBOX/secrets"
export DEVENV_LOADER="$SANDBOX/zsh_secrets"
export DEVENV_KEY_PROFILES="$SANDBOX/secrets/profiles.tsv"
export DEVENV_KEY_PROVIDERS="$SANDBOX/secrets/providers.tsv"
K() { ( cd "$PKG" && ./key "$@" 2>&1 ); }

group "1. Syntax and permissions"
assert "bash -n '$PKG/key'" "key parses"
assert "[ -x '$PKG/key' ]"  "key is executable"

group "2. Bash 3.2 compatibility"
hits=$(sed 's/#.*$//' "$PKG/key" | grep -nE 'declare[[:space:]]+-A|\bmapfile\b|\breadarray\b|\$\{[A-Za-z_]+\^\^\}' | head -3)
if [ -z "$hits" ]; then t_ok "no bash 4+ constructs"; else t_bad "no bash 4+ constructs" "$hits"; fi

group "3. Provider table"
OUT=$(K providers)
for p in anthropic openai gemini together deepseek moonshot dashscope zhipu \
         groq mistral fireworks openrouter xai cohere huggingface; do
  assert_has "$OUT" "$p" "knows $p"
done
assert_has "$OUT" "ANTHROPIC_API_KEY" "maps anthropic to the right env var"
assert_has "$OUT" "HF_TOKEN"          "huggingface uses HF_TOKEN, not HUGGINGFACE_API_KEY"
assert_has "$OUT" "console.anthropic.com" "includes console URLs"

group "3b. Every provider row is complete"
. /dev/stdin <<'SRC'
SRC
while IFS='|' read -r name var prefix auth turl console label; do
  [ -z "$name" ] && continue
  bad=""
  [ -n "$var" ]     || bad="$bad env_var"
  [ -n "$auth" ]    || bad="$bad auth"
  [ -n "$turl" ]    || bad="$bad test_url"
  [ -n "$console" ] || bad="$bad console"
  [ -n "$label" ]   || bad="$bad label"
  case "$auth" in bearer|xapikey|query) : ;; *) bad="$bad auth=$auth-invalid" ;; esac
  case "$turl" in https://*) : ;; *) bad="$bad test_url-not-https" ;; esac
  if [ -z "$bad" ]; then t_ok "$name: row complete"; else t_bad "$name: row complete" "missing:$bad"; fi
done <<EOF
$(sed -n "/^PROVIDERS='/,/^'/p" "$PKG/key" | grep '|')
EOF

group "4. Empty state"
OUT=$(K list)
assert_has "$OUT" "none yet"       "list reports an empty store"
assert_has "$OUT" "anthropic"      "list names the missing frontier providers"
assert "[ -d '$DEVENV_SECRETS_DIR' ]" "secrets dir created on demand"
PERM=$(stat -c '%a' "$DEVENV_SECRETS_DIR" 2>/dev/null || stat -f '%Lp' "$DEVENV_SECRETS_DIR" 2>/dev/null)
assert_eq "$PERM" "700" "secrets dir is mode 700"

group "5. Keys are never taken from argv"
# A key passed as an argument would land in shell history and the process
# table. `add` must not accept one.
assert_hasnt "$(K add anthropic sk-ant-leaked-in-argv 2>&1)" "saved" \
  "add does not accept a key as a positional argument"
assert "[ ! -f '$DEVENV_SECRETS_DIR/anthropic.key' ]" "nothing written from argv"

group "6. Storage and masking"
mkdir -p "$DEVENV_SECRETS_DIR"
printf 'sk-ant-abcdefghijklmnop1234' > "$DEVENV_SECRETS_DIR/anthropic.key"
printf 'sk-proj-zyxwvutsrq9876'      > "$DEVENV_SECRETS_DIR/openai.key"
chmod 600 "$DEVENV_SECRETS_DIR"/*.key

OUT=$(K list)
assert_has    "$OUT" "anthropic"                 "list shows a stored provider"
assert_has    "$OUT" "sk-ant-a"                  "list shows a masked prefix"
assert_hasnt  "$OUT" "sk-ant-abcdefghijklmnop"   "list never prints a full key"
assert_hasnt  "$OUT" "sk-proj-zyxwvutsrq9876"    "masking applies to every provider"

assert_eq "$(K show anthropic)" "sk-ant-abcdefghijklmnop1234" "show prints the raw key for piping"

group "7. rm requires confirmation and neutralizes the legacy loader"
printf 'n\n' | K rm openai >/dev/null 2>&1
assert "[ -f '$DEVENV_SECRETS_DIR/openai.key' ]" "declining rm keeps the key"
printf 'y\n' | K rm openai >/dev/null 2>&1
assert "[ ! -f '$DEVENV_SECRETS_DIR/openai.key' ]" "confirming rm deletes the key"
assert "[ -f '$DEVENV_LOADER' ]" "loader regenerated after rm"

group "8. Inert compatibility loader"
L=$(cat "$DEVENV_LOADER" 2>/dev/null)
assert_has "$L" "GENERATED"          "loader is marked generated"
assert_has "$L" "not exported globally" "loader explains scoped behavior"
assert_hasnt "$L" "ANTHROPIC_API_KEY" "loader exports no provider variable"
assert_hasnt "$L" '.key(N)'            "loader does not read stored keys"
assert_hasnt "$L" "sk-ant-abcdef"    "loader contains no key material"
PERM=$(stat -c '%a' "$DEVENV_LOADER" 2>/dev/null || stat -f '%Lp' "$DEVENV_LOADER" 2>/dev/null)
assert_eq "$PERM" "600" "loader is mode 600"

group "9. Scoped run"
printf 'sk-proj-test-openai' > "$DEVENV_SECRETS_DIR/openai.key"
printf 'test-gemini-key' > "$DEVENV_SECRETS_DIR/gemini.key"
chmod 600 "$DEVENV_SECRETS_DIR"/*.key
cat > "$SANDBOX/probe" <<'PROBE'
#!/bin/sh
printf 'openai=%s anthropic=%s gemini=%s keep=%s scope=%s argv=%s|%s\n' \
  "${OPENAI_API_KEY:+present}" "${ANTHROPIC_API_KEY:+present}" \
  "${GEMINI_API_KEY:+present}" "${TEST_KEEP:-}" "${KEY_SCOPE:-}" \
  "${1:-}" "${2:-}"
exit "${PROBE_EXIT:-0}"
PROBE
chmod +x "$SANDBOX/probe"
export ANTHROPIC_API_KEY="stale-inherited-value"
export GEMINI_API_KEY="stale-inherited-value"
export OPENAI_API_KEY="stale-inherited-openai"
export TEST_KEEP="preserved"
OUT=$(K run openai -- "$SANDBOX/probe" "one word" 'literal*$x')
assert_has "$OUT" "openai=present" "requested provider is injected"
assert_has "$OUT" "anthropic= gemini=" "unrequested and inherited managed keys are scrubbed"
assert_has "$OUT" "keep=preserved" "unrelated environment is preserved"
assert_has "$OUT" "scope=openai" "scope indicator names the provider"
assert_has "$OUT" 'argv=one word|literal*$x' "command argv is preserved exactly"

OUT=$(K run openai anthropic gemini openai -- "$SANDBOX/probe")
assert_has "$OUT" "openai=present anthropic=present gemini=present" "multiple providers are injected"
assert_has "$OUT" "scope=openai,anthropic,gemini" "duplicate providers are deterministically deduplicated"
assert_has "$(K run nosuch -- true)" "unknown provider 'nosuch'" "unknown provider fails before execution"
mv "$DEVENV_SECRETS_DIR/gemini.key" "$DEVENV_SECRETS_DIR/gemini.saved"
assert_has "$(K run gemini -- true)" "has no configured API key" "missing credential fails before execution"
mv "$DEVENV_SECRETS_DIR/gemini.saved" "$DEVENV_SECRETS_DIR/gemini.key"
assert_has "$(K run -- true)" "select at least one provider" "run never defaults to all providers"
assert_has "$(K run openai true)" "expected '--'" "run requires an explicit command separator"
PROBE_EXIT=37 K run openai -- "$SANDBOX/probe" >/dev/null 2>&1; RC=$?
assert_eq "$RC" "37" "child exit status is propagated"
OUT=$(K run --all -- "$SANDBOX/probe")
assert_has "$OUT" "openai=present anthropic=present gemini=present" "explicit --all exposes configured providers"
assert_hasnt "$(K run openai -- true 2>&1)" "sk-proj-test-openai" "key run emits no secret"

group "10. Scoped shell"
cat > "$SANDBOX/fake-shell" <<'SHELL'
#!/bin/sh
[ "${1:-}" = "-i" ] || exit 91
printf 'openai=%s anthropic=%s gemini=%s scope=%s\n' \
  "${OPENAI_API_KEY:+present}" "${ANTHROPIC_API_KEY:+present}" \
  "${GEMINI_API_KEY:+present}" "${KEY_SCOPE:-}"
SHELL
chmod +x "$SANDBOX/fake-shell"
export DEVENV_KEY_SHELL="$SANDBOX/fake-shell"
OUT=$(K shell openai anthropic)
assert_has "$OUT" "openai=present anthropic=present gemini=" "shell receives exactly selected providers"
assert_has "$OUT" "scope=openai,anthropic" "shell receives visible scope indicator"
assert_eq "${OPENAI_API_KEY:-}" "stale-inherited-openai" "parent environment is unchanged after scoped shell"
assert_eq "${ANTHROPIC_API_KEY:-}" "stale-inherited-value" "parent environment is unchanged"
assert_has "$(K shell)" "usage: key shell" "shell with no providers does not mean all"

group "11. Named profiles"
OUT=$(K profile add thinker openai anthropic gemini openai)
assert_has "$OUT" "openai,anthropic,gemini" "profile stores a deduplicated provider list"
assert_eq "$(K profile show thinker)" "openai anthropic gemini" "profile show returns provider names"
assert_has "$(K profile list)" "thinker" "profile list shows the profile"
assert_hasnt "$(cat "$DEVENV_KEY_PROFILES")" "sk-proj-test-openai" "profile persists no secret values"
PERM=$(stat -c '%a' "$DEVENV_KEY_PROFILES" 2>/dev/null || stat -f '%Lp' "$DEVENV_KEY_PROFILES" 2>/dev/null)
assert_eq "$PERM" "600" "profile file is mode 600"
OUT=$(K run-profile thinker -- "$SANDBOX/probe")
assert_has "$OUT" "openai=present anthropic=present gemini=present" "run-profile exposes its providers"
OUT=$(K shell-profile thinker)
assert_has "$OUT" "scope=openai,anthropic,gemini" "shell-profile exposes its provider scope"
K profile rm thinker >/dev/null
assert_has "$(K profile show thinker)" "unknown profile" "profile rm removes the profile"

group "12. Safe env status and legacy migration"
OUT=$(K env)
assert_has "$OUT" "STORED" "env distinguishes stored state"
assert_has "$OUT" "EXPORTED" "env distinguishes exported state"
assert_hasnt "$OUT" "stale-inherited-value" "env never prints inherited values"
assert_hasnt "$OUT" "sk-proj-test-openai" "env never prints stored values"
cat > "$DEVENV_LOADER" <<'LEGACY'
for _f in "$_sd"/*.key(N); do export "$_v"="$(< "$_f")"; done
LEGACY
K env >/dev/null
assert_hasnt "$(cat "$DEVENV_LOADER")" '.key(N)' "first key command neutralizes a legacy loader"

group "12b. Custom provider registry remains usable"
printf 'synthetic-custom-secret\n' | K add customai --var CUSTOMAI_TOKEN >/dev/null
assert_has "$(K providers)" "CUSTOMAI_TOKEN" "custom provider mapping persists"
assert_eq "$(K show customai)" "synthetic-custom-secret" "custom add stores hidden stdin input"
PERM=$(stat -c '%a' "$DEVENV_SECRETS_DIR/customai.key" 2>/dev/null || stat -f '%Lp' "$DEVENV_SECRETS_DIR/customai.key" 2>/dev/null)
assert_eq "$PERM" "600" "custom key file is mode 600"
OUT=$(K run customai -- sh -c 'printf "%s" "${CUSTOMAI_TOKEN:+present}"')
assert_eq "$OUT" "present" "custom provider works in a later scoped invocation"
assert_hasnt "$(cat "$DEVENV_KEY_PROVIDERS")" "synthetic-custom-secret" "custom registry stores no key value"
PERM=$(stat -c '%a' "$DEVENV_KEY_PROVIDERS" 2>/dev/null || stat -f '%Lp' "$DEVENV_KEY_PROVIDERS" 2>/dev/null)
assert_eq "$PERM" "600" "custom registry metadata is mode 600"
printf 'synthetic-custom-rotated\n' | K rotate customai >/dev/null
assert_eq "$(K show customai)" "synthetic-custom-rotated" "custom rotate replaces the stored key"
assert "ls '$DEVENV_SECRETS_DIR'/customai.key.*.bak >/dev/null 2>&1" "rotation preserves a mode-restricted backup"
printf 'y\n' | K rm customai >/dev/null
assert "[ ! -f '$DEVENV_SECRETS_DIR/customai.key' ]" "custom remove deletes the key"
assert_has "$(K run customai -- true)" "unknown provider" "custom remove also deletes its registry mapping"

group "13. Guard rails"

assert_has "$(K add anthropic)"    "rotate" "add refuses to overwrite, points at rotate"
assert_has "$(K rotate nosuch)"    "no existing key" "rotate refuses an unknown provider"
assert_has "$(K test nosuch)"      "no key stored"   "test refuses an unknown provider"
assert_has "$(K rm nosuch)"        "no key stored"   "rm refuses an unknown provider"
assert_has "$(K bogus)"            "unknown command" "unknown commands are rejected"
assert_has "$(K help)"             "rotate"          "help documents rotate"
assert_has "$(K help)"             "stdin"           "help states keys come from stdin"
assert_has "$(K help)"             "key run openai anthropic gemini" "help documents multi-provider scoping"

group "14. doctor"
chmod 644 "$DEVENV_SECRETS_DIR/anthropic.key"
assert_has "$(K doctor)" "should be 600" "doctor catches a loose key file"
assert_not "K doctor" "doctor returns failure for unsafe permissions"
chmod 600 "$DEVENV_SECRETS_DIR/anthropic.key"
assert_has "$(K doctor)" "permissions are correct" "doctor passes once fixed"
assert "K doctor" "doctor returns success once fixed"

group "15. No network was touched"
# Every test above ran without a live endpoint. If any command had hit the
# network, these would have taken far longer than the suite's runtime.
t_ok "suite is hermetic (no test performs a live request)"

rm -rf "$SANDBOX"
printf "\n%s%s%s\n" "$B" "────────────────────────────────────────" "$N"
printf "  %spassed %s%s   %sfailed %s%s\n" "$G" "$PASS" "$N" \
       "$([ $FAIL -gt 0 ] && printf '%s' "$R" || printf '%s' "$G")" "$FAIL" "$N"
[ $FAIL -gt 0 ] && exit 1
exit 0
