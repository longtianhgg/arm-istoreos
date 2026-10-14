# SPDX-License-Identifier: GPL-2.0-only
# KING3288 ARMv7 device registration and proven minimal default userspace.
# SD/extlinux boot deployment remains manual; no full SD/sysupgrade image yet.

define Device/king3288
  DEVICE_VENDOR := KING
  DEVICE_MODEL := KING3288
  DEVICE_DTS := rockchip/rk3288-king3288
  KERNEL := kernel-bin
  KERNEL_NAME := zImage
  FILESYSTEMS := ext4
  # M5: LuCI/Argon Web UI, validated on KING3288 SD rootfs.
  # luci-mod-admin-full selects status/system/network and iwinfo dependencies.
  DEVICE_PACKAGES += uhttpd uhttpd-mod-ubus luci-mod-admin-full luci-app-firewall luci-app-store
  IMAGES :=
endef
TARGET_DEVICES += king3288
