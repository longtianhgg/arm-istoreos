include $(TOPDIR)/rules.mk

PKG_NAME:=king3288-openclash-core
PKG_VERSION:=1.19.31
PKG_RELEASE:=1

MIHOMO_FILE:=mihomo-linux-armv7-v$(PKG_VERSION).gz
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

# Mihomo is an already stripped static binary; keep upstream ELF unchanged.
RSTRIP:=:

define Download/mihomo-armv7
  FILE:=$(MIHOMO_FILE)
  URL:=https://github.com/MetaCubeX/mihomo/releases/download/v$(PKG_VERSION)/
  HASH:=a61115819d9ebd568788b0f1bddfa6c9c03458071abdbda80f79291cac0276e1
endef

$(eval $(call Download,mihomo-armv7))

define Package/king3288-openclash-core
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=Mihomo core for KING3288 OpenClash
  DEPENDS:=@TARGET_rockchip_armv7
endef

define Package/king3288-openclash-core/description
  Prebuilt Mihomo ARMv7 core for OpenClash on KING3288.
endef

define Build/Prepare
	rm -rf $(PKG_BUILD_DIR)
	mkdir -p $(PKG_BUILD_DIR)
	gzip -dc $(DL_DIR)/$(MIHOMO_FILE) > $(PKG_BUILD_DIR)/clash_meta
	chmod 0755 $(PKG_BUILD_DIR)/clash_meta
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/king3288-openclash-core/install
	$(INSTALL_DIR) $(1)/etc/openclash/core
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/clash_meta \
		$(1)/etc/openclash/core/clash_meta
endef

$(eval $(call BuildPackage,king3288-openclash-core))
