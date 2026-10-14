#
# Copyright (C) 2015-2016 OpenWrt.org
# Copyright (C) 2020 jjm2473@gmail.com
#
# This is free software, licensed under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk

PKG_ARCH_quickstart:=$(ARCH)

PKG_NAME:=quickstart
PKG_VERSION:=0.13.0
PKG_RELEASE:=1
PKG_SOURCE:=$(PKG_NAME)-binary-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/linkease/istore-packages/releases/download/prebuilt/
PKG_HASH:=40eeaba1fbb4cfb732cb5c4759103d9307cb46b83f98b4514934d3e13e8c945b

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-binary-$(PKG_VERSION)

PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=net
	CATEGORY:=Network
	SUBMENU:=Web Servers/Proxies
	TITLE:=Quickstart, the quick start.
	DEPENDS:=@(x86_64||aarch64||arm) +shadow-utils +shadow-useradd +mount-utils +block-mount +lsblk +e2fsprogs +parted \
		+smartmontools +smartd +smartmontools-drivedb +ip-full +ubus +uci +bash
	URL:=https://easepi.linkease.com/
endef

define Package/$(PKG_NAME)/description
  Quickstart is a dashboard & user guide
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/quickstart
endef

define Build/Configure
endef

define Build/Compile
endef

# KING3288: the main procd service was started and tested on real hardware.
# It can now auto-start at boot. Never package startdhns (uciChange),
# any automatic network UCI defaults, or network/block hotplug triggers.
define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin $(1)/etc/config $(1)/etc/init.d $(1)/usr/libexec/quickstart $(1)/usr/share/quickstart
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/quickstart.$(PKG_ARCH_quickstart) $(1)/usr/sbin/quickstart
	$(INSTALL_BIN) ./files/quickstart.init $(1)/etc/init.d/quickstart
	$(INSTALL_CONF) ./files/quickstart.config $(1)/etc/config/quickstart
	$(INSTALL_BIN) ./files/dhcpvalid.sh $(1)/usr/libexec/quickstart/dhcpvalid.sh
	$(INSTALL_DATA) ./files/manuf $(1)/usr/share/quickstart/manuf
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
