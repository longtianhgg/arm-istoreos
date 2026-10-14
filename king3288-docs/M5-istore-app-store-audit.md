# M5.2 KING3288 native iStore app store

## Verified running board, 2026-10-14
- iStoreOS 24.10.8 Linux 6.6.144 ARMv7 boots from existing SD p1 extlinux + p2 ext4. eMMC production Ubuntu and original U-Boot remain unmodified.
- Board LAN configured as DHCP client, lease 192.168.50.202, gateway/DNS 192.168.50.3. Own LAN DHCP and RA disabled.
- Installed 16 matching IPKs locally built by the same iStoreOS 24.10 branch/toolchain, including luci-app-store 0.2.1-r1, taskd 1.0.3-r2, luci-lib-taskd 1.0.26, luci-lib-xterm 4.18.0 plus transitive deps. User's opkg output shows configuring all packages without an error.
- User enabled/started /etc/init.d/tasks and restarted rpcd/uhttpd. Browser screenshot demonstrates iStore menu and /cgi-bin/luci/admin/store/pages/store working, catalog cards, categories, logos, installation buttons and v0.2.1-r1 version.
- Only UI/catalog loading and package installation were proven; no iStore application install/upgrade/remove yet. Store catalog visibility does not demonstrate usable KING3288/ARMv7 app repository or Docker compatibility.
- No changes to active board kernel, DTS, SD boot chain, MAC or existing working network.

## Actual source and reproducibility
- Store feed: feeds/store at a97ace34f2da358a015b094d326bba2697697f2e.
- feeds/store/luci/luci-app-store/Makefile version 0.2.1-r1 depends on curl/tar/libuci-lua/mount-utils/luci-lib-taskd; which selects luci-lib-xterm and taskd; taskd selects script-utils, coreutils-stty and procd.
- UI archive istore-ui-v0.2.0-2.tar.gz taken from the local verified reference source tree (same source hash 9aec741aa5675347bc5a818acb285901bddf309af8ae402dd898336751de38be).
- Native full make -j12 V=s succeeded M5_2_ISTORE_BUILD_RC=0; build_dir/king3288-m3/m5.2-istore-build.log. ARMv7 rootfs manifest grew from M5.1 138 packages to 154; rootfs.tar.gz gzip -t passed.
- Device-specific source change in target/linux/rockchip/image/armv7.mk: append luci-app-store to KING3288 DEVICE_PACKAGES. All actual dependencies are selected by Makefile/Kconfig.
- Reproduced by copying king3288-configs/m3-firstboot.diffconfig as clean .config and make defconfig: uhttpd, luci-mod-admin-full, luci-app-store, luci-lib-taskd, luci-lib-xterm, taskd, libuci-lua, script-utils all =y. Thus no hand-selected .config symbols are required beyond M3 baseline.
- New compiled rootfs is ONLY on lab-ubuntu; NOT redeployed to SD. Live SD already has online IPKs installed.

## QuickStart boundary (separate milestone)
- Current KING3288 iStoreOS source/feeds have no QuickStart package. A separate local reference iStoreOS tree has package/custom/{quickstart,luci-app-quickstart}; versions quickstart 0.13.0 and luci-app-quickstart 0.12.10-r1.
- Reference quickstart.arm in quickstart-binary-0.13.0.tar.gz: statically-linked 32-bit little-endian ARM EABI5 ELF. Actual target runtime unverified.
- Reference QuickStart requires mdadm (and many other packages), while current Linux 6.6.144 board final config has # CONFIG_MD is not set. Need avoid pulling MD RAID drivers just to display setup UI; audit needs to establish if dependency can be safely removed.
- Reference /etc/init.d/startdhns calls quickstart uciChange at startup and reload on network configuration changes. Never enable it unmodified on the current single-port DHCP-client board. QuickStart requires separate source review and explicit network-safety acceptance before live trial.
