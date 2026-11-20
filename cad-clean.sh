#!/bin/bash
# Remove what cad-compile.sh staged: the downloaded tarball, SHA256SUMS and the
# unpacked binary. Nothing is compiled any more, so there is no cargo state to
# clean, and a consumer has no cargo to clean it with.
set -euo pipefail

# `avocado sdk clean` sets AVOCADO_BUILD_DIR, but `avocado ext clean` passes
# only AVOCADO_SDK_PREFIX. Fall back to the directory the compile step uses,
# $AVOCADO_SDK_PREFIX/build/<compile section>, and refuse rather than remove a
# path built from an empty variable.
if [ -n "${AVOCADO_BUILD_DIR:-}" ]; then
    BUILD_DIR="$AVOCADO_BUILD_DIR"
elif [ -n "${AVOCADO_SDK_PREFIX:-}" ]; then
    BUILD_DIR="${AVOCADO_SDK_PREFIX}/build/avocado-container-agent-dev"
else
    echo "Error: neither AVOCADO_BUILD_DIR nor AVOCADO_SDK_PREFIX is set; not removing anything" >&2
    exit 1
fi

echo "Cleaning avocado-container-agent-dev staged files in ${BUILD_DIR}/agent"
rm -rf "${BUILD_DIR}/agent"
echo "avocado-container-agent-dev cleaned successfully"
