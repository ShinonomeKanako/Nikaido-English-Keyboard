#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
./scripts/swift-local.sh build -c release
.build/release/enkeyboard-checks
.build/release/enkeyboard-cli --benchmark
