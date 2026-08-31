#!/usr/bin/env bash
cluster 25-containers

item name=docker \
  desc="Docker Desktop for Apple silicon — Docker CLI, Compose, Buildx, and a Linux VM" \
  check='[ -x "/Applications/Docker.app/Contents/Resources/bin/docker" ]' \
  version='"/Applications/Docker.app/Contents/Resources/bin/docker" --version' method=dmg \
  home='~/.docker:CLI config and registry credentials|~/Library/Containers/com.docker.docker:VM disk, images, volumes, and cache (can grow very large)|~/Library/Group Containers/group.com.docker:Desktop settings' \
  shell='path.zsh:/Applications/Docker.app/Contents/Resources/bin' \
  network='desktop.docker.com; Docker Hub and configured registries at runtime' \
  system='/Library/PrivilegedHelperTools/com.docker.vmnetd:optional privileged-port helper|/Library/LaunchDaemons/com.docker.vmnetd.plist:optional LaunchDaemon' \
  apps='/Applications/Docker.app:~2GB plus VM data' \
  receipt='optional com.docker.vmnetd LaunchDaemon after first-run setup' \
  purge='[ ! -x "/Applications/Docker.app/Contents/MacOS/uninstall" ] || "/Applications/Docker.app/Contents/MacOS/uninstall"; rm -rf "/Applications/Docker.app" "$HOME/.docker" "$HOME/Library/Containers/com.docker.docker" "$HOME/Library/Group Containers/group.com.docker"' \
  manual='Download Docker Desktop for Apple silicon from https://docs.docker.com/desktop/setup/install/mac-install/, drag Docker.app to /Applications, launch it, and accept its license' \
  alt='A daemonless CLI alone cannot run Linux containers on macOS; it needs Docker Desktop or another Linux VM provider' \
  install=install_docker

install_docker() {
  local tmp mount app
  ensure_dirs
  if [ ! -d "/Applications/Docker.app" ]; then
    tmp=$(mktemp -d) || return 1
    run curl -fsSL "https://desktop.docker.com/mac/main/arm64/Docker.dmg" -o "$tmp/Docker.dmg" || { rm -rf "$tmp"; return 1; }
    mount=$(hdiutil attach -nobrowse -readonly "$tmp/Docker.dmg" 2>>"$LOGFILE" \
      | awk '/\/Volumes\// {sub(/^.*\/Volumes\//,"/Volumes/"); print; exit}')
    [ -n "$mount" ] || { err "could not mount Docker.dmg"; rm -rf "$tmp"; return 1; }
    app="$mount/Docker.app"
    [ -d "$app" ] || { hdiutil detach "$mount" >>"$LOGFILE" 2>&1; rm -rf "$tmp"; err "Docker.app not found in disk image"; return 1; }
    run cp -R "$app" /Applications/ || { hdiutil detach "$mount" >>"$LOGFILE" 2>&1; rm -rf "$tmp"; return 1; }
    hdiutil detach "$mount" >>"$LOGFILE" 2>&1
    rm -rf "$tmp"
  fi
  shellent_add docker path '/Applications/Docker.app/Contents/Resources/bin'
  regen_shell
  warn "Launch Docker.app once to accept its license and start the Linux VM."
  inf "The CLI is installed now; docker info will work after Docker Desktop finishes starting."
  return 0
}
