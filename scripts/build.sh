#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
./scripts/swift-local.sh build -c release
app="$PWD/dist/EnKeyBoard.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/Licenses"
cp .build/release/EnKeyBoard "$app/Contents/MacOS/EnKeyBoard"
cp .build/release/enkeyboard-source "$app/Contents/MacOS/enkeyboard-source"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/lexicon.tsv "$app/Contents/Resources/lexicon.tsv"
cp Resources/lexicon.provenance.json "$app/Contents/Resources/lexicon.provenance.json"
cp Resources/Licenses/* "$app/Contents/Resources/Licenses/"
cp LICENSE "$app/Contents/Resources/LICENSE"
if [[ -f Resources/EnKeyBoard.icns ]]; then
    cp Resources/EnKeyBoard.icns "$app/Contents/Resources/"
fi
plutil -lint "$app/Contents/Info.plist"
# Swift release binaries retain debug symbols containing build-machine paths.
# Strip that metadata from packaged copies before applying their signatures.
strip -S "$app/Contents/MacOS/EnKeyBoard" "$app/Contents/MacOS/enkeyboard-source"
codesign --force --sign - "$app/Contents/MacOS/enkeyboard-source"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
touch "$app"
print "Built: $app"
