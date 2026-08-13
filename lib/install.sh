#!/usr/bin/env bash
# lib/install.sh — reusable installer primitives for cluster files.

ensure_dirs() { mkdir -p "$LOCAL_BIN" "$LOCAL_OPT"; }

# Resolve a GitHub release asset URL by pattern. Never hardcode a version in
# a /latest/download/ URL — that is a 404 waiting to happen.
gh_asset_url() {
  local repo="$1" pat="$2"
  curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
    | grep -o '"browser_download_url": *"[^"]*"' \
    | sed 's/.*"\(https[^"]*\)"/\1/' \
    | grep -iE -- "$pat" | head -1
}

unpack_into() {  # unpack_into <file> <destdir>
  local f="$1" d="$2"; mkdir -p "$d"
  # Sniff the content. Switching on the filename broke every download, because
  # the temp file is named "pkg" with no extension and fell through to cp.
  case "$(file -b "$f" 2>/dev/null)" in
    *Zip*)   unzip -oq "$f" -d "$d" ;;
    *gzip*)  tar -xzf "$f" -C "$d" ;;
    *bzip2*) tar -xjf "$f" -C "$d" ;;
    *XZ*|*xz*) tar -xJf "$f" -C "$d" ;;
    *)       cp "$f" "$d/" ;;
  esac
  rm -rf "$d/__MACOSX" 2>/dev/null
  return 0
}

install_gh_bin() {  # <repo> <asset-pattern> <binary-name>
  ensure_dirs
  local repo="$1" pat="$2" bin="$3" url tmp found
  url=$(gh_asset_url "$repo" "$pat")
  [ -n "$url" ] || { err "no release asset matching '$pat' in $repo"; return 1; }
  inf "$url"
  tmp=$(mktemp -d) || return 1
  run curl -fsSL "$url" -o "$tmp/pkg" || { rm -rf "$tmp"; return 1; }
  unpack_into "$tmp/pkg" "$tmp/x" >>"$LOGFILE" 2>&1
  found=$(find "$tmp/x" -type f -name "$bin" -not -path "*__MACOSX*" 2>/dev/null | head -1)
  [ -n "$found" ] || { err "binary '$bin' not found inside archive"; rm -rf "$tmp"; return 1; }
  install -m 0755 "$found" "$LOCAL_BIN/$bin"
  rm -rf "$tmp"
  return 0
}

install_gh_tree() {  # <repo> <asset-pattern> <opt-dirname> <bin-subdir-or-empty>
  ensure_dirs
  local repo="$1" pat="$2" dir="$3" binsub="$4" url tmp top f
  url=$(gh_asset_url "$repo" "$pat")
  [ -n "$url" ] || { err "no release asset matching '$pat' in $repo"; return 1; }
  inf "$url"
  tmp=$(mktemp -d) || return 1
  run curl -fsSL "$url" -o "$tmp/pkg" || { rm -rf "$tmp"; return 1; }
  unpack_into "$tmp/pkg" "$tmp/x" >>"$LOGFILE" 2>&1
  top=$(find "$tmp/x" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
  [ -n "$top" ] || top="$tmp/x"
  rm -rf "${LOCAL_OPT:?}/$dir"
  mv "$top" "$LOCAL_OPT/$dir"
  rm -rf "$tmp"
  if [ -n "$binsub" ] && [ -d "$LOCAL_OPT/$dir/$binsub" ]; then
    for f in "$LOCAL_OPT/$dir/$binsub"/*; do
      [ -f "$f" ] || continue
      chmod +x "$f" 2>/dev/null   # release tarballs often ship without the bit
      ln -sf "$f" "$LOCAL_BIN/$(basename "$f")"
    done
  fi
  return 0
}

# curl | sh, but with -f so an HTTP error page is never piped into a shell.
install_via_script() {  # <url> [args...]
  local url="$1"; shift
  local tmp; tmp=$(mktemp) || return 1
  run curl -fsSL "$url" -o "$tmp" || { rm -f "$tmp"; err "download failed: $url"; return 1; }
  [ -s "$tmp" ] || { rm -f "$tmp"; err "empty installer: $url"; return 1; }
  logline "--- installer script head ---"
  head -5 "$tmp" | strip_ansi >> "$LOGFILE" 2>/dev/null
  runsh "sh '$tmp' $*"
  local rc=$?
  rm -f "$tmp"
  return $rc
}
