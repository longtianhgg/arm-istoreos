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
# Freeze ImageBuilder's *available* IPK pool to the 296 tested M8 packages.
# The cloud full build may also produce optional packages such as btrfs-progs,
# which opkg installs automatically even when "-btrfs-progs" is passed.
# Prune ONLY the unpacked temporary ImageBuilder, never the original archive.
shopt -s nullglob
ipks=( "$IB"/packages/*.ipk )
test "${#ipks[@]}" -ge 296 || { echo "ERROR: ImageBuilder package pool too small"; exit 1; }
for ipk in "${ipks[@]}"; do
  name="${ipk##*/}"
  name="${name%%_*}"
  if ! grep -Fxq "$name" "$PKGLIST"; then
    echo "M8_FILTER_OPTIONAL_IPK $name"
    rm -f -- "$ipk"
  fi
done
missing=0
while IFS= read -r name; do
  found=( "$IB/packages/${name}_"*.ipk )
  if [ "${#found[@]}" -eq 0 ]; then
    echo "ERROR: missing pinned IPK: $name" >&2
    missing=1
  fi
done < "$PKGLIST"
test "$missing" -eq 0
echo M8_IMAGEBUILDER_PACKAGE_POOL_PINNED_296

# The stock ImageBuilder default pulls dnsmasq, while M8 uses dnsmasq-full.
PKGS="-dnsmasq $(tr '\n' ' ' < "$PKGLIST")"
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
