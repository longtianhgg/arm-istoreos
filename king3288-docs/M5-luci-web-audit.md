# M5.1 KING3288 LuCI Web: live validation and reproducible build

## Verified on board (2026-10-14)
- Runtime: iStoreOS 24.10.8, Linux 6.6.144, KING3288, original vendor U-Boot → SD p1 extlinux → SD p2 ext4.
- Board LAN: DHCP lease 192.168.50.202/24; user-set gateway and DNS 192.168.50.3. Running system remains SD; vendor eMMC is excluded from automatic mounting.
- Original rootfs contained luci-base, Argon and rpcd but lacked uhttpd and main LuCI menu modules. Browser showed LuCI's own 404 after adding only uhttpd and uhttpd-mod-ubus.
- User installed matching ARMv7 ipks online: uhttpd, uhttpd-mod-ubus, libiwinfo-data, libiwinfo20230701, rpcd-mod-iwinfo, luci-mod-status, luci-mod-system, luci-mod-network, luci-mod-admin-full, luci-app-firewall. opkg configuration of all eight later packages succeeded.
- After restarting rpcd/uhttpd and clearing /tmp/luci-indexcache*, user's screenshot shows Argon/iStoreOS system overview under /cgi-bin/luci/admin/status/overview and navigation for Status, System, Network. Model KING3288, rockchip/armv7, kernel 6.6.144 and memory are displayed.
- curl -I /cgi-bin/luci/ returned HTTP 403 with x-luci-login-required: yes: expected unauthenticated LuCI response, not a 404 failure.
- This verifies the Web UI's launch and overview only; not all individual settings pages, configuration persistence, iStore application store or QuickStart.

## Source changes and reproducible results
- target/linux/rockchip/image/armv7.mk Device/king3288 DEVICE_PACKAGES += uhttpd uhttpd-mod-ubus luci-mod-admin-full luci-app-firewall.
- The other six online-installed packages are selected through actual Makefile dependencies; the new image also picks luci-i18n-firewall-zh-cn as a default. Existing luci-base, Argon and base language packages are retained.
- make defconfig selected CONFIG_PACKAGE_{uhttpd,uhttpd-mod-ubus,luci-mod-admin-full,luci-mod-network,luci-mod-status,luci-mod-system,luci-app-firewall,libiwinfo,rpcd-mod-iwinfo}=y.
- king3288-configs/m5-luci-web.diffconfig is the reproducible Kconfig snapshot. Its text matches m3-firstboot.diffconfig because the new Web packages are DEVICE_PACKAGES defaults of the selected KING3288 device, not explicit diffconfig overrides.
- Native full make -j12 V=s: M5_WEB_BUILD_RC=0, log build_dir/king3288-m3/m5-web-fullbuild.log. New bin/targets/rockchip/armv7/istoreos-rockchip-armv7-king3288.manifest has 138 packages versus M3's 127; all ten live-installed Web packages are present. New rootfs.tar.gz gzip -t passed and root-rockchip contains uhttpd service/binary plus required LuCI menu JSON files.
- Current SD and eMMC were NOT written during this source/build milestone. The existing M3 SD files bundle is retained separately. The new build output under bin/targets is not yet flashed or boot-tested. No changes to kernel, DTS, U-Boot, networking or rootfs partition layout.
- M5 next independent milestone: iStore and QuickStart. M8: deferred network stress/stability tests at user's request.
