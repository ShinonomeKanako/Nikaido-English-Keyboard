#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build/cache .build/config .build/security .build/ModuleCache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
swift "$@" --disable-sandbox --cache-path "$PWD/.build/cache" --config-path "$PWD/.build/config" --security-path "$PWD/.build/security"
