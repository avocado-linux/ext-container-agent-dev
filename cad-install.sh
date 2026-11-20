#!/bin/bash
# Place the binary cad-compile.sh staged into the extension sysroot.
set -euo pipefail

BINARY_PATH="${AVOCADO_BUILD_DIR}/agent/avocado-container-agent-dev"

if [ ! -f "$BINARY_PATH" ]; then
    echo "Error: no staged binary at $BINARY_PATH" >&2
    echo "cad-compile.sh fetches it; this script only places it." >&2
    exit 1
fi

# The staged artifact is architecture-specific and the packaged extension is
# noarch, so nothing downstream re-checks that the two agree. Verify here, where
# the failure is one line from its cause: a mismatch otherwise ships an
# unrunnable binary that installs cleanly and fails at exec time on the device,
# past every gate that could have caught it.
case "${OECORE_TARGET_ARCH:-}" in
x86_64) EXPECT="x86-64" ;;
aarch64) EXPECT="aarch64" ;;
*)
    echo "Error: unexpected OECORE_TARGET_ARCH=${OECORE_TARGET_ARCH:-unset}" >&2
    exit 1
    ;;
esac

if command -v file >/dev/null 2>&1; then
    DESC=$(file -b "$BINARY_PATH")
    case "$DESC" in
    *"$EXPECT"*) ;;
    *)
        echo "Error: staged binary is not ${EXPECT}: ${DESC}" >&2
        exit 1
        ;;
    esac
    echo "verified-arch: ${EXPECT}"
else
    echo "Warning: 'file' unavailable; shipping the staged binary unverified" >&2
fi

echo "Installing avocado-container-agent-dev into extension"
install -D -m 755 "$BINARY_PATH" \
    "$AVOCADO_BUILD_EXT_SYSROOT/usr/bin/avocado-container-agent-dev"
echo "avocado-container-agent-dev installed successfully"
