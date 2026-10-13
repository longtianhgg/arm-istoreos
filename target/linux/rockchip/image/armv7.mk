# SPDX-License-Identifier: GPL-2.0-only
# M1: register KING3288 only; M2/M3 will supply kernel, DTB and rootfs.
# No installable SD or sysupgrade image is produced at this milestone.

define Device/king3288
  DEVICE_VENDOR := KING
  DEVICE_MODEL := KING3288
  DEVICE_DTS := rockchip/rk3288-king3288
  KERNEL := kernel-bin
  KERNEL_NAME := zImage
  FILESYSTEMS := ext4
  IMAGES :=
endef
TARGET_DEVICES += king3288
