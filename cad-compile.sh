#!/bin/bash
# Stage the prebuilt agent binary for this target so cad-install.sh can place it.
#
# This fetches a release artifact rather than compiling from source, as
# ext-microclaw does, with one difference: mc-compile.sh pins a sha256 per
# architecture in the script, and this script reads its digests from the same
# release as the artifact. The reason for fetching is not laziness about
# cross-compiling: `avocado ext package` runs no build step, so the published RPM
# can only carry what is in the repo. Shipping the crate source instead pushed the
# compile onto the consumer, and a consumer has no reason to have a Rust cross
# toolchain in their SDK. Measured 2026-09-15: a clean project following the
# documented setup failed inside ring's build script with
# `ToolNotFound: failed to find tool "x86_64-avocado-linux-gcc"`, after both
# `avocado install` and the extension's own sysroot creation had reported success.
#
# The binaries are statically linked against musl, so they carry no libc version
# coupling and run on any Avocado target of the right architecture regardless of
# what the device's glibc is.
set -euo pipefail

VERSION="${AVOCADO_EXT_VERSION:-}"
if [ -z "$VERSION" ]; then
    # The first indented `version:` is the extension's own. Accept it bare or
    # quoted: `avocado ext package` rewrites it to `version: '0.2.0'` in the
    # avocado.yaml a consumer receives, so the unquoted form only ever appears in
    # this repo. Keep a prerelease suffix, since the release workflow tags
    # `X.Y.Z-*` and those assets are named after the full tag.
    VERSION=$(sed -nE "/^[[:space:]]+version:/{s/^[[:space:]]+version:[[:space:]]*['\"]?([0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?)['\"]?[[:space:]]*(#.*)?\$/\1/p;q;}" \
        "$(dirname "$0")/avocado.yaml")
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

# A tarball and SHA256SUMS placed in dist/ next to this script are used instead
# of the release, with the same file names the release workflow produces. This
# lets a build run against binaries that are not released yet, and without
# network access.
PREBUILT_DIR="$(cd "$(dirname "$0")" && pwd)/dist"

STAGE_DIR="${AVOCADO_BUILD_DIR}/agent"
mkdir -p "$STAGE_DIR"
cd "$STAGE_DIR"

CLEAN_HINT="Run 'avocado ext clean' (or 'avocado sdk clean') to discard the cached download in ${STAGE_DIR}, then build again."

# Print the digest SUMS_FILE records for ASSET, or nothing when it is not listed.
listed_digest() {
    awk -v a="$ASSET" '$2 == a { print $1; exit }' "$1"
}

# True when FILE hashes to the digest SUMS_FILE records for ASSET.
matches_sums() {
    local want got
    want="$(listed_digest "$2")"
    got="$(sha256sum "$1" | cut -d' ' -f1)"
    [ -n "$want" ] && [ "$want" = "$got" ]
}

# Download through a .part file and rename only on success, so an interrupted
# fetch never leaves a partial file behind under the final name.
fetch() {
    echo "Fetching $1"
    curl -fsSL --retry 3 --retry-delay 2 -o "$2.part" "$1"
    mv "$2.part" "$2"
}

echo "resolved-artifact: ${ASSET}"

# SHA256SUMS comes from the same release as the artifact, so this verifies the
# transfer, not the provenance. Anyone who can replace the release assets can
# replace both files together and this check still passes. The digests are not
# pinned anywhere outside the release; dist/ is where a pinned copy would go.
if [ -f "${PREBUILT_DIR}/${ASSET}" ] && [ -f "${PREBUILT_DIR}/SHA256SUMS" ]; then
    echo "Using ${PREBUILT_DIR}/${ASSET} instead of the ${VERSION} release"
    SUMS="${PREBUILT_DIR}/SHA256SUMS"
    if [ -z "$(listed_digest "$SUMS")" ]; then
        echo "Error: ${SUMS} does not list ${ASSET}" >&2
        exit 1
    fi
    if ! matches_sums "${PREBUILT_DIR}/${ASSET}" "$SUMS"; then
        echo "Error: ${PREBUILT_DIR}/${ASSET} does not match ${SUMS}" >&2
        exit 1
    fi
    TARBALL="${PREBUILT_DIR}/${ASSET}"
else
    if [ -f "${PREBUILT_DIR}/${ASSET}" ] || [ -f "${PREBUILT_DIR}/SHA256SUMS" ]; then
        echo "Warning: ${PREBUILT_DIR} holds only one of ${ASSET} and SHA256SUMS, so it is ignored and the ${VERSION} release is used" >&2
    fi
    # Cached per version, so a rebuild needs no network once both files are
    # here, and a version bump never reads the previous version's sums.
    SUMS="SHA256SUMS-${VERSION}"
    if [ ! -f "$SUMS" ]; then
        fetch "${BASE}/SHA256SUMS" "$SUMS"
    elif [ -z "$(listed_digest "$SUMS")" ]; then
        # A cached file that does not list this asset may be a page a proxy
        # served with a 200, or a copy fetched before the release was complete.
        # Fetch it once more rather than failing on it for every later build.
        echo "Cached ${SUMS} does not list ${ASSET}; fetching it again"
        fetch "${BASE}/SHA256SUMS" "$SUMS"
    fi
    if [ -z "$(listed_digest "$SUMS")" ]; then
        echo "Error: SHA256SUMS from the ${VERSION} release does not list ${ASSET}" >&2
        echo "The release is incomplete for this architecture; do not install it." >&2
        echo "${CLEAN_HINT}" >&2
        exit 1
    fi

    if [ -f "$ASSET" ] && ! matches_sums "$ASSET" "$SUMS"; then
        echo "Cached ${ASSET} does not match ${SUMS}; downloading it again"
        rm -f "$ASSET"
    fi
    if [ ! -f "$ASSET" ]; then
        echo "Fetching ${BASE}/${ASSET}"
        curl -fsSL --retry 3 --retry-delay 2 -o "${ASSET}.part" "${BASE}/${ASSET}"
        # Verify before the rename, so a file this script writes under the final
        # name has matched the sums.
        if ! matches_sums "${ASSET}.part" "$SUMS"; then
            rm -f "${ASSET}.part"
            echo "Error: the downloaded ${ASSET} does not match ${SUMS}" >&2
            echo "$CLEAN_HINT" >&2
            exit 1
        fi
        mv "${ASSET}.part" "$ASSET"
    fi
    TARBALL="$ASSET"
fi

tar -xzf "$TARBALL"

if [ ! -f avocado-container-agent-dev ]; then
    echo "Error: ${ASSET} did not contain avocado-container-agent-dev" >&2
    exit 1
fi

chmod 0755 avocado-container-agent-dev
echo "avocado-container-agent-dev ${VERSION} staged for ${ASSET_ARCH}"
