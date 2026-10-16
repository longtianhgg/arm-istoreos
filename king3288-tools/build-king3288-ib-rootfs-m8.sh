#!/usr/bin/env bash
# KING3288 M8: reproduce the 296-package iStoreOS rootfs via native ImageBuilder.
# File-only build; no /dev writes and no changes to the running board.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IB_ARCHIVE="$ROOT/bin/targets/rockchip/armv7/istoreos-imagebuilder-rockchip-armv7.Linux-x86_64.tar.zst"
PKGLIST="$ROOT/king3288-configs/m8-txpbl1-imagebuilder-packages.txt"
WORK="$ROOT/build_dir/king3288-m8-imagebuilder-repro"
test -s "$IB_ARCHIVE"
test -s "$PKGLIST"
mkdir -p "$WORK"
tar --use-compress-program=zstd -xf "$IB_ARCHIVE" -C "$WORK"
IB="$WORK/istoreos-imagebuilder-rockchip-armv7.Linux-x86_64"
test -f "$IB/Makefile"
# The stock ImageBuilder default pulls dnsmasq, while this proven M6 rootfs uses dnsmasq-full.
# Explicitly exclude the optional Btrfs toolchain that the cloud build unexpectedly
# pulls in through imagebuilder/opkg defaults. The frozen M8 manifest has none of
# these packages; kernel and board settings remain unchanged.
PKGS="-dnsmasq -btrfs-progs -kmod-fs-btrfs $(tr '\n' ' ' < "$PKGLIST")"
(
  cd "$IB"
  make info > "$WORK/info.log" 2>&1
  if ! make image PROFILE=king3288 PACKAGES="$PKGS" > "$WORK/image.log" 2>&1; then
    tail -100 "$WORK/image.log" >&2
    exit 1
  fi
)
echo M8_IMAGEBUILDER_IMAGE_RC=0
find "$IB/bin" -type f -name '*king3288*' -printf '%p %s bytes\n'
