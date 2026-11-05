#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2013 OpenWrt.org
#
# iStoreOS adaptation:
#   p1 = boot
#   p2 = squashfs rootfs
#   p3 = writable overlay (optional)

set -ex

[ $# -eq 6 ] || [ $# -eq 7 ] || {
    echo "SYNTAX: $0 <file> <bootfs image> <rootfs image> <bootfs size> <rootfs size> <u-boot image> [overlay size]"
    exit 1
}

OUTPUT="$1"
BOOTFS="$2"
ROOTFS="$3"
BOOTFSSIZE="$4"
ROOTFSSIZE="$5"
UBOOT="$6"
OVERLAYSIZE="$7"

head=4
sect=63

if [ -n "$OVERLAYSIZE" ] && [ "$OVERLAYSIZE" -gt 0 ] 2>/dev/null; then
    PTGEN_OUTPUT=$(ptgen -o "$OUTPUT" -h "$head" -s "$sect" -l 1024 \
        -t c  -p "${BOOTFSSIZE}M" \
        -t 83 -p "${ROOTFSSIZE}M" \
        -t 83 -p "${OVERLAYSIZE}M")
    set -- $PTGEN_OUTPUT

    BOOTOFFSET="$(($1 / 512))"
    ROOTFSOFFSET="$(($3 / 512))"
    ROOTFSSIZE_SECTORS="$(($4 / 512))"
    OVERLAYOFFSET="$(($5 / 512))"
    OVERLAYSIZE_SECTORS="$(($6 / 512))"

    truncate -s "$(( (OVERLAYOFFSET + OVERLAYSIZE_SECTORS) * 512 ))" "$OUTPUT"

    dd bs=1024 if="$UBOOT" of="$OUTPUT" seek=8 conv=notrunc
    dd bs=512 if="$BOOTFS" of="$OUTPUT" seek="$BOOTOFFSET" conv=notrunc
    dd bs=512 if="$ROOTFS" of="$OUTPUT" seek="$ROOTFSOFFSET" conv=notrunc,sync

    ROOTFSIMGSIZE="$((($(wc -c < "$ROOTFS") + 511) / 512))"
    ROOTFSPADDINGSIZE="$(($ROOTFSSIZE_SECTORS - $ROOTFSIMGSIZE))"
    ROOTFSPADDINGOFFSET="$(($ROOTFSOFFSET + $ROOTFSIMGSIZE))"
    if [ "$ROOTFSPADDINGSIZE" -gt 2048 ]; then
        ROOTFSPADDINGSIZE="2048"
    fi
    if [ "$ROOTFSPADDINGSIZE" -gt 0 ]; then
        dd bs=512 if=/dev/zero of="$OUTPUT" seek="$ROOTFSPADDINGOFFSET" count="$ROOTFSPADDINGSIZE" conv=notrunc
    fi

    echo "RESET000" | dd of="$OUTPUT" bs=512 seek="$OVERLAYOFFSET" conv=notrunc,sync count=1
else
    PTGEN_OUTPUT=$(ptgen -o "$OUTPUT" -h "$head" -s "$sect" -l 1024 \
        -t c -p "${BOOTFSSIZE}M" \
        -t 83 -p "${ROOTFSSIZE}M")
    set -- $PTGEN_OUTPUT

    BOOTOFFSET="$(($1 / 512))"
    ROOTFSOFFSET="$(($3 / 512))"

    dd bs=1024 if="$UBOOT" of="$OUTPUT" seek=8 conv=notrunc
    dd bs=512 if="$BOOTFS" of="$OUTPUT" seek="$BOOTOFFSET" conv=notrunc
    dd bs=512 if="$ROOTFS" of="$OUTPUT" seek="$ROOTFSOFFSET" conv=notrunc
fi
