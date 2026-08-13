#!/usr/bin/env bash
# lib/ui.sh — footprint disclosure cards, prompts, summary tables.

W=74
rule() { local ch="${1:--}" i=0 s=""; while [ $i -lt $W ]; do s="$s$ch"; i=$((i+1)); done; printf '%s' "$s"; }

# footprint_row LABEL "value" — prints one disclosure line
fp_row() { printf "  %s%-8s%s %s\n" "$C_B" "$1" "$C_R" "$2"; logline "  $1 $2"; }

fp_multi() {  # fp_multi LABEL "a:note|b:note"
  local label="$1" val="$2" first=1 p path note
  [ -n "$val" ] || return 0
  local IFS='|'
  for p in $val; do
    path="${p%%:*}"; note="${p#*:}"; [ "$note" = "$p" ] && note=""
    if [ $first = 1 ]; then fp_row "$label" "$(printf '%-28s %s' "$path" "$note")"; first=0
    else fp_row "" "$(printf '%-28s %s' "$path" "$note")"; fi
  done
}

# The disclosure card shown before every install.
footprint_card() {
  local n="$1" state="$2"
  echo
  printf "  %s%s%s  %s[%s]%s\n" "$C_B" "$n" "$C_R" "$C_D" "$state" "$C_R"
  printf "  %s%s%s\n" "$C_D" "$(rule)" "$C_R"
  local d; d=$(item_get "$n" desc); [ -n "$d" ] && { printf "  %s\n" "$d"; logline "  $d"; }
  printf "  %s%s%s\n" "$C_D" "$(rule)" "$C_R"

  fp_multi "HOME" "$(item_get "$n" home)"
  local sh net sys apps rec
  sh=$(item_get "$n" shell); net=$(item_get "$n" network)
  sys=$(item_get "$n" system); apps=$(item_get "$n" apps); rec=$(item_get "$n" receipt)

  if [ -n "$sh" ]; then fp_multi "SHELL" "$sh"
  else fp_row "SHELL" "no change"; fi

  [ -n "$net" ] && fp_row "NETWORK" "$net"

  if [ -n "$sys" ]; then
    fp_multi "SYSTEM" "$sys"
    printf "           %sneeds sudo — outside \$HOME%s\n" "$C_YE" "$C_R"
    logline "           needs sudo - outside \$HOME"
  else fp_row "SYSTEM" "none"; fi

  if [ -n "$apps" ]; then fp_multi "APPS" "$apps"; else fp_row "APPS" "none"; fi
  if [ -n "$rec" ]; then fp_multi "RECEIPT" "$rec"; else fp_row "RECEIPT" "none"; fi

  printf "  %s%s%s\n" "$C_D" "$(rule)" "$C_R"
  fp_row "PURGE" "$(item_get "$n" purge)"
  printf "  %s%s%s\n" "$C_D" "$(rule)" "$C_R"
}

# Returns: i (install) / s (skip now) / n (never) / q (quit)
prompt_item() {
  local n="$1" ans
  if [ "$OPT_YES" = "1" ]; then
    # --yes never auto-approves a SYSTEM or APPS footprint.
    if [ -z "$(item_get "$n" system)" ] && [ -z "$(item_get "$n" apps)" ]; then
      printf '%s' i; return
    fi
    warn "--yes does not auto-approve SYSTEM/APPS footprints; asking."
  fi
  while :; do
    printf "  %s[i]%snstall  %s[s]%skip for now  %s[n]%sever  %s[d]%setails  %s[q]%suit → " \
      "$C_B" "$C_R" "$C_B" "$C_R" "$C_B" "$C_R" "$C_B" "$C_R" "$C_B" "$C_R"
    read -r ans </dev/tty || ans=q
    case "$ans" in
      i|I|y|Y|"") printf '%s' i; return ;;
      s|S)        printf '%s' s; return ;;
      n|N)        printf '%s' n; return ;;
      q|Q)        printf '%s' q; return ;;
      d|D)
        echo
        dim "method   : $(item_get "$n" method)"
        dim "check    : $(item_get "$n" check)"
        local man; man=$(item_get "$n" manual)
        [ -n "$man" ] && { dim "manual   :"; printf '%s\n' "$man" | sed 's/^/      /'; }
        local alt; alt=$(item_get "$n" alt)
        [ -n "$alt" ] && dim "alt      : $alt"
        echo ;;
      *) warn "choose i, s, n, d or q" ;;
    esac
  done
}

ask_note() {
  local note
  printf "  why? (enter to skip) → "
  read -r note </dev/tty || note=""
  printf '%s' "$note"
}

confirm_typed() {  # confirm_typed WORD "message"
  local word="$1" msg="$2" a
  printf "%s%s%s\n" "$C_YE" "$msg" "$C_R"
  printf "Type %s to confirm: " "$word"
  read -r a </dev/tty || a=""
  [ "$a" = "$word" ]
}
