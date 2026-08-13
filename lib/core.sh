#!/usr/bin/env bash
# lib/core.sh — paths, colours, logging.
# Bash 3.2 compatible (macOS ships bash 3.2; no assoc arrays, no mapfile).

: "${DEV_ROOT:?DEV_ROOT must be set by the dev entrypoint}"

DEV_LIB="$DEV_ROOT/lib"
DEV_CLUSTERS="$DEV_ROOT/clusters"
DEV_SHELL="$DEV_ROOT/shell"
DEV_STATE="${DEVENV_STATE:-$DEV_ROOT/state}"
DEV_LOGS="$DEV_STATE/logs"

REGISTRY="$DEV_STATE/registry.tsv"
DEFERRED="$DEV_STATE/deferred.tsv"
SHELLENTS="$DEV_STATE/shellents.tsv"

LOCAL_PREFIX="${DEVENV_PREFIX:-$HOME/.local}"
LOCAL_BIN="$LOCAL_PREFIX/bin"
LOCAL_OPT="$LOCAL_PREFIX/opt"

OPT_YES=0
OPT_DRYRUN=0
OPT_VERBOSE=0
OPT_RETRY_DEFERRED=0

mkdir -p "$DEV_STATE" "$DEV_LOGS" "$DEV_SHELL"

# --- colour ----------------------------------------------------------------
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ] && [ "${OPT_NOCOLOR:-0}" != "1" ]; then
  C_B=$'\033[1m';  C_D=$'\033[2m';  C_R=$'\033[0m'
  C_CY=$'\033[1;36m'; C_YE=$'\033[1;33m'; C_RD=$'\033[1;31m'; C_GN=$'\033[1;32m'
else
  C_B=""; C_D=""; C_R=""; C_CY=""; C_YE=""; C_RD=""; C_GN=""
fi
no_color() { C_B=""; C_D=""; C_R=""; C_CY=""; C_YE=""; C_RD=""; C_GN=""; }

strip_ansi() { sed $'s/\033\\[[0-9;]*[a-zA-Z]//g'; }

# --- logging ---------------------------------------------------------------
LOGFILE=""
log_open() {
  local action="${1:-run}" stamp
  stamp=$(date +%Y%m%dT%H%M%S)
  LOGFILE="$DEV_LOGS/${stamp}-${action}.log"
  {
    echo "devenv log"
    echo "action    : $action $*"
    echo "date      : $(date)"
    echo "host      : $(hostname 2>/dev/null)"
    echo "os        : $(sw_vers -productVersion 2>/dev/null || uname -sr)"
    echo "arch      : $(uname -m)"
    echo "shell     : ${SHELL:-?}"
    echo "bash      : ${BASH_VERSION:-?}"
    echo "devenv    : $DEV_ROOT"
    echo "git       : $(cd "$DEV_ROOT" 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo 'not a repo')"
    echo "----------------------------------------------------------------"
  } > "$LOGFILE"
  ln -sf "$LOGFILE" "$DEV_LOGS/latest.log" 2>/dev/null
  log_prune
}
log_prune() {
  local n
  n=$(ls -1 "$DEV_LOGS"/*.log 2>/dev/null | grep -v latest | wc -l | tr -d ' ')
  [ "${n:-0}" -gt 30 ] || return 0
  ls -1t "$DEV_LOGS"/*.log 2>/dev/null | grep -v latest | tail -n +31 | while read -r f; do rm -f "$f"; done
}
logline() { [ -n "$LOGFILE" ] && printf '%s\n' "$*" | strip_ansi >> "$LOGFILE"; return 0; }

# --- output (goes to terminal coloured, log stripped) ----------------------
say()  { printf "\n%s==> %s%s\n" "$C_CY" "$*" "$C_R"; logline "==> $*"; }
inf()  { printf "    %s\n" "$*"; logline "    $*"; }
ok()   { printf "    %s✓%s %s\n" "$C_GN" "$C_R" "$*"; logline "    [ok] $*"; }
warn() { printf "%s  ! %s%s\n" "$C_YE" "$*" "$C_R"; logline "    [warn] $*"; }
err()  { printf "%s  x %s%s\n" "$C_RD" "$*" "$C_R"; logline "    [err] $*"; }
die()  { err "$*"; exit 1; }
dim()  { printf "    %s%s%s\n" "$C_D" "$*" "$C_R"; logline "    $*"; }

have() { command -v "$1" >/dev/null 2>&1; }

# Run a command: always logged, shown only when --verbose.
run() {
  logline "+ $*"
  if [ "$OPT_DRYRUN" = "1" ]; then logline "  (dry-run, not executed)"; return 0; fi
  local rc
  if [ "$OPT_VERBOSE" = "1" ]; then
    "$@" 2>&1 | tee -a "$LOGFILE"; rc=${PIPESTATUS[0]}
  else
    "$@" >>"$LOGFILE" 2>&1; rc=$?
  fi
  logline "  exit=$rc"
  return $rc
}
# Same, for a shell string.
runsh() {
  logline "+ $1"
  if [ "$OPT_DRYRUN" = "1" ]; then logline "  (dry-run, not executed)"; return 0; fi
  local rc
  if [ "$OPT_VERBOSE" = "1" ]; then
    eval "$1" 2>&1 | tee -a "$LOGFILE"; rc=${PIPESTATUS[0]}
  else
    eval "$1" >>"$LOGFILE" 2>&1; rc=$?
  fi
  logline "  exit=$rc"
  return $rc
}

expand_tilde() { printf '%s' "${1//\~/$HOME}"; }

human_size() {
  local p total=0 sz
  for p in "$@"; do
    p=$(expand_tilde "$p")
    [ -e "$p" ] || continue
    sz=$(du -sk "$p" 2>/dev/null | awk '{print $1}')
    total=$((total + ${sz:-0}))
  done
  if   [ "$total" -gt 1048576 ]; then awk -v k="$total" 'BEGIN{printf "%.1fG", k/1048576}'
  elif [ "$total" -gt 1024 ];    then awk -v k="$total" 'BEGIN{printf "%.0fM", k/1024}'
  else printf '%sK' "$total"; fi
}
