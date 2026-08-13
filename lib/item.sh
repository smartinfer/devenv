#!/usr/bin/env bash
# lib/item.sh — the item DSL and the state tables.
#
# Bash 3.2 has no associative arrays, so items are stored as parallel indexed
# arrays: ITEM_NAMES[i] is the key, ITEM_DATA[i] is a US-delimited blob of
# key=value fields. item_get walks the blob.

US=$'\037'   # unit separator, safe field delimiter

ITEM_NAMES=()
ITEM_DATA=()
ITEM_CLUSTER=()
CLUSTER_LIST=""
CURRENT_CLUSTER=""

# cluster <name> — called at the top of each clusters/*.sh file
cluster() {
  CURRENT_CLUSTER="$1"
  case " $CLUSTER_LIST " in *" $1 "*) : ;; *) CLUSTER_LIST="$CLUSTER_LIST $1" ;; esac
}

# item name=... desc=... check=... ...
#
# Recognised fields:
#   name      short id, unique
#   desc      one-line description
#   check     shell expression, exit 0 == installed
#   version   shell expression printing a version (optional)
#   method    script|gh-binary|gh-tree|npm|mise|uv|tarball|dmg|manual|verify
#   home      "~/.path:note|~/.other:note"    footprint inside $HOME
#   shell     "path.zsh:+ $HOME/.cargo/bin"   generated-shell-file changes
#   network   the URL or command that reaches the network
#   system    anything outside $HOME (needs sudo) — empty means none
#   apps      anything landing in /Applications — empty means none
#   receipt   pkgutil receipt / LaunchAgent created — empty means none
#   purge     shell command that removes it
#   manual    human instructions for installing without this script
#   alt       an alternative approach, shown in status --commands
#   install   name of the bash function that performs the install
item() {
  local blob="" kv
  for kv in "$@"; do blob="${blob}${kv}${US}"; done
  local n; n=$(printf '%s' "$blob" | tr "$US" '\n' | sed -n 's/^name=//p' | head -1)
  [ -n "$n" ] || { echo "item() missing name=" >&2; return 1; }
  ITEM_NAMES[${#ITEM_NAMES[@]}]="$n"
  ITEM_DATA[${#ITEM_DATA[@]}]="$blob"
  ITEM_CLUSTER[${#ITEM_CLUSTER[@]}]="$CURRENT_CLUSTER"
}

item_index() {
  local i=0
  while [ $i -lt ${#ITEM_NAMES[@]} ]; do
    [ "${ITEM_NAMES[$i]}" = "$1" ] && { printf '%s' "$i"; return 0; }
    i=$((i+1))
  done
  return 1
}
item_get() {
  local i; i=$(item_index "$1") || return 1
  printf '%s' "${ITEM_DATA[$i]}" | tr "$US" '\n' | sed -n "s/^$2=//p" | head -1
}
item_cluster_of() { local i; i=$(item_index "$1") || return 1; printf '%s' "${ITEM_CLUSTER[$i]}"; }
item_exists()     { item_index "$1" >/dev/null 2>&1; }
items_in_cluster() {
  local i=0
  while [ $i -lt ${#ITEM_NAMES[@]} ]; do
    [ "${ITEM_CLUSTER[$i]}" = "$1" ] && printf '%s\n' "${ITEM_NAMES[$i]}"
    i=$((i+1))
  done
}
all_items() { printf '%s\n' "${ITEM_NAMES[@]}"; }
all_clusters() { printf '%s\n' $CLUSTER_LIST; }

load_clusters() {
  local f
  for f in "$DEV_CLUSTERS"/*.sh; do
    [ -f "$f" ] || continue
    # shellcheck disable=SC1090
    . "$f"
  done
}

# --- item state ------------------------------------------------------------
# ok | missing | deferred | never | failed
item_state() {
  local n="$1"
  never_has "$n"    && { printf 'never';    return; }
  deferred_has "$n" && { printf 'deferred'; return; }
  local chk; chk=$(item_get "$n" check)
  if [ -n "$chk" ] && eval "$chk" >/dev/null 2>&1; then printf 'ok'; return; fi
  registry_has "$n" && { printf 'failed'; return; }
  printf 'missing'
}
item_version_str() {
  local v; v=$(item_get "$1" version)
  [ -n "$v" ] || { printf '-'; return; }
  eval "$v" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

# ===========================================================================
# state tables
# ===========================================================================
tsv_init() {
  [ -f "$REGISTRY" ]  || printf 'name\tcluster\tmethod\tversion\troots\tpurge\tdate\n' > "$REGISTRY"
  [ -f "$DEFERRED" ]  || printf 'name\tcluster\tmode\tdate\tcount\tnote\n' > "$DEFERRED"
  [ -f "$SHELLENTS" ] || printf 'item\tkind\tpayload\n' > "$SHELLENTS"
}
tsv_drop() {  # tsv_drop <file> <name-in-col1>
  local f="$1" n="$2" t; t=$(mktemp)
  awk -F'\t' -v n="$n" 'NR==1 || $1!=n' "$f" > "$t" && mv "$t" "$f"
}
tsv_field() { awk -F'\t' -v n="$2" -v c="$3" 'NR>1 && $1==n {print $c; exit}' "$1"; }

registry_has() { awk -F'\t' -v n="$1" 'NR>1 && $1==n{f=1} END{exit !f}' "$REGISTRY"; }
registry_add() {
  local n="$1"
  tsv_drop "$REGISTRY" "$n"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$n" "$(item_cluster_of "$n")" "$(item_get "$n" method)" \
    "$(item_version_str "$n")" "$(item_roots "$n")" "$(item_get "$n" purge)" \
    "$(date +%F)" >> "$REGISTRY"
}
registry_del() { tsv_drop "$REGISTRY" "$1"; }

# deferred.tsv holds both modes; mode is 'later' or 'never'
deferred_has() { awk -F'\t' -v n="$1" 'NR>1 && $1==n && $3=="later"{f=1} END{exit !f}' "$DEFERRED"; }
never_has()    { awk -F'\t' -v n="$1" 'NR>1 && $1==n && $3=="never"{f=1} END{exit !f}' "$DEFERRED"; }
deferred_add() {  # <name> <mode> <note>
  local n="$1" mode="$2" note="$3" count
  count=$(tsv_field "$DEFERRED" "$n" 5); count=$(( ${count:-0} + 1 ))
  tsv_drop "$DEFERRED" "$n"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$n" "$(item_cluster_of "$n")" "$mode" "$(date +%F)" "$count" "$note" >> "$DEFERRED"
}
deferred_del() { tsv_drop "$DEFERRED" "$1"; }

# --- roots (filesystem footprint, comma separated) -------------------------
item_roots() {
  local out="" f p
  for f in home system apps; do
    local val; val=$(item_get "$1" "$f")
    [ -n "$val" ] || continue
    local IFS='|'
    for p in $val; do
      p="${p%%:*}"
      [ -n "$p" ] && out="${out:+$out,}$p"
    done
  done
  printf '%s' "$out"
}

# ===========================================================================
# generated shell files — rebuilt from shellents.tsv so purge is exact
# ===========================================================================
shellent_add() {  # <item> <path|env|hook> <payload>
  grep -qF "$(printf '%s\t%s\t%s' "$1" "$2" "$3")" "$SHELLENTS" 2>/dev/null && return 0
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$SHELLENTS"
}
shellent_del_item() { tsv_drop "$SHELLENTS" "$1"; }

regen_shell() {
  local hdr="# GENERATED by devenv. Do not edit — edit clusters/ and re-run."
  {
    echo "$hdr"
    echo "# sourced from ~/.zshenv : environment only, no PATH, no hooks."
    echo 'export DEVENV_ROOT="'"$DEV_ROOT"'"'
    awk -F'\t' '$2=="env"{print $3}' "$SHELLENTS"
    echo '[ -f "$HOME/.zsh_secrets" ] && source "$HOME/.zsh_secrets"'
    echo '# PATH is also applied here so non-interactive shells (agents) work.'
    echo '[ -f "'"$DEV_SHELL"'/path.zsh" ] && source "'"$DEV_SHELL"'/path.zsh"'
  } > "$DEV_SHELL/env.zsh"

  {
    echo "$hdr"
    echo "# sourced from ~/.zprofile AFTER macOS /etc/zprofile runs path_helper,"
    echo "# which is why these prepends survive. Idempotent + de-duplicating."
    echo 'devenv_path_prepend() {'
    echo '  case ":$PATH:" in *":$1:"*) return 0 ;; esac'
    echo '  [ -d "$1" ] && PATH="$1:$PATH"'
    echo '}'
    awk -F'\t' '$2=="path"{printf "devenv_path_prepend \"%s\"\n", $3}' "$SHELLENTS"
    echo 'export PATH'
  } > "$DEV_SHELL/path.zsh"

  {
    echo "$hdr"
    echo "# sourced from ~/.zshrc : interactive only (hooks, aliases, completions)."
    awk -F'\t' '$2=="hook"{print $3}' "$SHELLENTS"
  } > "$DEV_SHELL/interactive.zsh"
}
