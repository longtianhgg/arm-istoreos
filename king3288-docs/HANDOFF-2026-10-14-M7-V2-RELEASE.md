# KING3288 M7 v2 发行与下一阶段交接（2026-10-14）

> 此文档是当前最新 iStoreOS 增量；总基线仍为 Project 内更新后的 `KING3288_HANDOFF.md` 第 26 节。不要用旧第 25 节的 207 包、未制作整盘镜像等历史状态覆盖当前成果。

## 当前已验证实机状态
- 板：KING3288 RK3288 ARMv7 / 2GiB RAM / 8GiB 生产 eMMC / RTL8211E PHY@0 / UART2 115200。
- **插 SD**：原厂 U-Boot 2017.09 → SD IDB + FAT32 p1 (`KINGBOOT`) `/extlinux/extlinux.conf` → 原生 iStoreOS 24.10.8 自编 Linux 6.6.144 `zImage` + `rk3288-king3288.dtb` → SD ext4 p2 (`KINGROOT`)，`root=PARTUUID=4b328826-02`。M7 v1 完整镜像 2026-10-14 **全新 SD 冷启动已实机成功**。
- **无 SD**：生产 eMMC Ubuntu 20.04.3 / Linux 4.4.189 已在 2026-10-13 拔卡实机启动过；本轮不重测、不碰生产系统/U-Boot/Trust。
- M7 v1 刷到 SD16G，`--check` 验证 eMMC `mmcblk0` `/sys/.../type=MMC, removable=0`，SD `mmcblk1` `type=SD, removable=0`；`/dev/root` 为 SD p2 ext4。误把 `removable=1` 当安全条件导致原脚本拒绝，用户只删两行拦截后 `--check` 通过。
- 用户执行 `--apply` 仅写 SD p2 末端，已备份 SD 前 1MiB 与分区表。MBR p2 保持起始 LBA **2129920**，从 4194304 sectors 伸至 29351936 sectors、结束 LBA **31481855**；重启后 S98 一次性服务自动 `resize2fs`，日志 `resized filesystem to 3668992`，`/etc/king3288-rootfs-expand.done` 存在，`df -h /` **13.7GiB，总可用 13.3GiB**，`--check` 显示 `unallocated after p2=0 MiB` + `Already successfully completed`；**实机验收通过，无需手动 --finish，不再重复 --apply**。
- 新 SD 默认 LAN DHCP 客户端、本机 DHCPv4/DHCPv6/RA 关闭；用户最后明确**网络没有问题**。不要重新修改网络配置。
- v1 初始 iStoreOS 会通过 `port_mount=1` 自动以 rw 挂载生产 eMMC p8 (`/mnt/mmc0-8`)，用户已在线设置 `fstab.emmc_protect=mount`, `uuid=3d6b8cf4-922e-473b-bab1-bbdf3d8ad659`, `enabled=0`，卸载并重启。实机日志确认规则保存，`block info` 仅有 UUID、TYPE 而无 MOUNT，`mount` 无 eMMC 挂载，仅有 SD p2 在 `/` 与 `/opt/docker`；**重启验证成功**。
- 实机上 MAC **跨启动随机变化**：首轮如 `a6:45:fa:43:01:1e`，最终日志 `1a:bd:16:0c:cb:4b`，仍待新会话专门定位/固定。不要继承 Ubuntu Linux4.4 TX checksum off 缺陷为 Linux6.6 已有问题；当前网络反馈正常。M8 的网络稳定性、吞吐和长时负载待验。Docker/OpenClash/Tailscale 等有包不代表每项业务已板测通过。

## 本轮完成：两项源码修复与 v2 完整镜像
- Git branch `king3288-istoreos-24.10`，此前提交 `87d3c7318f`：`king3288-tools/king3288-expand-rootfs.sh` 已移除对 MMC `removable=1` 的依赖，但保留 DT model=KING3288、`device/type=SD`、根 PARTUUID、p1=vfat/p2=ext4、MBR 双分区及几何校验，严禁误写 eMMC。
- 新源码 `target/linux/rockchip/armv7/base-files/etc/uci-defaults/10-king3288-protect-emmc`，用户实机同款 UUID 的 UCI `fstab.emmc_protect` disabled 规则。实际源码顺序：`09_istoreos` 用 `blockmount.sh detect` 建 fstab → `/etc/init.d/boot` **START=10** 执行 `uci-defaults/10-...` → `/etc/init.d/blockmount` **START=11** 才 port auto-mount。首启保护设计仅执行一次，不修改用户后来配置，不禁止 USB `port_mount`。**v2 全新 SD 首启保护实际效果尚待一张新卡测试**。
- `king3288-tools/build-king3288-sd-image.sh` 已改为在 fakeroot 下将 eMMC 保护首启脚本直接装入 M7 根分区，也同时集成最新扩容脚本及一次性 S98 收尾服务；保持独立 v2 文件名，**没有覆盖 v1**，不需要重编译未变更的 296 包 OpenWrt 包集。
- 新文件：`bin/targets/rockchip/armv7/istoreos-rockchip-armv7-king3288-sdcard-3g-v2.img` (3,238,002,688 bytes)，同目录 `.img.gz`（约 173MiB）和 `.img.gz.sha256`。
- v2 `.img.gz` SHA256：`aa32f622a3e0f2ff2646861314a3ff676a371c0d493540026d3bfa3bd06c9836`；原始 v2 img SHA256 `9fa37f13cdf150fd9bd1b72cfb00d3cb9c8eccfa65dd5043d100b57e6a555cb0`。
- 根分区和分区表仍 p1 起始 LBA32768/2097152 sectors、p2 起始 LBA2129920/4194304 sectors、MBR disk ID 0x4b328826，extlinux 根 PARTUUID=4b328826-02，原 SD IDB/miniloader blob SHA256 `84c08dd9...` 不变。
- v2 `M7_V2_BUILD_RC=0`；测试 `/tmp/king3288-m7-v2-validate.log` 与 `/tmp/king3288-m7-v2-validate.rc` 返回 0 / `V2_FULL_DISK_OFFLINE_VALIDATION_OK`：MBR、IDB、FAT 实际读回 zImage+DTB+extlinux 均一致，p2 全 2GiB 与 root.ext4 逐字节相同、e2fsck clean、debugfs 直接读取新首启脚本与新 expand script 并确认旧 removable 报错不存在、09_istoreos 在前和 S10/S11 源码顺序正确，gzip -t、SHA256 OK。**尚未将 v2 实机刷卡检验；此限制必须保留**。
- 原有 v1 已板测镜像保留：`...-sdcard-3g.img.gz` SHA256 `5ffc5d0a0b722ff60f29386093a79cad19de33859e815e69deed4ae7fe5a61bd`。v1 首启旧脚本需要手动删掉 removable 检查、手动加入 fstab 保护；而用户当前运行的 SD 已完成这两项修复，不需要重新刷机。

## 下次会话目标与限制
- **仅讨论网络稳定性与 MAC 固定/来源**，其余 M7 已完成工作不要重做；首先只读核对 `ethtool -i/-k eth0`、`ethtool eth0`、`ip -br addr`、`cat /sys/class/net/eth0/address`、`dmesg|grep -i mac`、`logread`、UCI 网络实际配置、DTS/driver 核心代码，具体要求用户定一个里程碑后做单点修改。
- 不重配现有网关、IP 或 DNS；不因历史 Linux4.4 TCP checksum  bug 而擅自关闭 Linux6.6 offload；不改冻结 DTS GMAC delay/PHY、U-Boot/eMMC 或 SD extlinux。用户原有未跟踪 Plan.md、M2 logs、NetWizard/Partexp 不动。
- 如需将 v2 刷到新 SD 测试，先备份正在使用的已扩容 SD；Windows 可从 `dragon@192.168.50.25` 的上述产物目录获取 `.img.gz`，使用新空白 SD，勿写入 eMMC。首次检查 `/usr/sbin/king3288-expand-rootfs --check` 确认 `type=SD`、`root=PARTUUID`，再单独 `--apply` 并重启；首启同时检查 `uci show fstab.emmc_protect` 与 `mount|grep mmcblk`，确认 eMMC 未自动挂载。
