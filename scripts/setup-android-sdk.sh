#!/usr/bin/env bash
set -euo pipefail

# Helper: Attempt to download Android command-line tools and install basic SDK packages.
# Usage: bash scripts/setup-android-sdk.sh
# This script is designed to be run on a developer machine (not in a restricted CI container).

SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
TMPDIR="/tmp/raahi-android-sdk-$$"
ZIP_URL="https://dl.google.com/android/repository/commandlinetools-linux-latest.zip"
ZIP_FILE="$TMPDIR/commandlinetools.zip"

echo "Android SDK root: $SDK_ROOT"
mkdir -p "$SDK_ROOT"
mkdir -p "$TMPDIR"

echo "Downloading Android command-line tools from: $ZIP_URL"
# try download (follow redirects). If network blocked this will fail with non-zero exit.
if curl -fL -o "$ZIP_FILE" "$ZIP_URL"; then
  echo "Download complete: $ZIP_FILE"
else
  echo "\nDownload failed (HTTP error or network blocked)."
  echo "This environment may not have outbound access to dl.google.com."
  echo "FALLBACK: Please manually download the 'Command line tools' for Linux from:" 
  echo "  https://developer.android.com/studio#command-tools"
  echo "Then copy the downloaded zip into the machine and re-run this script or follow the manual steps below."
  echo "\nManual placement instructions (if you have the zip locally):"
  echo "  export ANDROID_SDK_ROOT=\"$SDK_ROOT\""
  echo "  mkdir -p \"$SDK_ROOT/cmdline-tools\""
  echo "  unzip -q PATH_TO_YOUR_DOWNLOADED_ZIP -d /tmp"
  echo "  mv /tmp/cmdline-tools \"$SDK_ROOT/cmdline-tools/latest\""
  echo "  ls -la \"$SDK_ROOT/cmdline-tools/latest/bin\""
  echo "\nAfter placing the commandline tools, re-run: sdkmanager --sdk_root=\"$ANDROID_SDK_ROOT\" --licenses"
  rm -rf "$TMPDIR"
  exit 1
fi

# Verify zip is actually a zip
if ! file "$ZIP_FILE" | grep -qi 'zip'; then
  echo "Downloaded file is not a zip (likely an HTML error page). Aborting." 
  file "$ZIP_FILE"
  rm -rf "$TMPDIR"
  exit 2
fi

# Unpack and move to SDK path
unzip -q "$ZIP_FILE" -d "$TMPDIR"
if [ -d "$TMPDIR/cmdline-tools" ]; then
  mkdir -p "$SDK_ROOT/cmdline-tools"
  mv "$TMPDIR/cmdline-tools" "$SDK_ROOT/cmdline-tools/latest"
  echo "Installed commandline tools to $SDK_ROOT/cmdline-tools/latest"
else
  # Some zips might unpack to a folder like 'cmdline-tools' or another name; try to detect
  found=$(find "$TMPDIR" -maxdepth 2 -type d -name 'cmdline-tools' | head -n1 || true)
  if [ -n "$found" ]; then
    mkdir -p "$SDK_ROOT/cmdline-tools"
    mv "$found" "$SDK_ROOT/cmdline-tools/latest"
    echo "Installed commandline tools to $SDK_ROOT/cmdline-tools/latest"
  else
    echo "Could not find 'cmdline-tools' inside the zip. Please inspect the zip file." 
    ls -la "$TMPDIR"
    rm -rf "$TMPDIR"
    exit 3
  fi
fi

# Ensure sdkmanager is available
export PATH="$SDK_ROOT/cmdline-tools/latest/bin:$SDK_ROOT/emulator:$SDK_ROOT/platform-tools:$PATH"

if ! command -v sdkmanager >/dev/null 2>&1; then
  echo "sdkmanager not found on PATH even after extraction. PATH=$PATH"
  echo "You may need to open a new shell or add the following to your ~/.bashrc:"
  echo "  export ANDROID_SDK_ROOT=\"$SDK_ROOT\""
  echo "  export PATH=\"$SDK_ROOT/cmdline-tools/latest/bin:$SDK_ROOT/emulator:$SDK_ROOT/platform-tools:\$PATH\""
  rm -rf "$TMPDIR"
  exit 4
fi

# Accept licenses and install basic packages
echo "Accepting SDK licenses (interactive prompts may appear)..."
yes | sdkmanager --sdk_root="$SDK_ROOT" --licenses || true

echo "Installing platform-tools, emulator, build-tools and a system image (android-33, x86_64)..."
sdkmanager --sdk_root="$SDK_ROOT" "platform-tools" "emulator" "platforms;android-33" "build-tools;33.0.2" "system-images;android-33;google_apis;x86_64"

echo "Creating an AVD named 'raahi_avd' (pixel device). If avdmanager is not installed, use Android Studio AVD Manager instead."
if command -v avdmanager >/dev/null 2>&1; then
  echo "Creating AVD..."
  echo no | avdmanager create avd -n raahi_avd -k "system-images;android-33;google_apis;x86_64" --device "pixel"
  echo "AVD 'raahi_avd' created. Start it with: emulator -avd raahi_avd"
else
  echo "avdmanager not found. You can create an AVD from Android Studio's AVD Manager instead."
fi

# Cleanup
rm -rf "$TMPDIR"

echo "Done. To use the SDK tools in this shell, run:"
echo "  export ANDROID_SDK_ROOT=\"$SDK_ROOT\""
echo "  export PATH=\"$SDK_ROOT/cmdline-tools/latest/bin:$SDK_ROOT/emulator:$SDK_ROOT/platform-tools:\$PATH\""

echo "You can now run: flutter doctor && flutter devices"

exit 0
