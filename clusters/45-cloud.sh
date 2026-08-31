#!/usr/bin/env bash
cluster 45-cloud

item name=gcloud \
  desc="Google Cloud CLI — gcloud, bq, gsutil, and the SDK component manager" \
  check='[ -x "$HOME/.local/opt/google-cloud-sdk/bin/gcloud" ]' \
  version='"$HOME/.local/opt/google-cloud-sdk/bin/gcloud" version' method=script \
  home='~/.local/opt/google-cloud-sdk:CLI and bundled components ~250MB|~/.config/gcloud:accounts, credentials, projects, and configuration' \
  shell='path.zsh:$HOME/.local/opt/google-cloud-sdk/bin' \
  network='https://sdk.cloud.google.com; Google APIs during use' \
  system='' apps='' receipt='' \
  purge='rm -rf "$HOME/.local/opt/google-cloud-sdk" "$HOME/.config/gcloud"' \
  manual='Download the current google-cloud-sdk.tar.gz from https://cloud.google.com/sdk/docs/install, extract it under ~/.local/opt, then run install.sh --quiet --install-python=false --path-update=false' \
  alt='The native SDK installer is used instead of Homebrew or mise because gcloud owns its components and updates' \
  install=install_gcloud

install_gcloud() {
  local tmp top
  ensure_dirs
  if [ ! -x "$LOCAL_OPT/google-cloud-sdk/bin/gcloud" ]; then
    tmp=$(mktemp -d) || return 1
    run curl -fsSL "https://dl.google.com/dl/cloudsdk/channels/rapid/google-cloud-sdk.tar.gz" -o "$tmp/sdk.tar.gz" || { rm -rf "$tmp"; return 1; }
    unpack_into "$tmp/sdk.tar.gz" "$tmp/unpacked" >>"$LOGFILE" 2>&1 || { rm -rf "$tmp"; return 1; }
    top="$tmp/unpacked/google-cloud-sdk"
    [ -d "$top" ] || { rm -rf "$tmp"; err "google-cloud-sdk directory not found in archive"; return 1; }
    mv "$top" "$LOCAL_OPT/google-cloud-sdk" || { rm -rf "$tmp"; return 1; }
    rm -rf "$tmp"
    run "$LOCAL_OPT/google-cloud-sdk/install.sh" --quiet \
      --install-python=false --path-update=false --command-completion=false \
      --usage-reporting=false || return 1
  fi
  shellent_add gcloud path "$LOCAL_OPT/google-cloud-sdk/bin"
  regen_shell
  inf "Run 'gcloud init' when you are ready to authenticate and choose a project."
  return 0
}
