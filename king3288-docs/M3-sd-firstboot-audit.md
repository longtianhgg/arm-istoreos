# KING3288 iStoreOS M3：首次 SD/extlinux 启动准备

日期：2026-10-13。状态：**离线构建已成功，尚未在 KING3288 实机验证启动**。
源码：`/home/dragon/king3288-build/king3288-istoreos`，构建时 HEAD `0ede5b75ac`；iStoreOS 24.10 / Linux 6.6.144，rockchip/armv7。

## 构建输入与实际结果

- 从本机 `/data/openwrt-build/istoreos/feeds` 只读参考仓库克隆六组干净的 Git checkout，未引入参考仓库未提交的改动。准确 SHA 见 `king3288-configs/m3-feeds.lock`。
- `third` feed 的四个 Git submodule 已初始化并按 SHA 锁定（`king3288-configs/m3-third-submodules.lock`），修复 Argon 源码初次缺失的问题。
- `./scripts/feeds update -a -i`、`./scripts/feeds install -a`；子模块安装后重新建立 third 索引。`make defconfig` 退出码 0。实际 diffconfig 见 `king3288-configs/m3-firstboot.diffconfig`。
- `make -j12 tools/install V=s` 成功：`M3_TOOLS_RC=0`。
- `make -j12 toolchain/install V=s` 成功：`M3_TOOLCHAIN_RC=0`。确认 GCC 13.3.0，target `arm-openwrt-linux-muslgnueabi`、musl 1.2.5。
- `make -j12 V=s` 完整构建成功：`M3_ROOTFS_BUILD_RC=0`；使用原生目标交叉工具链重编 Linux 6.6.144 zImage，生成 127 行 package manifest 和独立 rootfs。
- 本轮启用 `CONFIG_TARGET_ROOTFS_TARGZ=y`，ext4 rootfs 构建文件设为 512 MiB，不生成完整 SD 或 sysupgrade 镜像。

## 静态验收

- rootfs tar.gz 的 gzip 完整性通过；包含 `/sbin/init`、procd、ubusd、netifd、BusyBox、ubus。`/sbin/init` 为 ELF32 LSB ARM EABI5 hard-float，动态解释器 `/lib/ld-musl-armhf.so.1`。
- 原生内核 `zImage` 为 ARM little-endian；`vmlinux` 是 ELF32 LSB ARM；DTB 内存两段 `0 8400000 9200000 76e00000`、PMIC `active-semi,act8846`、UART2 115200；`/chosen` 无 bootargs 属性。
- `build_dir/target-arm_cortex-a15+neon-vfpv4_musl_eabi/linux-rockchip_armv7/root.ext4` 是仅用于离线检查的 512 MiB 独立文件。首次 e2fsck 发现 inode bitmap 尾部 padding 未设置，只对该生成文件执行离线修复，复检无警告；首次实验 SD 更新应使用 rootfs tar，而不是用 512 MiB 镜像覆盖既有约 14 GiB p2。

## 独立启动文件集合

构建输出：`bin/targets/rockchip/armv7/king3288-m3-sd-files/`，**尚未拷贝到 SD 卡**。
包含 `zImage`、`rk3288-king3288.dtb`、`istoreos-rockchip-armv7-king3288-rootfs.tar.gz`、127 行 manifest、`SHA256SUMS`、`README-M3.txt`。
`sha256sum -c SHA256SUMS` 三项均通过。构建日志与退出码位于忽略的 `build_dir/king3288-m3/`。

## 交付 SHA256

- `zImage`：`1c9788cfa7312e7754107fe15f45b9a13eec993f0e8351458c63c2b5d0654025`
- `rk3288-king3288.dtb`：`0b2506ab2ef0b7404e4305e89743213825b3a3bb7ee067af029d67571389b0eb`
- `istoreos-rockchip-armv7-king3288-rootfs.tar.gz`：`3f5591dac38e7bd8d09033f071daab0da53e2d3181b9999d5e0527f5321b221f`

## 后续实机验收（M3 尚未完成）

1. 首先只读核对实验 SD 盘符、分区表、FAT32 p1 内现存 `extlinux/extlinux.conf` 内容及 ext4 p2 的 UUID/PARTUUID。新版生产 eMMC Ubuntu 安装之后，插 SD 优先启动尚未复测。
2. 必须先备份并确认设备身份，之后才允许只部署到**实验 SD**。保留原厂 U-Boot、Trust、生产 eMMC 和现有已验证的引导机制；不要使用完整刷盘或不安全的升级流程。p2 应采用 rootfs tar 解包方式保留原 ext4 分区尺寸。
3. UART2 115200 全程留存串口日志：检查 Linux 6.6.144、四核/内存、SD/eMMC 枚举、extlinux 引导参数、SD p2 ext4 挂载、`/sbin/init`、procd、ubus 与 netifd。
4. 拔实验 SD，再验证当前 eMMC Ubuntu 能正常进入用户态。上述实机结果未返回前，不将 M3 标记成功。

网络长期稳定性 M4、完整 iStore/QuickStart M5、整盘 SD 镜像和安全升级 M7，均未进入本次范围。
