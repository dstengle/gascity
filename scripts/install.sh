#!/bin/sh
# Install the gc binary from the dstengle/gascity personal build.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/dstengle/gascity/personal-config/scripts/install.sh | sh
#
# Environment variables:
#   GC_INSTALL_DIR  — destination directory (default: /usr/local/bin)
#   GC_VERSION      — release tag to install (default: personal-latest)

set -eu

REPO="dstengle/gascity"
VERSION="${GC_VERSION:-personal-latest}"
INSTALL_DIR="${GC_INSTALL_DIR:-/usr/local/bin}"

# Detect OS
case "$(uname -s)" in
  Linux)  OS="linux"  ;;
  Darwin) OS="darwin" ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac

# Detect architecture
case "$(uname -m)" in
  x86_64)          ARCH="amd64" ;;
  amd64)           ARCH="amd64" ;;
  arm64 | aarch64) ARCH="arm64" ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

BINARY="gc-${OS}-${ARCH}"
URL="https://github.com/${REPO}/releases/download/${VERSION}/${BINARY}"
DEST="${INSTALL_DIR}/gc"

echo "Downloading gc ${VERSION} for ${OS}/${ARCH}..."

# Download using curl or wget, whichever is available
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$URL" -o "$TMP"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$TMP" "$URL"
else
  echo "Error: curl or wget is required" >&2
  exit 1
fi

chmod +x "$TMP"

# Install, using sudo if needed
if [ -w "$INSTALL_DIR" ]; then
  mv -f "$TMP" "$DEST"
else
  echo "Installing to ${DEST} (sudo required)..."
  sudo mv -f "$TMP" "$DEST"
fi

echo "Installed: $(command -v gc) — $("$DEST" version 2>/dev/null || echo "gc installed")"
