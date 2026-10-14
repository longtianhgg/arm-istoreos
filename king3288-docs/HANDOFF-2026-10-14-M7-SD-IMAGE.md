# KING3288 原生 iStoreOS M7 完整 SD 镜像制作交接（2026-10-14）

## 仍需遵循的总基线
- 总基线：Project `KING3288_HANDOFF.md` §25；KING3288 OpenWrt / iStoreOS 子基线与本项目 M6 各交接文档。
- 本次任务是用户明确要求“将最新的镜像准备好并将扩容脚本内置其中”，因此在构建机上组装完整可刷写 SD 镜像；未写 eMMC、原厂 U-Boot、Trust，也未修改正在运行的 SD 卡及其静态旁路由网络。
- 编译源码 `/home/dragon/king3288-build/king3288-istoreos`，branch `king3288-istoreos-24.10`，接续 Git `4140a6e930`；iStoreOS 24.10.8 / Linux 6.6.144 / ARMv7 hardfloat musl OPKG，M6 296 实际包最终 rootfs，整包编译已通过。
- 生产 eMMC Ubuntu Linux 4.4 和工厂 U-Boot 不动，插 SD 优先 SD p1 extlinux → iStoreOS SD p2 ext4 rootfs，无卡回退原 eMMC。

## 已制作并通过离线验证的实际产物
- `bin/targets/rockchip/armv7/istoreos-rockchip-armv7-king3288-sdcard-3g.img`，实际字节数 **3,238,002,688**（约 3.02 GiB）。
- 同目录 `istoreos-rockchip-armv7-king3288-sdcard-3g.img.gz`，约 **173 MiB**，SHA256 **`5ffc5d0a0b722ff60f29386093a79cad19de33859e815e69deed4ae7fe5a61bd`**。原始 .img SHA256 `bd237f1bc2344b83b809dff7aaafd79bc9d78ded3ff89949b99ff8b24d18f211`。
- 同目录 `README-KING3288-SD-IMAGE.md`、`*.img.gz.sha256`；构建及测试日志 `build_dir/king3288-m7-sd-image-build.{log,rc}`、`/tmp/king3288-m7-validate-full-image.log`。
- 主机源构建脚本：`king3288-tools/build-king3288-sd-image.sh`。只对**普通文件**调用 truncate/mkfs/mcopy/sfdisk/dd/fakeroot/pigz，绝不直接写真实的块设备；可以按相同基线重新生成镜像，但 SHA256 不承诺重建时 bit-for-bit 相同。
- 使用已实机验证的 `/home/dragon/king3288-build/images/king3288-ubuntu20.04.3-linux4.4.189-hid-hdmi-sd7g-idb-modulesfix-rootfix.img` **前 16 MiB 引导前缀**，只在新普通镜像文件中重写 MBR 的分区大小，LBA64 起连续 206 扇区的 Rockchip IDB 与已验证 blob 完全匹配，SHA256 `84c08dd990738c1e935f86206a062aa75effc1148039328b5aa1722db818f8e3`。
- MBR disk ID `0x4b328826`，对应 p2 `PARTUUID=4b328826-02`：p1 起始 LBA32768，2097152 sectors=1024MiB，类型 FAT32 LBA，卷名 KINGBOOT；p2 起始 LBA2129920，4194304 sectors=2048MiB，类型 Linux，ext4 卷名 KINGROOT、UUID `52b116ba-1676-4cb6-a20e-9e80e340cf65`。无第三分区。
- FAT p1 含 `/extlinux/extlinux.conf`、`/zImage`、`/rk3288-king3288.dtb`。extlinux: `APPEND console=ttyS2,115200n8 earlycon root=PARTUUID=4b328826-02 rootfstype=ext4 rootwait rw init=/sbin/init`。
- 内核 zImage `SHA256 99318e0bfdc264eabfe7f49a3267b61100bdcd7246a7bd60b44c1cf7206d3e2e`；DTB `SHA256 0b2506ab2ef0b7404e4305e89743213825b3a3bb7ee067af029d67571389b0eb`，来自已构建 Linux 6.6.144 ARMv7 target；不是历史 Linux 4.4/6.12 文件。
- ext4 p2 通过单个 fakeroot 会话从最新 `...rootfs.tar.gz` 解包并以 `mke2fs -d` 创建，保留 UIDs/GIDs，`debugfs` 验证 `/etc/shadow` 与嵌入扩容工具都属于 UID/GID 0；`e2fsck -fn` 返回 0，文件系统 clean。
- 仅生成镜像时向 ext4 增加 `/usr/sbin/king3288-expand-rootfs`（M7 已提交并语法检查的 SD-only 脚本）、`/etc/init.d/king3288-rootfs-resize`（下次启动自动完成 resize2fs 的模板）及 `/root/README-KING3288-SD-EXPAND.txt`。
- **不自动写分区表**：新刷 SD 首启后需用户显式 `--check` 然后 `--apply`。脚本只允许被识别为真正 SD 的 p2（`/proc/cmdline PARTUUID` + sysfs MMC type=SD/removable=1），严格拒绝 eMMC；备份 SD 前 1MiB 再 `parted resizepart 2 100%`；`--apply` 启用 S98 一次性重启任务；下次重启后运行 `resize2fs` 并成功自禁用。需新 SD 板端真实验收。
- 最新根文件系统保留 Docker/Compose/Dockerman、OpenClash/Mihomo、Tailscale、QuickStart、ttyd/关机页面、iStore 等 296 包；新刷后板级默认 LAN=DHCP 客户端、DHCP server 关闭，后续用户手动静态设置不会被首启脚本反复重写。

## 实际离线校验证据
- `M7_HOST_IMAGE_BUILD_RC=0`，`M7_COMPLETE_SD_IMAGE_OFFLINE_VALIDATION_OK`，`M7_FINAL_IMAGE_VALIDATION_RC=0`。
- 将 MBR 作为结构化 4 主分区表解析，验证磁盘 ID、p1 和 p2 的精确 LBA/大小，两个空分区项；读回 IDB 的 SHA256 匹配旧已启动 SD。
- **从完整 .img 的 p1 FAT32 内重新抽取** zImage/DTB/extlinux，并与源码编译产物用 `cmp` 逐字节比较。
- **完整 .img 的 p2 全部 2 GiB 内容**与 `root.ext4` 逐字节比较；`e2fsck -fn` 成功；压缩镜像 `gzip -t` 成功，SHA256 已记录。
- 完整镜像尚未实机新卡冷启动测试、DHCP 分配、eMMC 回退、首次 p2 扩容和重启后 `resize2fs` 真实验收。不要把离线验证夸大为实机成功。

## 用户刷写和扩容
- 在 Windows 可通过 `scp dragon@192.168.50.25:/home/dragon/king3288-build/king3288-istoreos/bin/targets/rockchip/armv7/istoreos-rockchip-armv7-king3288-sdcard-3g.img.gz .` 拉取文件，balenaEtcher 直接选择压缩镜像和**专用新 SD**，推荐至少 8 GiB（用于 Docker）。
- 启动后先在主路由 DHCP 列表查 IP，登录该新镜像，执行：
  ```sh
  /usr/sbin/king3288-expand-rootfs --check
  /usr/sbin/king3288-expand-rootfs --apply
  reboot
  df -h /
  /usr/sbin/king3288-expand-rootfs --check
  ```
- 用户首次尝试应贴 **--check** 完整输出确认：SD 型、分区、ext4、PARTUUID、p1；若守卫提示 removable/type 未达预期，应基于实机输出审查安全策略，而不是强行绕过；首次刷卡不要同时写其它块设备。

## 不变与后续
- 不改原厂 U-Boot/Trust/eMMC、M5 正在运行 SD 静态 IP 192.168.50.202、网关/DNS 192.168.50.3、DHCP 关闭；用户的 `Plan.md` 和旧日志及尚未跟踪的 NetWizard/Partexp 保留不触动。
- M7 整盘 SD 镜像**主机制作和离线检查已完成**；新 SD 首次实机冷启动 + 读取 `--check` 输出才是下一个验收点。M8 长时间稳定性按用户指示后置。
