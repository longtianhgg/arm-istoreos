# KING3288 原生 iStoreOS M6：Docker 默认内置 + 新刷 SD 首启 DHCP Client（2026-10-14）

## 依据、任务和现状
- Project 统一基线：`KING3288_HANDOFF.md` §25、`KING3288_OPENWRT_ADAPTATION_HANDOFF.md` §11；承接 M6 Docker 可选包提交 `e7c9fa715c`。
- 开发源码 `/home/dragon/king3288-build/king3288-istoreos`；branch `king3288-istoreos-24.10`，iStoreOS 24.10.8 / Linux 6.6.144 / ARMv7 musl OPKG。
- 用户更新的**新刷镜像**要求：开机 LAN 通过主路由 DHCP 自动取地址、设备自身 DHCP 服务关闭；用户之后通过 QuickStart 手动改成静态旁路由后不允许后续每次重启重置。用户允许 Docker 适度调整防火墙/网络，不要求完全禁用其启动脚本。
- **当前在用 SD** 仍为 M3 rootfs + 之后在线 M5 安装包，静态 `192.168.50.202/24`、网关/DNS `192.168.50.3`、本机 DHCP 关闭，未改动或刷写；原厂 U-Boot、Trust、生产 eMMC 不动。M7 首次 SD p2 扩容继续延后，届时参考用户 Orange Pi 脚本。

## 本轮构建机已验证
- 从 Zero3 对照确认为 Docker CLI、dockerd、containerd、runc、tini、docker-compose、luci-app-dockerman 及中文包、luci-lib-docker、ttyd 均已有 ARMv7 IPK，但此前选中为 `=m`，因此原 255 包新 rootfs **没有内置 Docker**。
- 本轮将这些包和必需网络模块 `kmod-veth`、`kmod-br-netfilter`、`kmod-nf-ipvs` 从 `=m` 改为 `=y`。实际 `make defconfig`：`CONFIG_PACKAGE_*=y` 从 270 增至 **306 项**，新增 36 项，原有 270 项全部保留，无 RAID/Btrfs/startdhns；`=m` 余 0 项。
- 构建 `make -j4` 全量完成：`build_dir/king3288-m6-docker-default/fullbuild.rc` 为 `M6_DOCKER_IMAGE_FULLBUILD_RC=0`。manifest 为 **291 个实际安装包**，36 个新增 Kconfig 项在 manifest 中全部找到（五个 lib 有 ABI 后缀名称）；rootfs `gzip -t`/tar读取无错误。
- 为使新镜像第一次开机就通过主路由 DHCP 取得 LAN 地址：仅对 armv7 target 添加 `target/linux/rockchip/armv7/base-files/etc/board.d/99-default_network`，内容复制当前 OpenWrt 默认脚本，唯一实质改动是 `ucidef_set_interface_lan 'eth0' 'dhcp'`；不影响 armv8 或其他 target。
- 为关闭首次开机本机 DHCP server，添加仅首次启动执行的 `target/linux/rockchip/armv7/base-files/etc/uci-defaults/90-king3288-firstboot-lan-docker`：确保 `dhcp.lan.ignore=1`、`dhcp.lan.dhcpv6/ra/ndp=disabled`，随后提交 dhcp；此 uci-defaults 被 S10boot `uci_apply_defaults` 在成功后删除，**不会在之后重启时再写用户手动配置**。
- 当前 iStoreOS 自带 `09_istoreos` uci-defaults 会把 Docker data-root 设置为 `/overlay/upper/opt/docker`，不适合 SD p2 可读写 ext4 rootfs；本轮首次启动脚本仅当值仍为该默认路径时覆盖为 `/opt/docker`，不覆盖用户自定义路径。Docker 的默认防火墙/网络首次启动脚本保留（用户允许）。
- 最新 rootfs 中离线确认：板级 DHCP LAN 配置脚本、关闭 DHCP 服务的一次性脚本、`/etc/init.d/dockerd`、`S99dockerd`、`/etc/config/dockerd`、QuickStart `S92`、OpenClash/Mihomo、Tailscale 首启禁自启规则均存在，rootfs 本身不预置 `/etc/config/network`，它由 `config_generate` 首次启动按板级规则生成。源码 `config_generate` 在 network/system 已配置时退出，不会覆盖后续手动静态网络。
- **rootfs 大小显著增长**：压缩约 141 MiB，构建目录解包约 405 MiB。当前 `.config` 的 `CONFIG_TARGET_ROOTFS_PARTSIZE=512` 仅是 M7 后续镜像制作参数，不应在软件适配阶段据此认定 Docker 数据有足够空间；后续 SD 镜像/扩容应预留空间（建议至少 1GiB 初始 ext4 p2，并最终扩展到剩余卡空间），不在此轮修改分区。
- rootfs 路径 `bin/targets/rockchip/armv7/istoreos-rockchip-armv7-king3288-rootfs.tar.gz`；SHA256 `148ed9bc39641fd752605b8ca72314a8842898f79d0a9035e3a1a8fd99335233`。
- 可复现配置 `king3288-configs/m6-docker-integrated.diffconfig`；编译日志 `build_dir/king3288-m6-docker-default/fullbuild.log`，源码/manifest 审计 `/tmp/king3288-m6-docker-default-validate.log`。
- 旧 M6 已保存 containerd 去 Btrfs 条件依赖补丁 `king3288-patches/m6-containerd-armv7-no-btrfs.patch`，当前独立 `feeds/packages` 工作区已应用；将来重新初始化 feeds 时必须依需要重施、不要盲目重复打补丁。

## 验收边界
- 仅构建机源码、打包和配置脚本**离线**成功，未新刷 SD、未实测 DHCP 地址分配、DHCP server 关闭、Docker 容器启动或 Dockerman 页面。因此不能声称以上功能已实机通过。
- 用户当前旁路由静态配置没有修改；新刷镜像第一次启动 DHCP 默认和后续手工设置持久性仍需要实机复验。
- 接下来继续 M6 其他必需插件/功能，待完成后按用户提供的 Orange Pi 自动扩容脚本推进 M7；再做 M8 长时间稳定性、重启持久性和拔卡回退验收。
