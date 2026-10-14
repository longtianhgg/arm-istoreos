#!/usr/bin/env bash
set -Eeuo pipefail

# KING3288 M3: replace ONLY the confirmed experimental USB SD card's
# existing p1 boot files and p2 ext4 rootfs. No SD bootloader, MBR, eMMC writes.
DISK=/dev/sdb
P1=/dev/sdb1
P2=/dev/sdb2
CARD_ID=/dev/disk/by-id/usb-Generic-_SD_MMC_20120501030900000-0:0
BASE=/home/dragon/king3288-build/king3288-istoreos
BUNDLE="$BASE/bin/targets/rockchip/armv7/king3288-m3-sd-files"
M1=/mnt/king3288-m3-boot
M2=/mnt/king3288-m3-root
ROOT_TAR=istoreos-rockchip-armv7-king3288-rootfs.tar.gz
mounted1=0
mounted2=0

say() { printf '[KING3288 M3] %s\n' "$*"; }
die() { printf 'ABORT: %s\n' "$*" >&2; exit 1; }

cleanup() {
  if (( mounted1 )); then sync; umount "$M1" || true; fi
  if (( mounted2 )); then sync; umount "$M2" || true; fi
}
trap cleanup EXIT

(( EUID == 0 )) || die "Run with sudo: sudo bash $BASE/build_dir/king3288-m3/deploy-sd.sh"
[[ -b "$DISK" && -b "$P1" && -b "$P2" ]] || die "Missing SD block devices"
[[ -L "$CARD_ID" && "$(readlink -f "$CARD_ID")" == "$DISK" ]] || die "USB card reader does not resolve to $DISK"
[[ "$(readlink -f "$CARD_ID-part1")" == "$P1" ]] || die "p1 by-id mismatch"
[[ "$(readlink -f "$CARD_ID-part2")" == "$P2" ]] || die "p2 by-id mismatch"
[[ "$(lsblk -dn -o RM "$DISK" | tr -d ' ')" == "1" ]] || die "Card is not removable"
[[ "$(lsblk -dn -o TRAN "$DISK" | tr -d ' ')" == "usb" ]] || die "Card is not a USB reader"
[[ "$(blkid -s PARTUUID -o value "$P1")" == "4b328826-01" ]] || die "p1 PARTUUID mismatch"
[[ "$(blkid -s PARTUUID -o value "$P2")" == "4b328826-02" ]] || die "p2 PARTUUID mismatch"
[[ "$(blkid -s TYPE -o value "$P1")" == "vfat" ]] || die "p1 is not FAT"
[[ "$(blkid -s TYPE -o value "$P2")" == "ext4" ]] || die "p2 is not ext4"
[[ "$(lsblk -dnbo SIZE "$DISK")" -gt 14000000000 ]] || die "Unexpectedly small SD card"
[[ "$(lsblk -dnbo SIZE "$DISK")" -lt 18000000000 ]] || die "Unexpectedly large SD card"
[[ -d "$BUNDLE" ]] || die "Missing M3 build files"
[[ -f "$BUNDLE/$ROOT_TAR" && -f "$BUNDLE/zImage" && -f "$BUNDLE/rk3288-king3288.dtb" ]] || die "Incomplete M3 files"

say "Checking 3 source file checksums"
(cd "$BUNDLE" && sha256sum -c SHA256SUMS) || die "Source checksum failed"

say "Verified removable $DISK (15 GiB), p1 4b328826-01, p2 4b328826-02"
say "Unmounting only $P1 and $P2"
if findmnt -rn -S "$P1" >/dev/null; then umount "$P1" || die "p1 busy: close any file manager windows"; fi
if findmnt -rn -S "$P2" >/dev/null; then umount "$P2" || die "p2 busy: close any file manager windows"; fi
if findmnt -rn -S "$P1" >/dev/null || findmnt -rn -S "$P2" >/dev/null; then die "SD card still mounted"; fi

say "Formatting ONLY $P2 as ext4 (partition table and SD boot sectors stay untouched)"
mkfs.ext4 -F -m 0 -L rootfs "$P2"

mkdir -p "$M1" "$M2"
mount -t ext4 "$P2" "$M2"
mounted2=1
say "Extracting musl ARMv7 iStoreOS rootfs to p2"
tar --numeric-owner -xzf "$BUNDLE/$ROOT_TAR" -C "$M2"
for file in sbin/init sbin/procd sbin/ubusd sbin/netifd bin/busybox; do
  [[ -s "$M2/$file" ]] || die "Missing extracted /$file"
done
[[ -e "$M2/lib/ld-musl-armhf.so.1" ]] || die "Missing ARM musl interpreter"

mount -t vfat "$P1" "$M1"
mounted1=1
say "Installing p1 zImage and KING3288 DTB"
install -m 0644 "$BUNDLE/zImage" "$M1/zImage"
install -m 0644 "$BUNDLE/rk3288-king3288.dtb" "$M1/rk3288-king3288.dtb"
mkdir -p "$M1/extlinux"
cat > "$M1/extlinux/extlinux.conf" <<'EXTLINUX'
DEFAULT istoreos
TIMEOUT 30

LABEL istoreos
LINUX /zImage
FDT /rk3288-king3288.dtb
APPEND console=ttyS2,115200n8 earlycon root=PARTUUID=4b328826-02 rootfstype=ext4 rootwait rw init=/sbin/init
EXTLINUX

cmp -s "$BUNDLE/zImage" "$M1/zImage" || die "zImage SD copy mismatch"
cmp -s "$BUNDLE/rk3288-king3288.dtb" "$M1/rk3288-king3288.dtb" || die "DTB SD copy mismatch"
grep -qF 'root=PARTUUID=4b328826-02' "$M1/extlinux/extlinux.conf" || die "root= missing"
sync
say "New extlinux.conf:"
cat "$M1/extlinux/extlinux.conf"

umount "$M1"; mounted1=0
umount "$M2"; mounted2=0
say "Checking p2 ext4 after unmount"
e2fsck -fn "$P2" || die "e2fsck reports filesystem errors"
[[ "$(blkid -s PARTUUID -o value "$P2")" == "4b328826-02" ]] || die "SD PARTUUID unexpectedly changed"
say "DEPLOY_OK — safe to remove SD after completing this command and try KING3288 UART2/115200 boot"
