#!/usr/bin/env bash
cluster 55-mobile-dev

item name=kotlin \
  desc="Kotlin CLI compiler via mise — JVM tooling for Kotlin and Android projects" \
  check='command -v kotlinc' version='kotlinc -version 2>&1' method=mise \
  home="~/.local/share/mise/installs/kotlin:compiler|$DEV_CONFIG_DIR/mise.toml:+ kotlin runtime entry" \
  shell='mise shims:kotlinc and kotlinr' \
  network='github.com/JetBrains/kotlin releases via mise' system='' apps='' receipt='' \
  purge='mise unuse --global --no-prune kotlin; mise uninstall --all kotlin' \
  manual='mise use --global --fuzzy kotlin@latest' \
  alt='Android projects should use their checked-in Gradle wrapper; a global Gradle install is intentionally omitted' \
  install=install_kotlin
install_kotlin() {
  have mise || { err "mise missing — run: dev install mise"; return 1; }
  have java || { err "Java missing — run: dev install mise"; return 1; }
  run mise use --global --fuzzy --yes kotlin@latest
}

item name=android-studio \
  supports=darwin \
  desc="Android Studio — official Kotlin/Android IDE (SDK setup wizard runs separately)" \
  check='[ -d "/Applications/Android Studio.app" ]' version='' method=manual \
  home='~/Library/Application Support/Google/AndroidStudio*:settings and caches|~/.android:devices, debug keys, and state' \
  shell='' network='developer.android.com/studio (manual download and license)' system='' \
  apps='/Applications/Android Studio.app:IDE ~4GB' receipt='' \
  purge='rm -rf "/Applications/Android Studio.app" "$HOME/.android" "$HOME/Library/Application Support/Google/AndroidStudio"*' \
  manual='Download Android Studio for Apple silicon from https://developer.android.com/studio, drag it to /Applications, then complete its Setup Wizard' \
  install=install_android_studio
install_android_studio() {
  if [ -d "/Applications/Android Studio.app" ]; then return 0; fi
  warn "Android Studio requires accepting Google's license and completing its Setup Wizard."
  inf "1. download the Apple-silicon build from https://developer.android.com/studio"
  inf "2. drag Android Studio.app to /Applications and launch it"
  inf "3. let the Setup Wizard install the recommended SDK, emulator, and platform"
  inf "4. re-run: dev install android-studio android-sdk"
  return 1
}

item name=android-sdk \
  supports=darwin \
  desc="Android SDK + platform tools + emulator — build and test Android apps" \
  check='[ -x "$HOME/Library/Android/sdk/platform-tools/adb" ] && [ -x "$HOME/Library/Android/sdk/emulator/emulator" ] && find "$HOME/Library/Android/sdk/platforms" -mindepth 1 -maxdepth 1 -type d -name "android-*" 2>/dev/null | grep -q .' \
  version='"$HOME/Library/Android/sdk/platform-tools/adb" version' method=manual \
  home='~/Library/Android/sdk:SDK, platforms, build tools, emulator, and system images (10GB+)' \
  shell='env.zsh:ANDROID_HOME and ANDROID_SDK_ROOT|path.zsh:platform-tools, emulator, cmdline-tools' \
  network='Android Studio SDK Manager / dl.google.com' system='' apps='' receipt='' \
  purge='rm -rf "$HOME/Library/Android/sdk"' \
  manual='In Android Studio: Settings > Languages & Frameworks > Android SDK; install an SDK Platform, Platform-Tools, Emulator, Command-line Tools, and one system image' \
  install=install_android_sdk
install_android_sdk() {
  local sdk="$HOME/Library/Android/sdk"
  [ -d "/Applications/Android Studio.app" ] || {
    err "Android Studio missing — run: dev install android-studio"
    return 1
  }
  [ -d "$sdk" ] || {
    warn "Launch Android Studio and complete its SDK Setup Wizard, then re-run this item."
    return 1
  }
  shellent_add android-sdk env 'export ANDROID_HOME="$HOME/Library/Android/sdk"'
  shellent_add android-sdk env 'export ANDROID_SDK_ROOT="$ANDROID_HOME"'
  shellent_add android-sdk path "$sdk/platform-tools"
  shellent_add android-sdk path "$sdk/emulator"
  shellent_add android-sdk path "$sdk/cmdline-tools/latest/bin"
  regen_shell
  [ -x "$sdk/platform-tools/adb" ] && [ -x "$sdk/emulator/emulator" ] &&
    find "$sdk/platforms" -mindepth 1 -maxdepth 1 -type d -name 'android-*' 2>/dev/null | grep -q . && return 0
  warn "SDK incomplete — install Platform-Tools, Emulator, an SDK Platform, and a system image in Android Studio's SDK Manager."
  return 1
}

item name=xcode-ios \
  supports=darwin \
  desc="Full Xcode + iOS SDK and Simulator runtime — build and test Swift iOS apps" \
  check='[ -d "/Applications/Xcode.app" ] && DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -showsdks 2>/dev/null | grep -q iphoneos && DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl list runtimes available 2>/dev/null | grep -q "iOS"' \
  version='DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -version' method=manual \
  home='~/Library/Developer/Xcode:derived data, archives, and device support' shell='' \
  network='Mac App Store + Apple Xcode component downloads' \
  system='/Library/Developer/CoreSimulator:iOS Simulator runtimes (several GB)' \
  apps='/Applications/Xcode.app:full IDE and Apple SDKs (15GB+)' \
  receipt='Mac App Store receipt + Xcode license' \
  purge='sudo rm -rf "/Applications/Xcode.app" "/Library/Developer/CoreSimulator"; rm -rf "$HOME/Library/Developer/Xcode"' \
  manual='Install Xcode from the Mac App Store; open it once, accept the license, select Xcode in Settings > Locations, then install an iOS Simulator runtime in Settings > Components' \
  install=install_xcode_ios
install_xcode_ios() {
  if [ ! -d "/Applications/Xcode.app" ]; then
    warn "Full Xcode must be installed through Apple."
    inf "1. install Xcode from the Mac App Store"
    inf "2. open it once and accept the license"
    inf "3. install the current iOS Simulator runtime in Xcode > Settings > Components"
    inf "4. run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
    inf "5. re-run: dev install xcode-ios"
    return 1
  fi
  if ! DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl list runtimes available 2>/dev/null | grep -q "iOS"; then
    warn "Xcode is installed, but no iOS Simulator runtime is available."
    inf "Install it in Xcode > Settings > Components, then re-run this item."
    return 1
  fi
  return 0
}
