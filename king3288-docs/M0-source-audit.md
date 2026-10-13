# KING3288 iStoreOS M0 三源兼容性与风险审查

- 日期：2026-10-13
- 执行依据：仓库根目录 `Plan.md`，项目总基线 `KING3288_HANDOFF.md` 第 24 节及 OpenWrt 子基线
- 阶段状态：**M0 源码只读审查完成；M1/M2/M3 尚未执行或验收**
- 范围：本次不修改原厂 U-Boot、生产 eMMC、SD 卡、现存 Ubuntu 镜像；不修改 iStoreOS target/驱动/DTS/Kconfig。
- 注意：Linux 6.6 参考源码来自既有 `/data/openwrt-build/istoreos/build_dir/toolchain-aarch64_cortex-a53_gcc-13.3.0_musl/linux-6.6.144`；这是旧构建缓存中的 Linux 6.6 源码树，用于预审主线节点/Kconfig，**不代表新 KING3288 target 的补丁叠加结果已经验证**。

## 一、源码版本与状态

| 代码库 | 实际位置 / 版本 | M0 发现 |
|---|---|---|
| iStoreOS 官方 | `/home/dragon/king3288-build/king3288-istoreos`；分支 `king3288-istoreos-24.10`；HEAD `fb971407ff` | 官方 `istoreos-24.10`；Rockchip `KERNEL_PATCHVER:=6.6`；`include/kernel-6.6` 为 6.6.144 |
| OpenWrt 已验证版本 | `/home/dragon/king3288-build/king3288-openwrt`；`king3288-25.12.5`；HEAD `2b99bdf90b` | Linux 6.12.94；`rockchip/armv7`，历史手工 SD/extlinux 实机完成 |
| 厂商 Linux / Ubuntu | `/home/dragon/king3288-build/rk3288-linux`；`king3288-ubuntu-4.4.189`；HEAD `7684ccbc5` | Linux 4.4.189；真实 `kernel/.config` 和 `king3288-linux.dts` 可读取；Ubuntu SD/eMMC 实机运行结论来自 handoff |

iStoreOS 检查时 Git 只有用户添加的 `?? Plan.md`；未发现源码已修改。M0 新增本报告，不擅自纳入/覆盖 Plan。

## 二、三源差异及移植决策

| 主题 | 实际证据 | 决策与优先级 |
|---|---|---|
| Rockchip target | iStoreOS `target/linux/rockchip/Makefile` 仅 `SUBTARGETS:=armv8`；顶层 `KERNELNAME:=Image dtbs` | **M1 重适配**：增加 armv7，保留 armv8 原行为，把 zImage 选择放到 armv7 |
| ABI/toolchain | OpenWrt `armv7/target.mk`：`ARCH:=arm`、`CPU_TYPE:=cortex-a15`、`CPU_SUBTYPE:=neon-vfpv4` | **M1 复用设计**，在 iStoreOS 24.10 真实配置解析验证，不凭假设声称兼容 |
| 镜像流程 | iStoreOS `image/Makefile` 通过 `include $(SUBTARGET).mk` 加载设备定义，默认 ARM64 FIT/boot-script/`pine64-img` | **M1 仅支持目标选择**；M3 生成独立 zImage/DTB/rootfs；M7 再开发 KING3288 SD 整盘生成，不能套 ARM64 写盘 |
| 内核版本 | iStoreOS `include/kernel-6.6`：6.6.144；OpenWrt 已验证 `config-6.12` | **M2 按实际 6.6 重建 ARMv7 config**，不能复制完整 6.12 config 或旧内核产物 |
| ARM endian | 6.6 `arch/arm/mm/Kconfig` CPU endian choice 默认 LITTLE；历史 6.12 曾因实际最终 config BIG 发生 `/sbin/init` ENOEXEC | **M2 显式核对** `CONFIG_CPU_LITTLE_ENDIAN=y` 与最终 `.config`/ELF，而非仅按默认推断 |
| DTS 入口 | 6.6 `arch/arm/boot/dts/rockchip/Makefile` 有 `rk3288-evb-act8846.dtb`，没有 `rk3288-king3288.dtb`；参考主线有 `rk3288.dtsi` | **M2 重移植** `140` 所建 KING3288 DTS 和 Makefile 条目，按 6.6 符号/绑定检查 |
| Trust / timer / UART | OpenWrt 历史实机验证两段内存、`&timer disabled`、UART2；6.6 `rk3288.dtsi` 存在 `timer@ff810000` | **P0 完整保留**，不套厂商 `chosen/bootargs` 根分区值 |
| 电源 / MMC | 厂商 ACT8846+SYR827/SYR828；OpenWrt DTS 有 regulators/SD/eMMC；6.6 源码找到 `REGULATOR_ACT8865`、`REGULATOR_FAN53555`、`MMC_DW_ROCKCHIP` Kconfig | **M2 基于 6.6 配置/依赖编译**，保持 GPIO0_B2 的 PMIC pwr_hold |
| TSADC 引脚冲突 | 6.6 `rk3288.dtsi` TSADC 继承 `pinctrl-0/1/2` = `otp_pin/otp_out`；两者均关联 GPIO0_B2（`RK_PB2`） | **P0 必须随 DTS 同批适配**：CRU TSHUT `rockchip,hw-tshut-mode=<0>`、删除继承 pinctrl；不能先仅启用 TSADC |
| GMAC / MDIO | OpenWrt 6.12 显式 `mdio0` + `ethernet-phy@0`、`phy-handle` 已实机验证；6.6 有 `gmac` 节点与 `DWMAC_ROCKCHIP` Kconfig | **M2 保留** RGMII、TX=0x30、RX=0x10、PHY@0；M4 再测试长期稳定性 |
| USB / HDMI / GPIO | 厂商 DTS 包含 `rp_power`、`rp_gpio`、HDMI/VOP/codec；4.4 config 有 DWC2、ConfigFS HID、mass storage、DRM_ROCKCHIP | **参考原理**，M6 分别核对 6.6 主线驱动/连接后适配；不直接移植私有 rp_* 驱动 |
| GMAC TX checksum | Ubuntu Linux 4.4 上 Windows pktmon 捕获到校验和错误，关闭 TX offload 后 SSH/HTTP 原地恢复；Ubuntu SD 镜像以 NM dispatcher 持久化 | **M4 先复现验证 6.6**，必要时用 iStoreOS 原生启动方式禁用 offload；不移植 NM dispatcher |
| MAC 来源 | 厂商 4.4 MAC 来源失败，Ubuntu udev .link 提前固定 `06:30:32:b6:32:5a`，DHCP 绑定可用 | **M4 设计每设备稳定 MAC**（不能让公开镜像所有设备复用同一 MAC），不拷贝 NM/udev 方案 |
| Wi-Fi | 历史 Broadcom AP6335 DHD 锁故障，Ubuntu 禁 Wi-Fi 后日志安静；OpenWrt 路由器已验证的是有线链路 | **M6 暂不加载旧 BSP DHD**，待 6.6 驱动/firmware 独立验收 |
| 软件包系统 | iStoreOS `config/Config-build.in`：`USE_APK` 依赖 `BROKEN`，OPKG 为当前常规路径；6.12 OpenWrt 的 APK、pinned feeds 版本不同 | **M5 按 OPKG 原生依赖**审查 iStore/QuickStart/软件仓库；不混入旧 APK 包 |
| 私人软件与配置 | Ubuntu Mihomo/NAT、Docker 已实机可用，但依赖 systemd/NM/iptables 或 glibc；iStoreOS 为 procd/fw4/musl 体系 | **M5/M6 原生集成**，不照搬自启动脚本、私人订阅和旧容器运行时 |
| OTA/sysupgrade | 当前无 KING3288 安全升级脚本；MMC 设备编号随 4.4/6.12 不同 | **M7 前禁止自动写盘**；由设备唯一标识/PARTUUID/分区布局判定 SD，保留 eMMC |

## 三、逐文件最小实施清单（未执行）

1. **M1** `target/linux/rockchip/Makefile`：增加 armv7；把 `KERNELNAME:=Image dtbs` 从公共设置移入 armv8 的适当位置，确保不改变 armv8。
2. **M1** 新增 `target/linux/rockchip/armv7/target.mk`：先核对 iStoreOS 24.10 的 CPU ABI 与 target 选择，沿用已验证的 ARMv7 用户空间架构思路。
3. **M1/M2 边界**：`image/armv7.mk` 和 `armv7/config-6.6` 为构建系统必需候选，但核心 DTS/Kconfig 内容要在 M2 由 Linux 6.6 真实源码确认后再填，不以 6.12 整文件直接覆盖。
4. **M2** `target/linux/rockchip/patches-6.6/...`：重新生成 KING3288 DTS patch，明确 TSADC/pwr_hold 和 MDIO，检查官方 Rockchip 6.6 patch 顺序/上下文。
5. **M2** 最终 `linux-6.6.144/.config`、`zImage`、`rk3288-king3288.dtb`：验证端序、驱动 built-in、CPU/Trust/PMIC/存储和 DTS 编译。
6. **M3** SD p1 extlinux + p2 ext4 rootfs：只在实验卡操作，记录串口和无 SD eMMC 回退；根设备名从实际探测确认，不跨内核照搬。
7. **M4+** 长期网络与温控验收，后续才接原生 iStore/OPKG、Docker/One-KVM 和整盘镜像。

## 四、未验证项与风险

- **未验证**：KING3288 相关 6.12 patch 在 iStoreOS 6.6 全量 patch stack 中可直接应用、内核可编译、可 SD 启动；当前参考 6.6 树为旧工具链源码快照。
- **未验证**：6.6 armv7 `config` 依赖闭环及 `make defconfig`、`target/linux/prepare`、`target/linux/compile`；尚无 KING3288 6.6 的 DTB / zImage。
- **未验证**：iStoreOS 上长期 GMAC 稳定性、offload 问题是否复现、Wi-Fi、Docker、USB OTG、One-KVM、HDMI。
- **不可动**：原厂 U-Boot/Trust、生产 eMMC、现有可靠 SD/Ubuntu 镜像；不得复做已验证 6.12 bring-up。
- **安全门槛**：先 M1 target 识别和 defconfig，后 M2 kernel/DTS，M3 才允许经确认使用 SD 卡；自动升级及 eMMC 写入在更后阶段才单独评审。

## 五、M0 验收与下一步

**M0 完成定义**：已列出版本差异、关键 Linux 6.6 实际源码依据、三方复用边界、逐文件清单与风险；此时不宣称任何 KING3288 iStoreOS 构建/实机成功。

**下一唯一里程碑 M1**：先小步修改 `rockchip` target 结构，证明 `rockchip/armv7` 可以被 iStoreOS 24.10 构建系统选中，不并行加入完整 DTS、驱动 patch、SD 镜像或 eMMC 安装。

