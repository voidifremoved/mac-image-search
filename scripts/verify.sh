#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "LocalImageSearch — Build & Test Verification"
echo "========================================="

echo "[1/3] Checking Swift toolchain..."
swift --version

echo "[2/3] Building LocalImageSearch (Release)..."
swift build -c release

echo "[3/3] Running Complete Test Suite..."
swift test --parallel

echo ""
echo "========================================="
echo "All verification checks passed cleanly!"
echo "========================================="
