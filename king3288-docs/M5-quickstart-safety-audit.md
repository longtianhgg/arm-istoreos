# M5.3 QuickStart safe ARMv7 adapter — staged and runtime audit (2026-10-14)

> Read the latest **M5.3 finalization** section at the bottom for the current verified status. Earlier sections preserve the deliberately cautious pre-runtime build-stage record.

## Baselines (do not change)
- KING3288 iStoreOS 24.10.8 / Linux 6.6.144 boots via original U-Boot → SD p1 extlinux → SD p2 ext4. eMMC hosts production Ubuntu, and must remain untouched.
- Active board is single eth0→br-lan, LAN is DHCP client (historically 192.168.50.202), with custom default gateway and DNS 192.168.50.3, no DHCP/RA server. The board's latest boot enumerated the SD as mmcblk0 and eMMC as mmcblk1; always trust UUID/PARTUUID, not mmcblk numbering.
- Current accepted iStore store and LuCI GUI already work. Network and rootfs stress testing is deferred at user's request.

## Actual local reference (source read, copied cleanly)
- Reference: /data/openwrt-build/istoreos/package/custom/quickstart and /data/openwrt-build/istoreos/package/custom/luci-app-quickstart, clean according to git status of those paths.
- Versions: quickstart 0.13.0, luci-app-quickstart 0.12.10-r1. Reference arm binary is statically linked, ELF32 LSB EABI5; architecture execution on this board pending verification.
- Cached file quickstart-binary-0.13.0.tar.gz source SHA256: 40eeaba1fbb4cfb732cb5c4759103d9307cb46b83f98b4514934d3e13e8c945b.
- The actual original QuickStart DEPENDS includes mdadm. Current Linux 6.6.144 has # CONFIG_MD is not set. mdadm depends on kmod-md-mod and RAID level modules. This adapter removes only mdadm dependency, deliberately leaving RAID unsupported.
- The actual original /etc/init.d/startdhns calls quickstart uciChange on service start and on network reload; /etc/hotplug.d/iface/21-startdhns calls ifaceEvent on interface changes. The binary contains UCI commands and explicit network/dhcp changes, so runtime actions need controlled tests.

## KING3288 first-stage modifications
- Package paths: package/custom/{quickstart,luci-app-quickstart}.
- quickstart/Makefile excludes mdadm; package install installs only the prebuilt ARM executable, /etc/config/quickstart and data plus a STAGED /usr/libexec/quickstart/quickstart.init script.
- NO /etc/init.d/quickstart, /etc/init.d/startdhns, /etc/hotplug.d/{block,iface} trigger, or /etc/uci-defaults/09-quickstart are included in the QuickStart IPK. OpenWrt default_postinst automatically STARTS /etc/init.d scripts when installed, hence staging the primary service instead of installing it directly under /etc/init.d is intentional.
- Package's original postinst auto logic was removed. luci-app-quickstart/root/etc/uci-defaults/50_luci-quickstart only clears temporary LuCI menu caches (confirmed by source).
- LuCI module preserves user-triggered network guide and interface configuration endpoints; only the RAID menu entry is removed.
- The opaque prebuilt backend itself may still change config when triggered through its Web API. Until explicitly verified on board, no guarantee is made that every GUI action is read-only. Do NOT click Save/Apply, auto setup, RAID or storage-related actions before controlled acceptance testing.
- Online install should first back up /etc/config/{network,dhcp,firewall,fstab} to the SD rootfs and verify their checksums, then install IPKs, verify no auto-service and compare network config, and only then manually start the staged main service via serial. No live SD writes or system network changes were performed from lab-ubuntu in this source-stage work.
- Final integration in Device/king3288 DEVICE_PACKAGES is withheld until successful running-board live test, consistent with prior M5 LuCI and iStore milestones.

## Milestone acceptance
1. make defconfig with CONFIG_PACKAGE_luci-app-quickstart=y resolves quickstart=y, mdadm remains NOT selected.
2. Native ARMv7 IPKs build successfully with exactly matching sources; examine controls and data payload, ensure no auto-activation targets and confirm manual network routes still present.
3. Install on KING3288 via serial only with explicit network backups, verify network files unchanged and no new DHCP servers or unwanted eMMC mounts; start only the main service manually.
4. User screenshot should show QuickStart/NetworkGuide pages. Manual network edits only later in a separate carefully recoverable UART-guided step.

## Offline build and package inspection results
- Both matching ARMv7 builds passed: QUICKSTART_PKG_RC=0, LUCI_QUICKSTART_PKG_RC=0.
- Produced quickstart_0.13.0-r1_arm_cortex-a15_neon-vfpv4.ipk and luci-app-quickstart_0.12.10-r1_all.ipk, plus the Chinese translation.
- Verified quickstart IPK control Depends contains no mdadm; data payload contains ONLY /etc/config/quickstart, /usr/sbin/quickstart, /usr/libexec/quickstart/{quickstart.init,dhcpvalid.sh}, and /usr/share/quickstart/manuf; no init.d, uci-defaults, block/iface hotplug. Verified LuCI UCI default only removes temporary LuCI menu cache.
- As an extra guard, removed the four unused auto-trigger script files from the custom source tree (startdhns.init, startdhns.hotplug, quickstart.uci-default, quickstart.hotplug), so they cannot accidentally be added back with a generic copy rule.
- Staged exactly 53 new IPKs (8.3 MiB) and checked them against the previous iStore 154-package manifest: UNMET_DEPS=[], FORBIDDEN_PAYLOADS=[], RESULT PASS. Installer script separately validates model, PARTUUID, LAN, DHCP server, gateway, DNS; backs up /etc/config/{network,dhcp,firewall,fstab}, and compares after installation. Installer intentionally does not start QuickStart.
- LAN HTTP package: http://192.168.50.25:8765/m5-quickstart-armv7.tar.gz, SHA256 bb9b974560994eea287016be845944c602be3d2f9f759a4b940f7566ebd6960f, 8562925 bytes. A separate board-side installation output and UI screenshot are REQUIRED before marking M5.3 runtime acceptance.
- Restored .config to the pre-QuickStart M5.2 baseline and passed make defconfig; both CONFIG_PACKAGE_quickstart and CONFIG_PACKAGE_luci-app-quickstart are NOT selected in the persistent build config. Do not add either to Device/king3288 DEVICE_PACKAGES before live verification.

## M5.3 finalization — verified on board (2026-10-14)
- User installed the 53 prebuilt matching IPKs with install-safe.sh; backup created at /root/king3288-quickstart-backup-20261014-132429 on SD. Installer ended M5_QUICKSTART_INSTALL_OK, tested four original config files unchanged and showed default route via 192.168.50.3 dev br-lan, IP 192.168.50.202.
- User manually copied staged quickstart.init to /etc/init.d/quickstart and started service. ps showed /usr/sbin/quickstart serve --unix /var/run/quickstart/local.sock; socket existed; 127.0.0.1:3038 listening. Immediately after service start, cmp of /etc/config/{network,dhcp,firewall,fstab} to backup returned OK for all four; default route still via 192.168.50.3.
- User screenshots verify network wizard loads three options (broadband, existing router, side router) and QuickStart home shows network rates, online devices, IP/DNS and port state. User confirmed manually setting up bypass-router networking THROUGH the network wizard worked.
- Latest screenshot labeled IPv4 network type as static network, LAN IP 192.168.50.202 and DNS 192.168.50.3. This is user-chosen config after running the wizard; DO NOT restore old DHCP client config automatically or compare network config to the now-outdated pre-wizard backup.
- These results justify normal automatic startup of the main QuickStart procd service ONLY. No automatic startdhns/uciChange or iface/block hotplug scripts are reintroduced. A future full reboot, persistence and every QuickStart feature remain separately unverified.
- Updated quickstart/Makefile to install existing proven quickstart.init into /etc/init.d/quickstart (START=92, procd); updated Device/king3288 DEVICE_PACKAGES to add luci-app-quickstart, which selects quickstart and runtime deps automatically.
- Clean .config regenerated starting from king3288-configs/m3-firstboot.diffconfig: make defconfig selected CONFIG_PACKAGE_{luci-app-quickstart,quickstart,luci-i18n-quickstart-zh-cn,ip-full,smartmontools,shadow-utils}=y and left CONFIG_PACKAGE_{mdadm,kmod-md-mod} unselected.
- Fresh full native build RC=0 (build_dir/king3288-m5-quickstart/m5-final-fullbuild.log), manifest 207 packages including iStore, LuCI, QuickStart and Chinese translation; rootfs tar.gz gzip -t OK. Rootfs has /etc/init.d/quickstart and /etc/rc.d/S92quickstart; there are no startdhns, iface/block auto triggers, or 09-quickstart UCI defaults. Build output is lab-ubuntu only, not flashed. U-Boot, eMMC, board kernel and DTS unchanged.
- Runtime follow-up: enable /etc/init.d/quickstart on existing SD and verify network manually after the wizard. Do not run any scripts that enforce original DHCP-client proto; obey current user configuration. Defer reboot/stress to comprehensive final acceptance if user prefers.
