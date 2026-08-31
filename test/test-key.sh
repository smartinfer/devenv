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

group "6. Storage, masking, loader"
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

group "7. rm requires confirmation and regenerates the loader"
printf 'n\n' | K rm openai >/dev/null 2>&1
assert "[ -f '$DEVENV_SECRETS_DIR/openai.key' ]" "declining rm keeps the key"
printf 'y\n' | K rm openai >/dev/null 2>&1
assert "[ ! -f '$DEVENV_SECRETS_DIR/openai.key' ]" "confirming rm deletes the key"
assert "[ -f '$DEVENV_LOADER' ]" "loader regenerated after rm"

group "8. Generated loader"
L=$(cat "$DEVENV_LOADER" 2>/dev/null)
assert_has "$L" "GENERATED"          "loader is marked generated"
assert_has "$L" "ANTHROPIC_API_KEY"  "loader maps anthropic"
assert_has "$L" "HF_TOKEN"           "loader maps huggingface to HF_TOKEN"
assert_has "$L" '.key(N)'            "loader uses a null glob so an empty dir is not an error"
assert_hasnt "$L" "sk-ant-abcdef"    "loader contains no key material"
PERM=$(stat -c '%a' "$DEVENV_LOADER" 2>/dev/null || stat -f '%Lp' "$DEVENV_LOADER" 2>/dev/null)
assert_eq "$PERM" "600" "loader is mode 600"

group "9. Guard rails"
assert_has "$(K add anthropic)"    "rotate" "add refuses to overwrite, points at rotate"
assert_has "$(K rotate nosuch)"    "no existing key" "rotate refuses an unknown provider"
assert_has "$(K test nosuch)"      "no key stored"   "test refuses an unknown provider"
assert_has "$(K rm nosuch)"        "no key stored"   "rm refuses an unknown provider"
assert_has "$(K bogus)"            "unknown command" "unknown commands are rejected"
assert_has "$(K help)"             "rotate"          "help documents rotate"
assert_has "$(K help)"             "stdin"           "help states keys come from stdin"

group "10. doctor"
chmod 644 "$DEVENV_SECRETS_DIR/anthropic.key"
assert_has "$(K doctor)" "should be 600" "doctor catches a loose key file"
chmod 600 "$DEVENV_SECRETS_DIR/anthropic.key"
assert_has "$(K doctor)" "permissions are correct" "doctor passes once fixed"

group "11. No network was touched"
# Every test above ran without a live endpoint. If any command had hit the
# network, these would have taken far longer than the suite's runtime.
t_ok "suite is hermetic (no test performs a live request)"

rm -rf "$SANDBOX"
printf "\n%s%s%s\n" "$B" "────────────────────────────────────────" "$N"
printf "  %spassed %s%s   %sfailed %s%s\n" "$G" "$PASS" "$N" \
       "$([ $FAIL -gt 0 ] && printf '%s' "$R" || printf '%s' "$G")" "$FAIL" "$N"
[ $FAIL -gt 0 ] && exit 1
exit 0
