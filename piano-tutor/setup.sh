#!/bin/bash
# Creates PianoTutor.xcodeproj and opens it in Xcode. Run on your Mac from this folder:  ./setup.sh
set -e
cd "$(dirname "$0")"
if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing XcodeGen with Homebrew…"
    brew install xcodegen
  else
    echo "XcodeGen is needed. Install Homebrew from https://brew.sh, then run this script again."
    exit 1
  fi
fi
xcodegen generate
echo "Running the core tests…"
(cd PianoCore && swift test 2>&1 | tail -3) || echo "Some core tests failed: see the output above."
open PianoTutor.xcodeproj
