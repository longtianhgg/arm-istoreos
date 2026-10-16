# KING3288 M8：GMAC TXPBL1 源码固化、SD v3 和 ImageBuilder（2026-10-16）

> 当前总基线是 Project `KING3288_HANDOFF.md` 第 27 节，专项基线是 `KING3288_OPENWRT_ADAPTATION_HANDOFF.md` 第 13 节。本文件保留构建机工程上下文。iStoreOS 24.10.8 / Linux 6.6.144 / rockchip armv7 / musl OPKG。不覆盖 M7 v1/v2，不写 eMMC/U-Boot/Trust/运行中 SD。

## 实机验证完成（不是推断）

- 从 M7 内核原 DTB 仅增 `/ethernet@ff290000/snps,txpbl=<1>` 得到 2026-10-15 TXPBL1 实测 DTB（SHA256 `783b637003be862a164e05ee76d6eb9039bc14869d52c59a15beb5db1d615fd0`），原有 TX/RX delay 0x30/0x10、max-speed=1000、其余所有节点不变。
- 当前 100Mbps/Full、TX PBL=1（开启 8×，有效 8 beats）、RX PBL 保持原样、TX/RX checksum on。
- 用户 KING3288 → Windows 传输 2.45GB ISO，完整成功、SHA256 双端一致、吞吐跑满百兆。ethtool TX underflow/payload/header/csum、RX CRC/overflow、DMA fatal bus error 计数均 0。
- 约 24 小时 Windows 监控 2873 探测、2869 正常、4 异常采样：12:03 `procd` SIGBUS kernel panic 自动重启（传 2.45GB 到仅约 1002MB 的 /tmp tmpfs 时间相关，根因未证明）；16:44 Windows 用户手动重配网络；10:07 两次仅 Ping 失败时 SSH/LuCI/TCP 仍正常。没有再次见到旧式长时间 Ping 正常/TCP 全失联。千兆未测。
- 12:03 的 Kernel panic **不应视为已证实的 PBL1 驱动错误**；`/tmp` tmpfs 满也不能直接证明 PID1 SIGBUS 原因；SD ext4 errors_count=0 不能证明历史全无问题。

## M8 源码变更

- DTS 源补丁：`target/linux/rockchip/patches-6.6/140-arm-dts-rockchip-add-king3288.patch` 只在现有 GMAC 节点新增 `snps,txpbl = <1>;`，并更新补丁 hunk 行数。Linux6.6.144 clean/rebuild DTB 通过，重编 DTB SHA256 `02a2537f6e13d1b2ed066df13d70544e5ee49dc8c338868dadb4a9f85340a2d0`、`fdtget snps,txpbl=1`。
- `.config` 启用 `CONFIG_IB=y`，原生使能 `CONFIG_IB_STANDALONE=y`；`king3288-configs/m8-txpbl1-imagebuilder.diffconfig` 可在新构建环境通过 `cp ... .config && make defconfig` 复原选择。M6 原包集合构建 manifest 仍为 296 包。
- 完全源码化两个 M7 曾镜像后注入的组件：`target/linux/rockchip/armv7/base-files/usr/sbin/king3288-expand-rootfs`、`target/linux/rockchip/armv7/base-files/etc/init.d/king3288-rootfs-resize`。已有的 `target/linux/rockchip/armv7/base-files/etc/uci-defaults/10-king3288-protect-emmc` 不改变原有 UUID 保护。已强制重编 `package/base-files`，新 IPK 内三个文件均存在。
- 独立的 `king3288-tools/build-king3288-sd-image-txpbl1-v3.sh` 使用编译的 zImage/DTB/rootfs，先验证 DTB TXPBL1 和三项 rootfs 文件，再文件级封装 M7 相同 MBR/p1 FAT32 + SD IDB/extlinux/p2 ext4。旧 v1/v2 镜像单独备份在 `/home/dragon/king3288-build/images/king3288-m7-preserved-20261016`。
- 整盘 SD 的供应商 IDB/miniloader 不由 ImageBuilder 独立生成；Native ImageBuilder 的默认 DEVICE_king3288 profile 只列 profile 内包，M6 额外包需配包清单显式选用。不能宣称 native ImageBuilder 单命令产出具有原厂 IDB 的可启动 SD 镜像。

## 当前构建与验收

- M8 Linux6.6.144 源码 clean/build -> `fullbuild-final.rc=0`；manifest **296 包**，新 DTB `snps,txpbl=1`，SHA256 `02a2537f6e13d1b2ed066df13d70544e5ee49dc8c338868dadb4a9f85340a2d0`。
- M8 SD v3 `sd-v3-build.rc=0`：`bin/targets/rockchip/armv7/istoreos-rockchip-armv7-king3288-sdcard-3g-txpbl1-v3.img.gz`，SHA256 `e078a8f36deee515d11b0785a64a0700e2905f5b31b0a831a57e42a83bb38f1f`；raw IMG SHA256 `864aea3eec3fecd2c10cbad4129dc63fb854b49eb5f915f1ea68d301b39f2246`，raw 3,238,002,688 bytes。
- v3 完整离线验收 `v3-offline-validation.rc=0`：MBR/IDB、FAT 读回 zImage/DTB/extlinux、新 DTB 仅 TXPBL1、整段 2GiB p2 与 ext4 产物 SHA 完全相同、e2fsck、三个源脚本检查全通过；`M8_V3_FULL_DISK_OFFLINE_VALIDATION_OK`。**新 v3 未刷到新 SD 实机冷启动**。
- Native ImageBuilder `bin/targets/rockchip/armv7/istoreos-imagebuilder-rockchip-armv7.Linux-x86_64.tar.zst`，SHA256 `70470f3fa09fc910471dfef5e86cef0e409ef0f2a95e0b95174082c6eb7bef32`，约 176 MiB，`CONFIG_IB_STANDALONE=y`。独立解包后运行 `king3288-tools/build-king3288-ib-rootfs-m8.sh` 复现 `ib-smoke-retry.rc=0`；`king3288-configs/m8-txpbl1-imagebuilder-packages.txt` 钉住全部 296 包、`-dnsmasq` 覆盖默认包以保留 `dnsmasq-full`；IB 自建 `king3288.manifest` 与源码构建 manifest **逐行完全一致**，IB rootfs.tar.gz 存在并包括三项板级脚本。
- IB smoke 期间 OpenClash 的宿主机环境绝对路径脚本仍有提示（`sed can't read`、`/lib/functions.sh` 不存在），但整体 make image 返回 0、296 包名单一致；**不将该离线构建误写成 OpenClash 全功能实机验收**。
- 默认 native `make image PROFILE=king3288` 不自动装入 .config 中额外 M6 包；请用 M8 wrapper/pinned 296 包表才能复现本轮 rootfs。native ImageBuilder 不是包含厂商 IDB 的 KING3288 可启动整盘镜像生成器，完整 SD v3 仍由专用脚本构建。
- 源码源码仓库 Git 未执行在线 push；保留旧 v1/v2 的独立备份。未复制用户手动配置的静态 IP / 网关 / 密码等运行态信息到 image 默认值，避免新刷卡冲突。

## 安全边界

继续在 tmux `king3288-istoreos:0.0` 工作，保持 `:1.0` 不动；保留未跟踪 `Plan.md`、旧日志、`luci-app-netwizard/` 与 `luci-app-partexp/`，不进行 broad git add。禁止触碰原厂 U-Boot/Trust、eMMC、运行中的已扩容 SD。新增 v3 即使离线合格仍是**未进行新卡实机冷启动**。

## M9：2026-10-16 GitHub 发布封版

- 用户宣布 iStoreOS 适配工作结束，进入归档/发布/按需维护；不再修改已验证的硬件启动链、GMAC、Trust/U-Boot/eMMC。
- iStoreOS 源码已发布至 https://github.com/longtianhgg/arm-istoreos/tree/king3288；Git HEAD 43370a8871fcd2beb77b410db122bde629ea6843（此前 M8 编译内核/用户空间 HEAD 420f023d1a；新提交仅增加源脚本移植、IDB 与 Actions，不是重新编译内核）。
- 新公开 ImageBuilder 仓库：https://github.com/longtianhgg/king3288-imagebuilder，main=2acb3cc516dddd1edcd0149446a65850b1078272；包含 README、NOTICE、296 包清单、校验与 SD v3 封装工具。大型 ImageBuilder 二进制独立置于 Releases，不进入 Git 历史。
- 构建机从 M8 Standalone ImageBuilder 解包后执行新仓库 ./build.sh，**无需重新编译内核**，重建 296 包 rootfs 和完整 SD v3，manifest 完全一致，e2fsck/MBR/IDB/FAT/DTB/ext4 校验全通过（RC=0）。该轮 standalone SD 镜像 SHA256 eb0576eaa4cb45f797090509711d221555a1107d2931db55e1479bfb4388b8f3；与早期源码构建 gzip SHA 不同，两个镜像都已通过离线验证但 M8 新卡冷启动仍未做。
- `.github/workflows/build-king3288.yml`：公开仓库标准 ubuntu-24.04 GitHub Actions 免费运行器，push king3288 触发；限制 355min、默认只保留 1 天 artifact、发布 Release 要求显式触发；**首次云编译正在运行，结果尚未确认**。GitHub 标准 runner 14GB SSD，不能保证从零源码构建不会耗尽空间。
- 新发布的 CI 必须以 Actions 真正成功和新产物校验为准，不能以本地 M8 已通过去替代云编译验收。尚未上传任何私人 SSH 密码、私钥、设备配置到新提交。
