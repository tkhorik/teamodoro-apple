#!/bin/bash
# setup.sh — one-time project bootstrap for Teamodoro
# Run from the repo root:  ./setup.sh
set -euo pipefail

echo "🍅 Teamodoro setup"
echo "==================="

# 1. Install xcodegen if missing
if ! command -v xcodegen &>/dev/null; then
  echo "→ Installing xcodegen via Homebrew..."
  if ! command -v brew &>/dev/null; then
    echo "❌ Homebrew not found. Install it first: https://brew.sh"
    exit 1
  fi
  brew install xcodegen
fi

echo "→ xcodegen $(xcodegen version)"

# 2. Generate the Xcode project
echo "→ Generating Teamodoro.xcodeproj..."
xcodegen generate --spec project.yml

echo ""
echo "✅ Done!  Opening Xcode..."
echo "   Press Cmd+R to run on the iOS Simulator."
echo ""

open Teamodoro.xcodeproj
