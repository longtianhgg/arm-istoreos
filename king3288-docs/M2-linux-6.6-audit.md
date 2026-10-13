# KING3288 iStoreOS M2 - Linux 6.6.144 板级适配记录

日期：2026-10-13
目标源码：`/home/dragon/king3288-build/king3288-istoreos`，分支 `king3288-istoreos-24.10`
功能对照：`/data/openwrt-build/istoreos` OrangePi Zero3 fork（只读、**不改**）和其 `configs/orangepi-zero3-istoreos.config`。

## 适配原则

- iStoreOS 官方 24.10 / Linux 6.6.144 为唯一交付代码基础。
- OpenWrt 25.12.5 Linux 6.12.94 提供实机验证的 RK3288 DTS、PMIC/PHY/timer/Trust 约束；厂商 Linux 4.4/Ubuntu 提供供电、USB、GMAC checksum 等硬件线索。
- **ARM64 sunxi/kmod/DTB 不拷贝**；OrangePi 的路由、容器及应用功能只在 RK3288 上按实际 Kconfig/kmod 依赖转译。
- 原厂 U-Boot/Trust 保留；本阶段绝不写生产 eMMC，也不做 SD 镜像。
- 只把用户 `Plan.md` 当作执行规划，不修改内容。

## M2 实际改动

1. `target/linux/rockchip/armv7/config-6.6`：以 iStoreOS **自身** `target/linux/armsr/armv7/config-6.6` 作为 ARMv7 起点，添加 6.6 真实存在的 RK3288 必需驱动和配置；显式 Little-endian、四核、SD/eMMC EXT4、GMAC Realtek PHY、ACT8846/SYR82x、USB/TSADC。另留 `CGROUPS`、`NAMESPACES`、`OVERLAY_FS`、`CONFIGFS_FS` 内核前提以支持后续 Docker/USB Gadget。
2. `target/linux/rockchip/patches-6.6/140-arm-dts-rockchip-add-king3288.patch`：将已实机验证的 OpenWrt 6.12 KING3288 DTS port 到实际 Linux 6.6 源码（Linux 6.6 的 rk3288.dtsi 中已存在对应设备节点）。
3. `target/linux/rockchip/patches-6.6/141-arm-dts-rockchip-enable-king3288-tsadc.patch`：**重新生成 context**，因为旧 OpenWrt 141 patch 直接在 6.6 上叠加失败；保持硬件内容完全一致（清除 TSADC pinctrl-0/1/2/names，CRU TSHUT mode 0）。


4. `target/linux/rockchip/Makefile`：仅 `SUBTARGET=armv7` 的 `Kernel/Configure` 在 iStoreOS 自有默认配置合并后执行 `$(KERNEL_MAKE) olddefconfig`。实际首次编译暴露 `UCLAMP_TASK`、`HIGHPTE` 等未决交互提示，此改动使新增 32-bit target 可以非交互构建，不影响现有 armv8。
5. 内核配置依赖修正：`REGULATOR_ACT8865` 在 Linux 6.6 需要 `POWER_SUPPLY=y`；USB 需要先启用 `USB_SUPPORT=y`；`USB_STORAGE` 需要 `SCSI=y` 和 `BLK_DEV_SD=y`。删除对隐藏派生符号 `USB_PHY` 的直接强制，保留 `PHY_ROCKCHIP_USB=y`。为确定性设置 `# CONFIG_UCLAMP_TASK is not set`。


## 已验证的实际测试

- `patch --dry-run --batch -p1`：Linux 6.6.144 中 140 补丁 Makefile hunk 按偏移 -3 可定位。
- 6.6.144 源码临时工作区顺序应用 140、141：`patch --batch --fuzz=0 -p1` 两份均成功。原来的 141 上下文不合法/缩进不匹配，未复制到本项目。
- `make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- multi_v7_defconfig` + `make ... rockchip/rk3288-king3288.dtb`：Linux 6.6 主线源码 DTB 成功生成，38670 bytes；这只是**上游 6.6 + KING3288 补丁的独立测试**，未代表官方 iStoreOS 269 个 rockchip patch 全栈通过。
- DTB 解码：memory 两段 `<0x0 0x08400000> <0x09200000 0x76e00000>`；timer@ff810000 disabled；TSADC status okay，mode 0/polarity 0，节点内不含 pinctrl；GMAC status okay/显式 phy-handle。
- 用 `scripts/kconfig/merge_config.sh -m` 将新 armv7 seed 与主线 `multi_v7_defconfig` 合并，`make olddefconfig` 返回 exit 0；最终配置核对 `CONFIG_CPU_LITTLE_ENDIAN=y`、`CONFIG_NR_CPUS=4`、`CONFIG_ARCH_ROCKCHIP=y`、`CONFIG_MMC_DW_ROCKCHIP=y`、`CONFIG_DWMAC_ROCKCHIP=y`、`CONFIG_REALTEK_PHY=y`、`CONFIG_ROCKCHIP_THERMAL=y`、`CONFIG_EXT4_FS=y`、`CONFIG_CGROUPS=y`、`CONFIG_NAMESPACES=y`、`CONFIG_OVERLAY_FS=y`。

## OrangePi Zero3 已选功能 → KING3288 移植分类

| 功能 | OrangePi 实际配置 | 规划迁移点 |
|---|---|---|
| iStore / QuickStart | `luci-app-store=y`, `luci-app-quickstart=y`, `istoreos-files=y` | **M5** 核对 32-bit ARM 软件包和默认 iStoreOS 仅在 aarch64/x86_64 自动加 iStore 的规则 |
| Docker | `containerd=y docker=y dockerd=y luci-app-dockerman=y` + `kmod-veth=y`, `kmod-br-netfilter=y` | **M2** 先满足 cgroups/namespaces/overlayfs；**M5/M6** 依据实际 ARMv7 软件包及 kmod 完成依赖；禁止复制 arm64 kmod |
| OpenClash/Mihomo | `luci-app-openclash=y`，`kmod-nf-tproxy`、`kmod-nft-tproxy` 等 | **M5/M6** 需要 armv7 Meta Core、fw4/nftables 规则、单网口测试 |
| Tailscale | `tailscale=y`，`kmod-tun=y` | **M5/M6** 审查 Go/ARMv7 构建、TUN 模块及内存资源 |
| LuCI 中文/Argon/管理 | `luci=y`、`luci-theme-argon`、`luci-i18n-*-zh-cn`、`luci-app-ttyd` | **M5** 优先保持同类用户体验 |
| 扩容/存储/RAID | `luci-app-partexp`、`mdadm`、`kmod-md-*` | **M7** 首先确保 SD-only 安全；不能把原来的 1GiB p1 + ext4 p2 分区当作 OrangePi 的相同布局 |
| OrangePi Zero3 H618 SoC 专用 | `sunxi/cortexa53`、H618 内核/DTS/clock/MMC 驱动 | **不移植**，替换为 Rockchip RK3288 ARMv7/实际 DTS |

## M2 完成验收（2026-10-13）

- **实际 iStoreOS 源码 `target/linux/prepare` 成功（exit 0）**：在 iStoreOS Linux 6.6.144 上顺序应用现有 rockchip patch 链及新增 KING3288 140/141 两份 DTS 补丁；真实 patch 结果中的 DTS 保留 Trust/TEE memory、`timer` disabled、GMAC/RTL8211E、ACT8846、TSADC 删除 pinctrl。
- **实际 iStoreOS `target/linux/rockchip compile` 成功（exit 0）**：构建命令为 `make -j12 -C target/linux/rockchip TOPDIR=$PWD TARGET_BUILD=1 BISON_PKGDATADIR=/usr/share/bison KERNEL_CROSS=arm-linux-gnueabihf- KERNEL_CC=arm-linux-gnueabihf-gcc compile V=s`。编译和 ARMv7 `olddefconfig` 均在原仓库实际 kernel 6.6.144 上执行。先前配置交互报错已修复，最终完整日志为 `king3288-m2-linux-compile-final.log`、退出状态文件 `king3288-m2-linux-compile-final.rc`（`M2_FINAL_COMPILE_RC=0`）。编译在独立 tmux 会话 `king3288-istoreos` 内运行。
- **真实产物检查**：`build_dir/target-arm_cortex-a15+neon-vfpv4_musl_eabi/linux-rockchip_armv7/linux-6.6.144/arch/arm/boot/zImage` 约 3.2 MiB；`arch/arm/boot/dts/rockchip/rk3288-king3288.dtb` 约 38 KiB；`vmlinux` ELF32 ARM EABI5 LSB，小端；该 Linux 工作目录中产生 37 个 `.ko`。
- **最终 .config**：`CONFIG_CPU_LITTLE_ENDIAN=y`；`REGULATOR_ACT8865=y` / `REGULATOR_FAN53555=y` / `POWER_SUPPLY=y`；`USB_SUPPORT=y` / `USB=y` / `USB_EHCI_HCD=y` / `USB_OHCI_HCD=y` / `USB_DWC2=y` / `SCSI=y` / `BLK_DEV_SD=y` / `USB_STORAGE=y`；`MMC_DW_ROCKCHIP=y` / `EXT4_FS=y` / `DWMAC_ROCKCHIP=y` / `REALTEK_PHY=y` / `ROCKCHIP_THERMAL=y`。
- DTB `fdtget -t x ... /memory@0 reg` 返回 `0 8400000 9200000 76e00000`；PMIC compatible 为 `active-semi,act8846`，与板级 DTS 基线相符。

### 尚未完成（不属于 M2 内核成功结论）

- 本次内核编译为 **iStoreOS 已打补丁的真实 6.6.144 kernel + Ubuntu 主机 `arm-linux-gnueabihf-` 编译器**，不是 iStoreOS 自身 musl target GCC 的完整工具链/firmware/rootfs/feeds 构建。完整原生交付能力需要后续里程碑验证，不能将上述结果称为最终可刷机固件。
- 未在 KING3288 实机启动新内核，也未写实验 SD 卡、生产 eMMC 或原厂 U-Boot。SD/extlinux 以及 rootfs 验收按后续里程碑逐项执行。
