# KING3288 / RK3288 — iStoreOS 24.10.8

本分支对应 KING3288（RK3288 ARMv7 / 2GiB RAM）的 iStoreOS 24.10.8 / Linux 6.6.144 源码适配，非 iStoreOS 官方设备支持。

## 已验证功能

- 原厂 U-Boot → SD p1 FAT32/extlinux → zImage + KING3288 DTB → SD p2 ext4，生产 eMMC 不写。
- GMAC RGMII / RTL8211E PHY@0 / TX delay 0x30 / RX delay 0x10 / TX PBL=1，100Mbps 2.45GB 文件传输双端 SHA256 相同，TX/RX checksum on。
- LuCI/iStore、QuickStart、OpenClash/Mihomo、Tailscale、Docker 等共 296 个软件包集成入源码（**不表示所有服务均已端到端实机测试**）。
- Linux 6.6.144、完整 SD v3、ImageBuilder 源码构建成功，SD v3 全盘离线验证成功，ImageBuilder 重建 rootfs 的 296 包 manifest 完全一致。
- 已有 M7 v1 SD 镜像实机冷启动和 SD p2 扩容验证；**M8 v3 尚未进行新卡冷启动验收**。

## Ubuntu 24.04 编译

~~~bash
git clone -b king3288 https://github.com/longtianhgg/arm-istoreos.git
cd arm-istoreos

sudo apt update
sudo apt install -y build-essential clang flex bison gawk gcc-multilib g++-multilib gettext \
  git libncurses-dev libssl-dev libelf-dev python3 python3-dev python3-setuptools \
  rsync subversion swig unzip zlib1g-dev file wget curl bc time xsltproc zstd \
  ccache libfuse-dev libglib2.0-dev libpixman-1-dev device-tree-compiler \
  fakeroot fdisk dosfstools mtools e2fsprogs pigz jq

cp king3288-configs/m3-feeds.lock feeds.conf
./scripts/feeds update -a
./scripts/feeds install -a
cp king3288-configs/m8-txpbl1-imagebuilder.diffconfig .config
make defconfig
make download -j4
make -j4

bash king3288-tools/build-king3288-sd-image-txpbl1-v3.sh
bash king3288-tools/validate-king3288-sd-image-txpbl1-v3.sh
~~~

构建出现在：`bin/targets/rockchip/armv7/`，包括完整 SD `*txpbl1-v3.img.gz`、Standalone ImageBuilder `*.tar.zst` 及 296 包 manifest。

## Cloud CI

`.github/workflows/build-king3288.yml` 使用公开仓库免费的标准 Ubuntu 24.04 x64 runner。仅针对 king3288 分支有关文件 push 触发，保留产物 1 天；可选手工发 Release。标准 runner 免费，但受 14GB 磁盘及 6 小时任务上限约束，**云端从零构建尚待验证**，具体状态请以 Actions 日志为准。

## IDB 和安全边界

`king3288-blobs/king3288-idb-miniloader.bin`（105472 字节；SHA256 `84c08dd990738c1e935f86206a062aa75effc1148039328b5aa1722db818f8e3`）源于先前验证可启动的 KING3288 SD IDB，供离线制作 SD 镜像；不保证适用于其它 RK3288 板，不会改写生产 eMMC 或原厂 U-Boot。

完整 SD 为 MBR + FAT32 p1（1GiB）+ ext4 p2（2GiB），可在新刷 SD 上使用安全扩容脚本扩展至卡尾。不可把整盘 SD 镜像直接写到 eMMC。

单独 ImageBuilder 仓库：[king3288-imagebuilder](https://github.com/longtianhgg/king3288-imagebuilder)。

仓库继承 iStoreOS/OpenWrt 和各第三方组件原许可证；不要加入私人配置、订阅、密钥、签名私钥。
