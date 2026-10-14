# KING3288 原生 iStoreOS — M6 Docker 可选软件包交接（2026-10-14）

## 工程与安全基线
- 项目总基线：KING3288_HANDOFF.md 第25节；iStoreOS ARMv7 适配摘要 KING3288_OPENWRT_ADAPTATION_HANDOFF.md 第11节；工程根目录 Plan.md M6。
- 开始于 Git `cd09b6cdf2`（M6 Tailscale 完成）；仓库 `/home/dragon/king3288-build/king3288-istoreos`，分支 `king3288-istoreos-24.10`；iStoreOS 24.10.8 / Linux 6.6.144 / musl ARMv7 / OPKG。
- 当前板端仍是原有 M3 SD rootfs + M5 在线安装包；静态 LAN `192.168.50.202/24`，网关/DNS `192.168.50.3`，DHCP 禁用。**本轮仅主机配置和编译；未刷 SD、未启动 Docker、不写 eMMC/U-Boot/Trust、不改变运行中网络。**
- 用户不要求完整 NAS/Btrfs/RAID，SD p2 ext4 安全扩容留待其他软件包适配后，届时参考用户提供的 Orange Pi 脚本。

## 完成：源码、Kconfig、IPK、rootfs 离线验证
- 当前源码实际版本：Docker CLI/dockerd 27.3.1、containerd 1.7.22、runc 1.1.14、Compose 2.39.1、tini 0.19.0、Dockerman 0.5.13.20250109。
- **仅编译可选 IPK**：`.config` 里基础安装包 `CONFIG_PACKAGE_*=y` 仍为 270 项不变；新增 36 项 `CONFIG_PACKAGE_*=m`（Docker 生态、Dockerman/中文包、ttyd、iptables-nft、依赖库、网络 kmod）。
- 原 `feeds/packages/utils/containerd/Makefile` 的 `+btrfs-progs` 导致联动选中 `kmod-fs-btrfs`，与用户目标不符。已在此 feed 文件中将条件依赖更改为 `+!TARGET_rockchip_armv7:btrfs-progs`，使 KING3288 无 Btrfs 依赖，而其他 targets 保留原依赖。
- 外部 feeds/packages 仓库不在主工程 Git 历史内，**绝不能仅依赖该 feed 的工作区改动**。已将可复用补丁保存到本工程受 Git 跟踪的 `king3288-patches/m6-containerd-armv7-no-btrfs.patch`。当前 feed 工作区已应用；若未来清理/重检 feeds，在主工程根目录重新应用：
  `git -C feeds/packages apply "$(pwd)/king3288-patches/m6-containerd-armv7-no-btrfs.patch"`
  对已打补丁的工作区不得重复应用。此前已通过 `git -C feeds/packages apply --reverse --check` 核验补丁一致性。
- Linux 6.6.144 构建产物内核配置 `CONFIG_VETH=m`、`CONFIG_BRIDGE_NETFILTER=m`、`CONFIG_IP_VS=m`、`CONFIG_OVERLAY_FS=y`；`kmod-veth`、`kmod-br-netfilter`、`kmod-nf-ipvs` ARMv7 IPK 已生成。Btrfs/RAID 内核模块及 mdadm 没有选中。
- 完整编译 `make -j4` → `build_dir/king3288-m6-docker/fullbuild.rc` 为 `M6_DOCKER_FULL_BUILD_RC=0`。**11 个关键 IPK**（Docker CLI/dockerd/containerd/runc/tini/Compose/Dockerman/luci-lib-docker/kmod-veth/kmod-br-netfilter/kmod-nf-ipvs）逐一确认存在。
- 从实际 IPK 的 `data.tar.gz` 内提取 ELF 头，已确认 docker、dockerd、containerd、runc、docker-compose 五个真实程序都是 **ELF32 little-endian ARM (EM_ARM=40)**。验证脚本 `/tmp/king3288-m6-docker-elf-audit.py`。
- 完成 rootfs 检查：manifest **255包**，与 M6 Tailscale 完成时的包名集合一致；无 Docker Engine、containerd、Compose、Dockerman、Btrfs 被默认安装，`etc/init.d/dockerd`、`etc/rc.d/S99dockerd` 和 Docker UCI 默认网络/防火墙脚本均不存在于基础 rootfs。QuickStart `S92`、OpenClash/Mihomo、Tailscale 及其首次禁自启规则仍在。
- 新生成 rootfs `bin/targets/rockchip/armv7/istoreos-rockchip-armv7-king3288-rootfs.tar.gz`，SHA256 `a446a1053835c24b253dbfaabbe69944435335f958e0dc134fb74d295bb87823`，`gzip -t` 通过（因为内核模块/Kconfig构建变化，hash 不同于上轮）。
- 可复现配置：`king3288-configs/m6-docker-optional.diffconfig`；构建日志和前后配置保留于 `build_dir/king3288-m6-docker/`。审计：`/tmp/king3288-m6-docker-optional-validate.log`、`/tmp/king3288-m6-docker-elf-audit.log`。

## 尚未实机确认 / 安装边界
- **没有在 KING3288 板端安装/运行 Docker，也没有验证容器启动、overlay2、cgroup、docker0/iptables、Dockerman Web 管理功能。** 软件包编译成功 ≠ 实机 Docker 功能完成。
- 当前 dockerd 上游 IPK 的 `postinst` 在在线安装时会执行 `/etc/init.d/dockerd enable`、`uciadd`、`start`，且包含 Docker/firewall UCI 默认脚本。**不可不经审查直接在运行中的 192.168.50.202 旁路由上在线安装这些 IPK**，否则可能改变网络/防火墙。后续单独提供可回退的安全安装/实机验证方案。
- 当前 2GiB RAM 适合小规模容器，不默认启多个资源密集型容器；Docker 数据盘暂定 SD p2 ext4 上 `/opt/docker`，SD 扩容最后再处理。
- 未处理的 M6 网络监控、备份、其他硬件和软件包按 Plan.md 继续；M7 SD 镜像和安全扩容、M8 重启持久性与 24–48h 稳定性均按用户要求后置。不要重复 M1～M5 和 OpenClash/Tailscale 已验证的编译工作。
