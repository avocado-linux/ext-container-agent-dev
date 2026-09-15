#!/bin/bash
# Stage the prebuilt agent binary for this target so cad-install.sh can place it.
#
# This fetches a release artifact rather than compiling from source, which is the
# same shape ext-microclaw uses. The reason is not laziness about cross-compiling:
# `avocado ext package` runs no build step, so the published RPM can only carry
# what is in the repo. Shipping the crate source instead pushed the compile onto
# the consumer, and a consumer has no reason to have a Rust cross toolchain in
# their SDK. Measured 2026-09-15: a clean project following the documented setup
# failed inside ring's build script with
# `ToolNotFound: failed to find tool "x86_64-avocado-linux-gcc"`, after both
# `avocado install` and the extension's own sysroot creation had reported success.
#
# The binaries are statically linked against musl, so they carry no libc version
# coupling and run on any Avocado target of the right architecture regardless of
# what the device's glibc is.
set -euo pipefail

VERSION="${AVOCADO_EXT_VERSION:-}"
if [ -z "$VERSION" ]; then
    VERSION=$(grep -oE '^[[:space:]]+version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+' \
        "$(dirname "$0")/avocado.yaml" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
fi
if [ -z "$VERSION" ]; then
    echo "Error: could not determine the extension version" >&2
    exit 1
fi

# Map the SDK's architecture onto the published artifact. An unmapped
# architecture fails loudly here rather than installing nothing and leaving the
# agent silently absent from the image.
case "${OECORE_TARGET_ARCH:-}" in
x86_64) ASSET_ARCH="x86_64-unknown-linux-musl" ;;
aarch64) ASSET_ARCH="aarch64-unknown-linux-musl" ;;
"")
    echo "Error: OECORE_TARGET_ARCH is unset; cannot choose an artifact" >&2
    exit 1
    ;;
*)
    echo "Error: no prebuilt agent for OECORE_TARGET_ARCH=${OECORE_TARGET_ARCH}" >&2
    echo "Published artifacts cover x86_64 and aarch64 only. Add the architecture" >&2
    echo "to the binaries matrix in .github/workflows/release.yml and re-release." >&2
    exit 1
    ;;
esac

ASSET="avocado-container-agent-dev-${VERSION}-${ASSET_ARCH}.tar.gz"
BASE="https://github.com/avocado-linux/ext-container-agent-dev/releases/download/${VERSION}"

STAGE_DIR="${AVOCADO_BUILD_DIR}/agent"
mkdir -p "$STAGE_DIR"
cd "$STAGE_DIR"

echo "resolved-artifact: ${ASSET}"

if [ ! -f "$ASSET" ]; then
    echo "Fetching ${BASE}/${ASSET}"
    curl -fsSL -o "$ASSET" "${BASE}/${ASSET}"
fi

# SHA256SUMS comes from the same release as the artifact, so this verifies the
# transfer rather than the provenance - the release itself is the trust anchor.
# That is proportionate for a first-party artifact and avoids pinning a digest
# in this file, which would force every release through a build-commit-tag dance
# just to record the hash of something the tag itself produces.
echo "Fetching ${BASE}/SHA256SUMS"
curl -fsSL -o SHA256SUMS "${BASE}/SHA256SUMS"

if ! grep -q " ${ASSET}\$" SHA256SUMS; then
    echo "Error: SHA256SUMS from the ${VERSION} release does not list ${ASSET}" >&2
    echo "The release is incomplete for this architecture; do not install it." >&2
    exit 1
fi

grep " ${ASSET}\$" SHA256SUMS | sha256sum -c -

tar -xzf "$ASSET"

if [ ! -f avocado-container-agent-dev ]; then
    echo "Error: ${ASSET} did not contain avocado-container-agent-dev" >&2
    exit 1
fi

chmod 0755 avocado-container-agent-dev
echo "avocado-container-agent-dev ${VERSION} staged for ${ASSET_ARCH}"
