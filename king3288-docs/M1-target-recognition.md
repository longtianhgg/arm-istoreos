# M1 - KING3288 Rockchip ARMv7 Target 接入记录

日期：2026-10-13
基线：官方 iStoreOS `istoreos-24.10` / HEAD `fb971407ff` / Rockchip Linux 6.6.144
分支：`king3288-istoreos-24.10`
阶段：**M1 target/profile 配置解析通过**；Linux 内核、DTS、SD 启动未验证。

## 最小修改范围

- `target/linux/rockchip/Makefile`：`SUBTARGETS:=armv8 armv7`；删除对 armv7 不适用的顶层 `KERNELNAME:=Image dtbs`。
- `target/linux/rockchip/armv8/target.mk`：显式维持 ARM64 `KERNELNAME:=Image dtbs`。
- `target/linux/rockchip/armv7/target.mk`：`ARCH=arm`，`CPU_TYPE=cortex-a15`，`CPU_SUBTYPE=neon-vfpv4`，`KERNELNAME=zImage dtbs`。
- `target/linux/rockchip/armv7/config-6.6`：仅用于 M1 元数据解析的最小 seed（ARM/CPU_V7/ARCH_ROCKCHIP/CPU_LITTLE_ENDIAN），**不是可编译可启动的 RK3288 内核 config**。
- `target/linux/rockchip/image/armv7.mk`：注册 `DEVICE_king3288`；暂不产生镜像（`IMAGES :=`）。实际 `rk3288-king3288.dtb`、内核配置和镜像生成归 M2/M3/M7。

## 验证

首次未准备独立新仓库的完整 feeds；以纯 Linux PATH 运行 `make defconfig` 返回 exit code 0，元数据及 `.config` 实查：

```text
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv7=y
CONFIG_TARGET_rockchip_armv7_DEVICE_king3288=y
CONFIG_TARGET_BOARD="rockchip"
CONFIG_TARGET_SUBTARGET="armv7"
CONFIG_TARGET_PROFILE="DEVICE_king3288"
CONFIG_TARGET_ARCH_PACKAGES="arm_cortex-a15_neon-vfpv4"
CONFIG_arm=y
CONFIG_arm_v7=y
CONFIG_TARGET_ROOTFS_EXT4FS=y
```

`tmp/.targetinfo` 包含 `Target: rockchip/armv7`、`Linux-Version: 6.6.144`、`Target-Profile: DEVICE_king3288`。
`git diff --check` 无输出。

## 尚待验证与已知提示

1. 首次 defconfig 因尚未安装 feeds，报告 `libev`、`libpam`、`luci-theme-argon` 等缺失依赖；不归咎于 armv7 适配，M5 前按 iStoreOS feeds 安装后重新审查。
2. 独立 `DUMP=1` target 探测提示 `CPU_TYPE "cortex-a15" doesn't correspond to a known type`；这份 iStoreOS 24.10 的 `armsr/armv7` 使用相同 CPU_TYPE。M2 应核验 CFLAGS/最终工具链是否包含期望的 ARMv7/NEON 设置，不将本次配置解析视为编译参数已验证。
3. iStoreOS 对 `luci-app-store` 的默认包选择有架构限制；ARMv7 iStore/QuickStart 依赖需到 M5 核对，M1 不启用。
4. 未执行 `target/linux/prepare`、内核/模块编译、DTS 构建、rootfs 打包或任何介质写入。
5. 用户原始 `Plan.md` 保留原样，未包含进本提交。

下一阶段 M2：核对 iStoreOS 自身 Linux 6.6.144 的 ARMv7 Kconfig / DTS / 补丁叠加顺序，按最小顺序完成 kernel config 与 DTB，验证 zImage+DTB 后再进入 SD 启动。
