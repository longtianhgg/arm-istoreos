# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk

BOARD:=rockchip
BOARDNAME:=Rockchip
FEATURES:=ext4 audio usb usbgadget display gpio fpu pci pcie rootfs-part boot-part squashfs
SUBTARGETS:=armv8 armv7

KERNEL_PATCHVER:=6.6

define Target/Description
	Build firmware image for Rockchip SoC devices.
endef

include $(INCLUDE_DIR)/target.mk

DEFAULT_PACKAGES += uboot-envtools partx-utils e2fsprogs mkf2fs kmod-gpio-button-hotplug ethtool

ifeq ($(SUBTARGET),armv7)
# Complete Linux 6.6 Kconfig non-interactively for the new 32-bit subtarget.
define Kernel/Configure
	$(call Kernel/Configure/Default)
	$(KERNEL_MAKE) olddefconfig
endef
endif

$(eval $(call BuildTarget))
