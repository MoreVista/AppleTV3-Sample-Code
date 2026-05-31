#!/bin/bash
# ============================================================
# build.sh — HelloWorldATV ビルド & インストールスクリプト
# ============================================================

set -e

: "${THEOS:=/opt/theos}"
: "${THEOS_DEVICE_IP:=AppleTV.local}"
: "${THEOS_DEVICE_PORT:=22}"

export THEOS THEOS_DEVICE_IP THEOS_DEVICE_PORT

echo "=== [1/5] Clean ==="
make clean

echo ""
echo "=== [2/5] Build ==="
make

echo ""
echo "=== [3/5] Package ==="
make package

echo ""
echo "=== [4/5] Install → ${THEOS_DEVICE_IP} ==="
make install

echo ""
echo "Done. AppleTV should restart automatically."
