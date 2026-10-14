# KING3288 / M7 — SD p2 ext4 安全扩容脚本阶段（2026-10-14）

## 用户决定与适配依据
- M6 软件包适配就此收口：保留现有 296 个实际包，不再追求 Zero3 清单剩余 23 项。Docker/Compose/Dockerman/ttyd、OpenClash/Mihomo、Tailscale、LuCI/iStore/QuickStart 等已在构建机完整编译，**未将新的 rootfs 刷到正在使用的 SD**。
- 用户提供 `orangepi-zero3-expand-overlay.sh` 作为参考，该脚本处理 **p1 FAT + p2 SquashFS + p3 ext4 /overlay**，不可在 KING3288 上原样使用。
- 当前 KING3288 已实机验证的 SD 启动布局：原厂 U-Boot → **SD p1 FAT32 extlinux/zImage/DTB** → **SD p2 ext4 `/`**。`root=PARTUUID=4b328826-02` 曾实测；MMC 内核设备号会改变，生产 eMMC Ubuntu 严禁写入。
- 因尚未生成/冷启动验证正式 M7 整盘 SD 镜像，**本阶段只建立安全扩容脚本与重启后的收尾 init 模板，并作离线校验；不将它接入自动执行，也不在当前生产 SD 上运行**。

## 已制作文件
- `king3288-tools/king3288-expand-rootfs.sh`：`--check`（只读检查）、`--apply`（显式备份 SD 分区表、扩 SD p2 到末尾）、`--finish`（重启后 `resize2fs` 在线扩 ext4）。默认必须带明确参数，不会在无参数时写盘。
- `king3288-tools/king3288-rootfs-resize.init`：可选一次性 rc.common 服务模板，`START=98`；只有 `--apply` 在镜像已安装它时才会开启，重启后自动调用 `--finish`，成功则禁用自身。
- 安全约束：读取 DTS `model=KING3288`；根据实际 `/proc/cmdline root=PARTUUID=...` + `blkid` 匹配 SD p2，**不硬编码 mmcblk0/1**；强制校验 MMC `device/type=SD`、`removable=1`、根挂载 ext4、p1 vfat、MBR/msdos 两分区、p1 在 p2 前且不重叠；有其它分区直接拒绝；`PARTUUID` 或分区起点改变时停止；**绝不接受 eMMC 的 MMC 类型**。
- `--apply` 先备份 SD 前 1MiB（MBR + Rockchip IDB 区域）和分区布局记录到 SD 根下 `/root/king3288-expand-backup`，先写 pending 状态，再允许 `parted ... resizepart 2 100%`；不新增分区、不重建文件系统、不执行 mkfs、不修改 p1 / extlinux、不触碰 U-Boot 和 eMMC；失败时不自动重试写盘。
- 重启后 `--finish` 会要求与 pending 相同的 PARTUUID、相同 p2 起始扇区、实际增加的 p2 扇区数且尾部剩余空间很小，再调用 `resize2fs`，完成后写 done、删除 pending、禁止以后重复扩容。
- `--check` 不写磁盘、不创建状态文件；在不符合条件的主机/设备上会安全退出。根 ext4、新分区表、重启后的 `resize2fs` **尚未在实机验证**。

## 已查依赖与构建事实
- 当前 iStoreOS ARMv7 `.config` 已选中 `parted` 3.6、`blkid`、`e2fsprogs` 1.47.0、`resize2fs`、`fdisk`，且均在 296 包 rootfs manifest 中，不需额外加入 Btrfs/RAID。
- `sh -n` 均成功；脚本远程工作目录副本与下载版本的 SHA256 完全相同。
- 这 **不是整盘 SD 镜像完成**，亦未进行分区表模拟变更/实机冷启动/扩容验证。

## 下一步
1. 在 M7 整盘 SD 镜像方案（IDB/miniloader 来源、分区 MBR、p1 extlinux/boot、p2 大小/PARTUUID 一致）确认后，才把脚本安装进 **新镜像** 的 `/usr/sbin/king3288-expand-rootfs`，模板置 `/etc/init.d/king3288-rootfs-resize`。
2. 先对新刷出的实验 SD 执行 `/usr/sbin/king3288-expand-rootfs --check`，确认 SD-only 保护、分区边界与日志，再明确批准首启 `--apply` 机制（自动/手动），绝不对现在的生产 SD 执行。
3. 仅在新 SD 上测试首次扩容、重启后 ext4、持久化与拔卡回退，最终与 M8 验收配合。保留生产 eMMC Ubuntu 4.4、原厂 U-Boot/Trust 不动；当前 SD 手动静态旁路由网络不变。
