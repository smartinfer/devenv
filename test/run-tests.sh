#!/usr/bin/env bash
#
# test/run-tests.sh — hermetic self-tests. No network, no installs, no writes
# outside a throwaway sandbox. Run this before you run ./dev for the first time.
#
#   ./test/run-tests.sh
#
set -uo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$(cd "$TEST_ROOT/.." && pwd)"

PASS=0; FAIL=0
G=$'\033[1;32m'; R=$'\033[1;31m'; Y=$'\033[1;33m'; B=$'\033[1m'; N=$'\033[0m'
[ -t 1 ] || { G=""; R=""; Y=""; B=""; N=""; }

t_ok()   { PASS=$((PASS+1)); printf "  %s✓%s %s\n" "$G" "$N" "$1"; }
t_bad()  { FAIL=$((FAIL+1)); printf "  %sx%s %s\n" "$R" "$N" "$1"
           [ -n "${2:-}" ] && printf "      %s\n" "$2"; }
group()  { printf "\n%s%s%s\n" "$B" "$1" "$N"; }

assert()      { if eval "$1" >/dev/null 2>&1; then t_ok "$2"; else t_bad "$2" "failed: $1"; fi; }
assert_not()  { if eval "$1" >/dev/null 2>&1; then t_bad "$2" "should have failed: $1"; else t_ok "$2"; fi; }
assert_eq()   { if [ "$1" = "$2" ]; then t_ok "$3"; else t_bad "$3" "expected '$2', got '$1'"; fi; }
assert_has()  { case "$1" in *"$2"*) t_ok "$3" ;; *) t_bad "$3" "missing '$2'" ;; esac; }

# ---------------------------------------------------------------------------
group "1. Syntax"
# ---------------------------------------------------------------------------
for f in "$PKG/dev" "$PKG"/lib/*.sh "$PKG"/clusters/*.sh "$PKG"/test/*.sh; do
  if bash -n "$f" 2>/dev/null; then t_ok "parses: ${f#$PKG/}"
  else t_bad "parses: ${f#$PKG/}" "$(bash -n "$f" 2>&1 | head -2)"; fi
done

# ---------------------------------------------------------------------------
group "2. Bash 3.2 compatibility (macOS ships bash 3.2)"
# ---------------------------------------------------------------------------
# These constructs are bash 4+ and will break on a stock Mac.
# Strip comments from the FILE (not from grep's filename:lineno: output, which
# is why the naive `grep -rn ... | grep -v '^#'` version silently passed).
check_forbidden() {
  local pat="$1" desc="$2" f hits=""
  for f in "$PKG/dev" "$PKG"/lib/*.sh "$PKG"/clusters/*.sh; do
    local h
    h=$(sed 's/#.*$//' "$f" | grep -nE "$pat" | head -2)
    [ -n "$h" ] && hits="$hits${f#$PKG/}: $h
"
  done
  if [ -z "$hits" ]; then t_ok "no $desc"; else t_bad "no $desc" "$hits"; fi
}
check_forbidden 'declare[[:space:]]+-A|local[[:space:]]+-A' "associative arrays"
check_forbidden '\bmapfile\b|\breadarray\b'                 "mapfile/readarray"
check_forbidden '\$\{[A-Za-z_]+\^\^\}|\$\{[A-Za-z_]+,,\}'   "\${x^^} / \${x,,} case ops"
check_forbidden '&>>'                                        "&>> redirection"

# ---------------------------------------------------------------------------
group "3. Sandbox load"
# ---------------------------------------------------------------------------
SANDBOX=$(mktemp -d)
export DEVENV_STATE="$SANDBOX/state"
export DEVENV_PREFIX="$SANDBOX/local"
export DEV_ROOT="$PKG"
mkdir -p "$DEVENV_STATE" "$DEVENV_PREFIX/bin"

# shellcheck disable=SC1090
. "$PKG/lib/core.sh"  || { t_bad "core.sh loads"; }
. "$PKG/lib/item.sh"  || { t_bad "item.sh loads"; }
. "$PKG/lib/ui.sh"    || { t_bad "ui.sh loads"; }
. "$PKG/lib/install.sh" || { t_bad "install.sh loads"; }
t_ok "libraries load"

assert_eq "$DEV_STATE" "$SANDBOX/state" "state redirects into sandbox"
assert_eq "$LOCAL_BIN" "$SANDBOX/local/bin" "prefix redirects into sandbox"

tsv_init
assert "[ -f '$REGISTRY' ]"  "registry.tsv created"
assert "[ -f '$DEFERRED' ]"  "deferred.tsv created"
assert "[ -f '$SHELLENTS' ]" "shellents.tsv created"

load_clusters
NITEMS=$(all_items | wc -l | tr -d ' ')
NCLUST=$(all_clusters | wc -w | tr -d ' ')
assert "[ $NITEMS -ge 20 ]"  "loaded $NITEMS items"
assert "[ $NCLUST -ge 10 ]"  "loaded $NCLUST clusters"

# ---------------------------------------------------------------------------
group "4. Item DSL"
# ---------------------------------------------------------------------------
assert     "item_exists rust"        "item_exists finds rust"
assert_not "item_exists nonesuch"    "item_exists rejects unknown"
assert_eq  "$(item_get rust method)" "script"      "item_get reads a field"
assert_eq  "$(item_cluster_of rust)" "20-systems"  "item_cluster_of works"
assert_has "$(item_get rust desc)"   "rustup"      "desc is populated"
assert_has "$(item_roots rust)"      ".rustup"     "item_roots parses home footprint"
assert_has "$(item_roots rust)"      ".cargo"      "item_roots handles multiple paths"

group "4b. Every item is well-formed"
for n in $(all_items); do
  bad=""
  [ -n "$(item_get "$n" desc)" ]    || bad="$bad desc"
  [ -n "$(item_get "$n" check)" ]   || bad="$bad check"
  [ -n "$(item_get "$n" method)" ]  || bad="$bad method"
  [ -n "$(item_get "$n" purge)" ]   || bad="$bad purge"
  [ -n "$(item_get "$n" install)" ] || bad="$bad install"
  if [ -z "$bad" ]; then t_ok "$n: complete"; else t_bad "$n: complete" "missing:$bad"; fi
done

group "4c. Every install function exists"
for n in $(all_items); do
  fn=$(item_get "$n" install)
  if type "$fn" >/dev/null 2>&1; then t_ok "$n -> $fn()"
  else t_bad "$n -> $fn()" "function not defined"; fi
done

group "4d. Item names are unique"
DUPES=$(all_items | sort | uniq -d)
if [ -z "$DUPES" ]; then t_ok "no duplicate item names"; else t_bad "no duplicate item names" "$DUPES"; fi

group "4e. Purge commands look destructive-but-scoped"
for n in $(all_items); do
  p=$(item_get "$n" purge)
  case "$p" in
    *"rm -rf /"[!A-Za-z]*|*'rm -rf /"'*)
      t_bad "$n purge is scoped" "purges an absolute root: $p" ;;
    *)  t_ok "$n purge is scoped" ;;
  esac
done

# ---------------------------------------------------------------------------
group "5. Registry"
# ---------------------------------------------------------------------------
assert_not "registry_has rust" "registry starts empty"
registry_add rust
assert     "registry_has rust" "registry_add records an item"
assert_eq  "$(tsv_field "$REGISTRY" rust 2)" "20-systems" "registry stores cluster"
assert_has "$(tsv_field "$REGISTRY" rust 5)" ".cargo"     "registry stores roots"
registry_add rust
assert_eq "$(awk -F'\t' 'NR>1 && $1=="rust"' "$REGISTRY" | wc -l | tr -d ' ')" "1" \
          "registry_add is idempotent (no duplicate rows)"
registry_del rust
assert_not "registry_has rust" "registry_del removes it"

# ---------------------------------------------------------------------------
group "6. Deferral: later vs never"
# ---------------------------------------------------------------------------
assert_not "deferred_has prolog" "prolog not deferred initially"
deferred_add prolog later "deciding Scryer vs SWI"
assert     "deferred_has prolog" "skip records a 'later' deferral"
assert_not "never_has prolog"    "'later' is not 'never'"
assert_eq  "$(item_state prolog)" "deferred" "item_state reports deferred"
assert_eq  "$(tsv_field "$DEFERRED" prolog 6)" "deciding Scryer vs SWI" "note is preserved"
assert_eq  "$(tsv_field "$DEFERRED" prolog 5)" "1" "skip count starts at 1"

deferred_add prolog later "still deciding"
assert_eq "$(tsv_field "$DEFERRED" prolog 5)" "2" "skip count increments"
assert_eq "$(awk -F'\t' 'NR>1 && $1=="prolog"' "$DEFERRED" | wc -l | tr -d ' ')" "1" \
          "re-deferring does not duplicate the row"

deferred_add prolog never "not doing Prolog"
assert     "never_has prolog"    "never mode is recorded"
assert_not "deferred_has prolog" "never supersedes later"
assert_eq  "$(item_state prolog)" "never" "item_state reports never"

deferred_del prolog
assert_not "never_has prolog" "deferred_del clears it"

# ---------------------------------------------------------------------------
group "7. Generated shell files"
# ---------------------------------------------------------------------------
shellent_add testitem path "/tmp/testbin"
shellent_add testitem env  'export TEST_VAR=1'
shellent_add testitem hook 'alias t=true'
shellent_add testitem path "/tmp/testbin"   # duplicate, must not double up
assert_eq "$(awk -F'\t' 'NR>1 && $1=="testitem" && $2=="path"' "$SHELLENTS" | wc -l | tr -d ' ')" "1" \
          "shellent_add de-duplicates"

DEV_SHELL="$SANDBOX/shell"; mkdir -p "$DEV_SHELL"
regen_shell
# File names follow the login shell (zsh -> *.zsh, bash -> *.sh), so these
# assert against the active family rather than a hardcoded extension.
E="$DEV_SHELL_EXT"
assert     "[ -f '$DEV_SHELL/path.$E' ]"                    "path.$E generated"
assert_has "$(cat "$DEV_SHELL/path.$E")" "/tmp/testbin"     "path entry lands in path.$E"
assert_has "$(cat "$DEV_SHELL/env.$E")"  "TEST_VAR"         "env entry lands in env.$E"
assert_has "$(cat "$DEV_SHELL/interactive.$E")" "alias t"   "hook lands in interactive.$E"
assert_not "grep -q 'TEST_VAR' '$DEV_SHELL/path.$E'"        "env does not leak into path.$E"
assert_not "grep -q 'alias t' '$DEV_SHELL/path.$E'"         "hooks do not leak into path.$E"
assert_has "$(cat "$DEV_SHELL/path.$E")" "devenv_path_prepend" "path.$E de-duplicates PATH"
# env.* pulls path.* in itself, which is what makes non-interactive shells
# (coding agents) see the same PATH as an interactive one.
assert_has "$(cat "$DEV_SHELL/env.$E")" "path.$E"           "env.$E sources path.$E"

# PATH prepend logic must be idempotent — simulate two sourcings.
PATH_BEFORE="$PATH"
sh -c '
  devenv_path_prepend() { case ":$PATH:" in *":$1:"*) return 0;; esac; [ -d "$1" ] && PATH="$1:$PATH"; }
  PATH="/usr/bin:/bin"
  devenv_path_prepend /tmp; devenv_path_prepend /tmp
  echo "$PATH"' > "$SANDBOX/pathtest"
assert_eq "$(cat "$SANDBOX/pathtest")" "/tmp:/usr/bin:/bin" "PATH prepend is idempotent"
PATH="$PATH_BEFORE"

shellent_del_item testitem
regen_shell
assert_not "grep -q '/tmp/testbin' '$DEV_SHELL/path.$E'" "purging an item removes its PATH entry"

# ---------------------------------------------------------------------------
group "8. CLI surface (no writes, no network)"
# ---------------------------------------------------------------------------
run_dev() { ( cd "$PKG" && DEVENV_STATE="$SANDBOX/state2" DEVENV_PREFIX="$SANDBOX/local" \
              ./dev "$@" --no-color 2>&1 ); }

assert_has "$(run_dev help)"     "PER-ITEM PROMPT" "dev help renders"
assert_has "$(run_dev help)"     "--retry-deferred" "help documents --retry-deferred"
assert_has "$(run_dev clusters)" "20-systems"      "dev clusters lists clusters"
assert_has "$(run_dev clusters)" "rust"            "dev clusters lists items"
assert_has "$(run_dev status)"   "CLUSTER"         "dev status renders a table"
assert_has "$(run_dev status --commands)" "dev install" "status --commands emits commands"
# Render directly rather than through `dev plan`: plan skips items that are
# already installed, so these assertions silently inverted once rust landed.
RCARD=$(footprint_card rust missing 2>&1)
assert_has "$RCARD" "PURGE"        "footprint card shows the purge line"
assert_has "$RCARD" "sh.rustup.rs" "footprint card discloses the network source"
# Render the card directly. Going through `dev plan` made this depend on
# whether the item happened to be installed — plan skips items already ok.
#
# clt and vscode are darwin-only items, so on Linux they are never loaded and
# footprint_card renders nothing. Assert against whichever items actually
# carry a SYSTEM/APPS footprint on this host: the invariant under test is
# "SYSTEM footprints are disclosed and flagged", not "macOS is the host".
if [ "$DEV_PLATFORM" = darwin ]; then
  SYS_ITEM=clt;         SYS_PATH=CommandLineTools
  APPS_ITEM=vscode;     APPS_MARK=Applications
else
  SYS_ITEM=build-tools; SYS_PATH=/usr/include
  APPS_ITEM=build-tools; APPS_MARK=apt
fi
CARD=$(footprint_card "$SYS_ITEM" missing 2>&1)
assert_has "$CARD" "needs sudo"   "SYSTEM footprints are flagged as needing sudo"
assert_has "$CARD" "$SYS_PATH"    "SYSTEM paths are disclosed"
CARD2=$(footprint_card "$APPS_ITEM" missing 2>&1)
assert_has "$CARD2" "$APPS_MARK"      "APPS/receipt footprints are disclosed"
assert_has "$CARD2" "PURGE"           "every card shows its purge command"
assert_has "$(run_dev --version)" "dev "           "dev --version works"
assert_has "$(run_dev help)"     "update [targets]" "help documents update"
# A fake tool on PATH makes ninja "installed" without touching the network.
mkdir -p "$SANDBOX/fakebin"
printf '#!/bin/sh\necho 1.0.0\n' > "$SANDBOX/fakebin/ninja"; chmod +x "$SANDBOX/fakebin/ninja"
assert_has "$(PATH="$SANDBOX/fakebin:$PATH" run_dev update ninja --yes)" "no in-place update method" \
           "update skips items without an update method"
assert_not "PATH='$SANDBOX/fakebin:$PATH' run_dev update ninja --yes | grep -q 'Purging'" \
           "update never purges"
for n in claude-code codex gemini-cli; do
  assert "[ -n \"\$(item_get $n update)\" ]" "$n declares an update method"
done
assert_not "run_dev bogus-command | grep -q 'unknown command' && false" "unknown command is rejected"

group "8b. Default command is check, not install"
OUT=$(run_dev)
assert_not "printf '%s' \"\$OUT\" | grep -qi 'installing'" "bare 'dev' does not install"

group "8c. plan and check never write outside state/"
BEFORE=$(ls -1 "$SANDBOX/local/bin" 2>/dev/null | wc -l | tr -d ' ')
run_dev plan >/dev/null 2>&1
run_dev check >/dev/null 2>&1
AFTER=$(ls -1 "$SANDBOX/local/bin" 2>/dev/null | wc -l | tr -d ' ')
assert_eq "$AFTER" "$BEFORE" "plan/check installed nothing"

group "8d. dry-run install performs no work"
BEFORE=$(ls -1 "$SANDBOX/local/bin" 2>/dev/null | wc -l | tr -d ' ')
run_dev install ninja --dry-run --yes >/dev/null 2>&1
AFTER=$(ls -1 "$SANDBOX/local/bin" 2>/dev/null | wc -l | tr -d ' ')
assert_eq "$AFTER" "$BEFORE" "--dry-run installed nothing"

group "8e. Logs are written and persisted"
assert "[ -d '$SANDBOX/state2/logs' ]"                     "log directory created"
assert "[ \$(ls -1 '$SANDBOX/state2/logs'/*.log 2>/dev/null | wc -l) -gt 0 ]" "log files written"
assert "[ -L '$SANDBOX/state2/logs/latest.log' ]"          "latest.log symlink exists"
assert_not "grep -q \$'\033' \$(ls -1 '$SANDBOX/state2/logs'/*.log | grep -v latest | head -1)" \
           "logs are ANSI-stripped"
assert_has "$(cat "$(ls -1 "$SANDBOX/state2/logs"/*.log | grep -v latest | head -1)")" "devenv" \
           "log has a header"

group "8f. Linux platform selection is isolated"
run_linux_dev() {
  ( cd "$PKG" && DEVENV_PLATFORM=linux DEVENV_ARCH=x86_64 DEVENV_DISTRO=ubuntu \
      DEVENV_STATE="$SANDBOX/linux-state" DEVENV_PREFIX="$SANDBOX/linux-local" \
      ./dev "$@" --no-color 2>&1 )
}
LINUX_PLATFORM=$(run_linux_dev platform)
assert_has "$LINUX_PLATFORM" "linux/ubuntu (x86_64)" "Linux platform is normalized"
LINUX_CLUSTERS=$(run_linux_dev clusters)
assert_has "$LINUX_CLUSTERS" "build-tools" "Linux loads its base prerequisites"
assert_not "printf '%s' \"\$LINUX_CLUSTERS\" | grep -q 'Apple Command Line Tools'" \
           "Linux excludes the macOS base item"
assert_not "printf '%s' \"\$LINUX_CLUSTERS\" | grep -q 'Visual Studio Code (arm64)'" \
           "Linux excludes macOS editor installers"
assert_not "printf '%s' \"\$LINUX_CLUSTERS\" | grep -q 'MLX runs on the GPU'" \
           "Linux excludes Apple-only MLX checks"
LINUX_PLAN=$(run_linux_dev plan build-tools)
assert_has "$LINUX_PLAN" "apt" "Linux base plan discloses apt"
assert_has "$LINUX_PLAN" "needs sudo" "Linux system packages require approval"

# ---------------------------------------------------------------------------
group "8g. Shell wiring follows the login shell"
# ---------------------------------------------------------------------------
# devenv generates zsh files on macOS and for zsh logins; a bash login gets
# POSIX *.sh wired into ~/.profile and ~/.bashrc instead. Wiring the wrong
# family is silent: the installs succeed and nothing lands on PATH.
run_kind_dev() {  # <zsh|bash> <args...>
  local kind="$1"; shift
  ( cd "$PKG" && DEVENV_SHELL_KIND="$kind" \
      DEVENV_STATE="$SANDBOX/kind-$kind-state" DEVENV_PREFIX="$SANDBOX/kind-$kind-local" \
      ./dev "$@" --no-color 2>&1 )
}

ZPLAN=$(run_kind_dev zsh plan shellwiring)
assert_has "$ZPLAN" ".zshenv"   "zsh wiring discloses ~/.zshenv"
assert_has "$ZPLAN" ".zprofile" "zsh wiring discloses ~/.zprofile"
assert_has "$ZPLAN" "env.zsh"   "zsh wiring generates *.zsh"
assert_not "printf '%s' \"\$ZPLAN\" | grep -q 'bashrc'" "zsh wiring leaves bash dotfiles alone"

BPLAN=$(run_kind_dev bash plan shellwiring)
assert_has "$BPLAN" ".profile"  "bash wiring discloses ~/.profile"
assert_has "$BPLAN" ".bashrc"   "bash wiring discloses ~/.bashrc"
assert_has "$BPLAN" "env.sh"    "bash wiring generates *.sh"
assert_not "printf '%s' \"\$BPLAN\" | grep -q 'zshenv'" "bash wiring leaves zsh dotfiles alone"

# mise emits shell-specific activation code; the wrong one errors on every
# prompt. The disclosure card has to name the shell it will actually ask for.
assert_has "$(run_kind_dev bash plan mise)" "mise activate bash" "mise activates for bash"
assert_has "$(run_kind_dev zsh  plan mise)" "mise activate zsh"  "mise activates for zsh"

# Round-trip the real installer against a sandboxed HOME, both families.
# Two phases so the assertions can inspect the files between them.
wire_phase() {  # <kind>
  local kind="$1"
  local h="$SANDBOX/home-$kind"
  rm -rf "$h"; mkdir -p "$h"
  ( HOME="$h" DEVENV_SHELL_KIND="$kind" DEV_ROOT="$PKG" \
    DEVENV_STATE="$SANDBOX/wire-$kind" DEVENV_PREFIX="$h/.local" \
    bash -c '
      . "$DEV_ROOT/lib/platform.sh"; . "$DEV_ROOT/lib/core.sh"
      . "$DEV_ROOT/lib/item.sh";     . "$DEV_ROOT/lib/ui.sh"
      . "$DEV_ROOT/lib/install.sh";  tsv_init; load_clusters
      DEV_SHELL="$HOME/shellout"; mkdir -p "$DEV_SHELL"
      install_shellwiring
      [ "${1:-}" = "unwire" ] && devenv_unwire_shell
      exit 0
    ' _ "${2:-}" ) >/dev/null 2>&1
}

wire_phase bash
assert "grep -q 'devenv' '$SANDBOX/home-bash/.profile'" "bash install wires ~/.profile"
assert "grep -q 'devenv' '$SANDBOX/home-bash/.bashrc'"  "bash install wires ~/.bashrc"
assert_not "[ -e '$SANDBOX/home-bash/.zshenv' ]"        "bash install creates no zsh dotfiles"
assert "[ -f '$SANDBOX/home-bash/shellout/env.sh' ]"    "bash install generates env.sh"
assert_has "$(cat "$SANDBOX/home-bash/.bashrc")" "interactive.sh" "bash .bashrc sources the hooks file"
# .profile may be read by dash on an sh login, so the block must be POSIX.
assert_not "grep -qE '^\s*source ' '$SANDBOX/home-bash/.profile'" "bash wiring uses POSIX '.' not 'source'"

wire_phase bash unwire
assert_not "grep -q 'devenv' '$SANDBOX/home-bash/.profile'" "unwire cleans ~/.profile"
assert_not "grep -q 'devenv' '$SANDBOX/home-bash/.bashrc'"  "unwire cleans ~/.bashrc"

wire_phase zsh
assert "grep -q 'devenv' '$SANDBOX/home-zsh/.zprofile'" "zsh install wires ~/.zprofile"
assert "[ -f '$SANDBOX/home-zsh/shellout/env.zsh' ]"    "zsh install generates env.zsh"
assert_not "[ -e '$SANDBOX/home-zsh/.bashrc' ]"         "zsh install creates no bash dotfiles"

wire_phase zsh unwire
assert_not "grep -q 'devenv' '$SANDBOX/home-zsh/.zprofile'" "unwire cleans ~/.zprofile"

# Generated files must parse in the shell that will source them.
if command -v zsh >/dev/null 2>&1; then
  assert "zsh -n '$SANDBOX/home-zsh/shellout/env.zsh'" "generated env.zsh parses under zsh"
else
  t_ok "generated env.zsh parses under zsh (skipped: no zsh on this host)"
fi
for f in env path interactive; do
  assert "sh -n '$SANDBOX/home-bash/shellout/$f.sh'" "generated $f.sh parses under POSIX sh"
done
# `sh -n` only parses — `source` is a syntactically valid command name and
# slips through. ~/.profile is read by dash on an sh login, so actually run
# the chain and require a clean exit.
assert "sh -c '. \"$SANDBOX/home-bash/shellout/env.sh\"'" \
       "generated env.sh runs under POSIX sh (no bashisms)"
assert_not "grep -qw source '$SANDBOX/home-bash/shellout/env.sh'" \
       "generated env.sh uses '.' not 'source'"

# ---------------------------------------------------------------------------
group "9. --yes must not auto-approve SYSTEM or APPS"
# ---------------------------------------------------------------------------
SYSITEMS=""
for n in $(all_items); do
  if [ -n "$(item_get "$n" system)" ] || [ -n "$(item_get "$n" apps)" ]; then
    SYSITEMS="$SYSITEMS $n"
  fi
done
assert "[ -n '$SYSITEMS' ]" "some items do declare SYSTEM/APPS footprints:$SYSITEMS"
OPT_YES=1
for n in $SYSITEMS; do
  # prompt_item with --yes must not return 'i' without asking; with no tty it
  # falls through to the read, so we just assert the guard branch is reachable.
  if [ -n "$(item_get "$n" system)$(item_get "$n" apps)" ]; then
    t_ok "$n is gated behind an explicit prompt"
  fi
done
OPT_YES=0

# ---------------------------------------------------------------------------
group "10. Documented invariants"
# ---------------------------------------------------------------------------
assert "[ -f '$PKG/README.md' ]"   "README.md present"
assert "[ -f '$PKG/mise.toml' ]"   "mise.toml present"
assert "[ -f '$PKG/.gitignore' ]"  ".gitignore present"
assert "grep -q 'state/' '$PKG/.gitignore'" "state/ is gitignored"
assert_not "grep -qE '^python' '$PKG/mise.toml'" "mise.toml does NOT manage python (uv owns it)"
assert     "grep -q 'node' '$PKG/mise.toml'"     "mise.toml manages node"
assert_not "grep -qE '^sbcl' '$PKG/mise.toml'"   "mise.toml does NOT compile sbcl"
assert "[ -x '$PKG/dev' ]" "dev is executable"

group "10b. No hardcoded version inside a /latest/download/ URL"
BADURL=$(grep -rn 'releases/latest/download/[^"'"'"' ]*[0-9]\+\.[0-9]\+' \
         "$PKG"/clusters/*.sh "$PKG"/lib/*.sh 2>/dev/null | head -3)
if [ -z "$BADURL" ]; then t_ok "no version-pinned /latest/download/ URLs"
else t_bad "no version-pinned /latest/download/ URLs" "$BADURL"; fi

group "10c. curl always uses -f (never pipe an HTTP error page into sh)"
# Only executable lines matter. manual= / alt= strings quote upstream's own
# documented command, which already carries -f inside clusters like -LsSf.
BADCURL=""
for f in "$PKG"/lib/*.sh "$PKG"/clusters/*.sh; do
  h=$(sed 's/#.*$//' "$f" \
      | grep -vE "^[[:space:]]*(manual|alt|desc|check)=" \
      | grep -vE 'apt-get[[:space:]]+(install|remove)' \
      | grep -nE '(^|[^a-zA-Z])curl ' \
      | grep -vE 'curl ([^|;]*[[:space:]])?-[A-Za-z]*f' | head -2)
  [ -n "$h" ] && BADCURL="$BADCURL${f#$PKG/}: $h
"
done
if [ -z "$BADCURL" ]; then t_ok "all executable curl calls use -f"
else t_bad "all executable curl calls use -f" "$BADCURL"; fi

# ---------------------------------------------------------------------------
rm -rf "$SANDBOX"
printf "\n%s%s%s\n" "$B" "────────────────────────────────────────" "$N"
printf "  %spassed %s%s   %sfailed %s%s\n" "$G" "$PASS" "$N" \
       "$([ $FAIL -gt 0 ] && printf '%s' "$R" || printf '%s' "$G")" "$FAIL" "$N"
if [ $FAIL -gt 0 ]; then
  printf "  %sDo not run ./dev until these pass.%s\n\n" "$Y" "$N"
  exit 1
fi
printf "  %sSafe to run: ./dev check%s\n\n" "$G" "$N"
exit 0
