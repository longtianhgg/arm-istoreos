# KING3288 iStoreOS M6 OpenClash/Mihomo — 2026-10-14

## 依据与范围
- 唯一总基线：Project 的 `KING3288_HANDOFF.md` 第 25 节；子基线 `KING3288_OPENWRT_ADAPTATION_HANDOFF.md` 第 11 节。
- 原生源码 `king3288-istoreos-24.10`，iStoreOS 24.10.8 / Linux 6.6.144 / rockchip-armv7 / OPKG。
- 保留 M5 的 LuCI/Argon、iStore、QuickStart 手动网络向导；当前 SD 旁路由静态 `192.168.50.202/24`、网关和 DNS `192.168.50.3`、DHCP 关闭，不切回 DHCP 客户端。
- 原厂 U-Boot/Trust/生产 eMMC 不写；没有刷入新 rootfs、没有改动当前运行 SD 配置；自动 SD p2 扩容明确延后至其他软件包适配完成后，参考用户另行提供的 Orange Pi 脚本。

## 本轮已完成（仅源码/编译机验收）
- 从 Zero3 `package/custom/luci-app-openclash` 移植 OpenClash `0.47.156`；将 OpenClash Makefile 中基于 firewall4 的默认依赖限制为选中 OpenClash 时才生效，避免禁用状态下自动改变 dnsmasq 配置。
- `make defconfig` 实际验证：OpenClash、Ruby/Ruby-YAML、`dnsmasq-full`、`kmod-tun`、`kmod-inet-diag`、`kmod-nf-tproxy`、`kmod-nft-tproxy` 等已选中。新 rootfs 内 `dnsmasq` 替换为 `dnsmasq-full`；未选中 mdadm/kmod-md-mod/startdhns。
- 在 KING Linux 6.6.144 最终 kernel config 确认 `CONFIG_TUN=m`、`CONFIG_INET_DIAG=m`、`CONFIG_NFT_TPROXY=m`、`CONFIG_NF_TPROXY_IPV4=m`、`CONFIG_NF_TPROXY_IPV6=m`；对应 ARMv7 IPK/manifest 已存在。
- 从已验证 OpenWrt 源码移入 `package/custom/king3288-openclash-core`，下载 Mihomo `1.19.31` ARMv7 静态 ELF，原下载压缩包 SHA256 为 `a61115819d9ebd568788b0f1bddfa6c9c03458071abdbda80f79291cac0276e1`。
- 通过 iStoreOS 完整编译：`build_dir/king3288-m6-openclash/mihomo-fullbuild.rc` 为 `M6_MIHOMO_FULL_BUILD_RC=0`，manifest **254 包**。
- 离线验证新 rootfs 中 `/etc/openclash/core/clash_meta` 与经过 SHA256 验证的上游解压 ARMv7 二进制逐字节一致（56,033,406 bytes；SHA256 `1f0d082b19a51a31f04de29c3db28c8145e499dc5ab01cccf12376cf7fc71777`）。
- 新 rootfs 的 `/etc/config/openclash` 默认主开关 `option enable '0'`。仍保留 QuickStart、luci-app-quickstart 和 luci-app-store。
- rootfs: `bin/targets/rockchip/armv7/istoreos-rockchip-armv7-king3288-rootfs.tar.gz`，约 47 MB；SHA256 `f7c1f6d4a1cebd2b61f13e55e5586ebfcda214918246caffdda8d366985bbacf`。
- 可复现配置：`king3288-configs/m6-openclash.diffconfig`；构建日志：`build_dir/king3288-m6-openclash/{fullbuild.log,mihomo-fullbuild.log}`。

## 边界与未完成
- 只证明源代码、依赖解析、内核模块编译、rootfs 打包及 Mihomo 核心字节正确；**没有刷 SD、没有在线安装本轮固件，也没有实机验收 OpenClash 代理/DNS/nftables TPROXY 或 Mihomo 运行**。勿将 M6 OpenClash 功能标为实机完成。
- OpenClash 的 DNS/防火墙规则与现有静态旁路由不能未经授权覆盖；正式镜像安装/实机启用须另行审查并允许安全恢复。
- 其他 M6 包：Tailscale、Docker、ttyd 等待后续逐项；另外 3 个 LuCI 源码目录目前为未跟踪候选，不在本提交。
- M7 SD p2 安全自动扩容及 M8 吞吐、24～48h 长稳、重启持久性、拔卡回退等按用户要求全部后置。
