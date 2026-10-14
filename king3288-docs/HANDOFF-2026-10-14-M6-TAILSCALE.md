# KING3288 iStoreOS M6 Tailscale — 2026-10-14

## 工程基线
- 唯一总基线：Project `KING3288_HANDOFF.md` 第 25 节；原生 iStoreOS 24.10.8 / Linux 6.6.144 / rockchip-armv7 / musl / OPKG。
- 接续 KING3288 原生仓库 M6 OpenClash/Mihomo 提交 `5abc8f28c5`，保留 M5 QuickStart、LuCI/Argon、iStore 和 M6-A 用户态组件。
- 当前实机 SD 仍为 M3 rootfs + 在线 M5 包，手动设置静态 `192.168.50.202/24`、网关/DNS `192.168.50.3`、本机 DHCP 关闭；本轮**未刷 SD、不改现有网络、不写 eMMC / U-Boot / Trust**。

## M6 Tailscale 主机构建事实
- 当前 feed `feeds/packages/net/tailscale/Makefile` 为 `tailscale 1.80.3-r1`，`DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle +kmod-tun`。没有修改上游 feed。
- 从已通过的 M6 OpenClash 配置追加且**仅追加** `CONFIG_PACKAGE_tailscale=y`，选包 269→270；未删除任何原有选项。当前 Go 1.23.12 host toolchain 通过源码 bootstrap 构建后完成 ARMv7 Tailscale 交叉编译。
- 最终 `make -j8`：`build_dir/king3288-m6-tailscale/fullbuild.rc` = `M6_TAILSCALE_FULL_BUILD_RC=0`。
- 针对首次启动默认自启增加且仅增加 `target/linux/rockchip/armv7/base-files/etc/uci-defaults/99-king3288-tailscale-disabled`：S10boot 的 uci-defaults 会先运行此脚本，调用 `/etc/init.d/tailscale disable` 移除上游自动生成的 `S80tailscale` 链接；成功后 uci-defaults 脚本被删除。Tailscale 后续由用户自行 `start`、登录和 `enable`，不影响 QuickStart `S92quickstart`。
- 第二次完整构建 `build_dir/king3288-m6-tailscale/safety-build.rc` = `M6_TAILSCALE_SAFETY_BUILD_RC=0`；离线验证该 uci-defaults 文件在最终 rootfs，S10 boot/S80 tailscale/S92 quickstart 链接均存在，首次启动策略的执行顺序由 iStoreOS 实际 `/etc/init.d/boot` 验证。
- ARMv7 IPK `bin/packages/arm_cortex-a15_neon-vfpv4/packages/tailscale_1.80.3-r1_arm_cortex-a15_neon-vfpv4.ipk`，约 9.0 MB。
- 新 rootfs `bin/targets/rockchip/armv7/istoreos-rockchip-armv7-king3288-rootfs.tar.gz` 约 56 MB、manifest 255 包；`gzip -t` 正常，Tailscale、`kmod-tun`、`ca-bundle`、OpenClash/Mihomo、QuickStart/iStore 均存在；无 `dnsmasq`（已换 dnsmasq-full）、mdadm 或 startdhns。
- `/usr/sbin/tailscaled` 经 `file` 实检为 32-bit ARM EABI5、musl `/lib/ld-musl-armhf.so.1` 动态链接 Go ELF；`/usr/sbin/tailscale` 为指向 `tailscaled` 的符号链接。
- rootfs SHA256 `38861e8c2ad3898782f8365fb54aa1f5bb6d34f276e121e871496a09c3c67583`。
- 可复现配置：`king3288-configs/m6-tailscale.diffconfig`。日志：`build_dir/king3288-m6-tailscale/{fullbuild.log,safety-build.log}`，配置审计 `/tmp/king3288-m6-tailscale-config-20261014.log`。

## 尚未验证 / 后续
- 尚未把此 rootfs 刷入 SD。Tailscale 登录、tun0 设备、连接 Tailnet、子网路由/nftables 规则、首次启动禁用执行情况均需后续实机核对；不得把这些写成已实机通过。
- 当前 Tailscale 在未来新 rootfs 首次启动默认不自启；用户实际部署后须手动启动、认证，并在需要持久化时执行 `/etc/init.d/tailscale enable`。不要提前更改用户正在运行的 SD 旁路由网络。
- 继续 M6 其他软件包分组适配；Btrfs/RAID/NAS 非必选；SD p2 首次安全扩容等其他软件包完成后参考用户将提供的 Orange Pi 脚本；M8 吞吐/24–48h 稳定性/重启持久性最终验收仍后置。
