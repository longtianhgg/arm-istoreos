# Orange Pi Zero 3 - iStoreOS 25.12.6 固件

本项目基于 **iStoreOS 25.12**（OpenWrt 25.12.6，Linux Kernel 6.12.112）针对 **香橙派 Orange Pi Zero 3** 单板电脑进行了深度适配，支持全新的 **apk 包管理器**、**内核内建 BTF**、**单臂旁路由优化**，并原生就绪支持 **[honk](https://github.com/daeuniverse/honk)** 与 **[dae](https://github.com/daeuniverse/dae)** eBPF 透明代理引擎。

---

## 一、 设备硬件情况

| 项目 | 规格 |
| :--- | :--- |
| **设备型号** | 迅龙 香橙派 Orange Pi Zero 3 (Xunlong Orange Pi Zero 3) |
| **主控芯片 (SoC)** | 全志 Allwinner H618 (4 核 ARM Cortex-A53 @ 1.5GHz) |
| **内存 (RAM)** | 1GB / 1.5GB / 2GB / 4GB LPDDR4（均自适应支持） |
| **有线网卡** | Motorcomm YT8531C 千兆以太网 (10/100/1000Mbps) |
| **无线网络** | 板载 WiFi 5 + BT 5.0 (CDW-20U5622 / AW859A) |
| **网口数量** | 单网口（默认预设为单臂旁路由模式，接入主路由局域网） |
| **存储介质** | MicroSD / TF 卡 |

---

## 二、 适配的核心功能与技术特性

### 1. 系统与基础架构
- **系统版本**：iStoreOS 25.12.6（对应 OpenWrt 25.12.6，包管理器全面迁移为 **apk**）。
- **内核版本**：Linux Kernel **6.12.112**，默认开启 `CONFIG_NETKIT=y`（针对 BPF 的虚拟网卡对支持）。
- **硬件专属修复**：
  - **YT8531C 网卡千兆防休眠与 PLL 锁定补丁**：彻底杜绝大流量传输时偶发断网或降速至百兆的问题。
  - **关闭板载 SPI0**：规避 Allwinner SPI 控制器在部分内核版本下的初始化崩溃。
- **三分区 SD 镜像架构**：
  - `p1` (32MB FAT32 Boot)：存放 FIT 格式压缩内核与设备树。
  - `p2` (512MB SquashFS RootFS)：只读系统底包，安全稳定。
  - `p3` (2GB ext4 Overlay，带 `RESET000` 标记)：独立可读写用户数据分区，可在 Web 后台通过 `磁盘扩容 (PartExp)` 一键扩容至整张 TF 卡容量。
  - 定制 `platform.sh`：升级固件时支持完整保留 `p3` Overlay 数据。

### 2. 内核内建 BTF 与 eBPF 透明代理就绪（honk / dae）
- **内核原生内建 BTF (`/sys/kernel/btf/vmlinux`)**：
  - 开启 `CONFIG_KERNEL_DEBUG_INFO_BTF=y` 与 `CONFIG_DWARVES=y`。
  - 彻底摆脱官方 OpenWrt 外置 `vmlinux-btf` 对 `vermagic`（内核版本与签名指纹）严格校验的限制，无需依赖第三方为自编译固件构建 kmod。
  - 完美契合 `@daeuniverse` 的 `vmlinux-btf-builtin` 依赖机制。
- **预装所有必需的内核模块 (kmods)**：
  - `kmod-sched-core` & `kmod-sched-bpf`（激活 TCX 与 TC-BPF 数据路径）
  - `kmod-veth`（`dae0` / `daens` 虚拟网络命名空间链路支持）
  - `kmod-nft-core`、`kmod-nft-queue`、`kmod-nfnetlink-queue`（`honk` 必需的 NFQUEUE 320 首包防丢队列支持）
  - `kmod-nf-conntrack`
- **预置规则包与运行时支持**：
  - 固件预装 `v2ray-geoip` 与 `v2ray-geosite`，刷机后直接生效。
  - 预装 `libstdcpp`、`ca-bundle`、`flock`、`coreutils-timeout`（运行 `honk` 及 `luci-app-honk` 必需）。

### 3. 单臂旁路由（Single-Arm Gateway）网络深度优化
- **保留原生 `br-lan` 桥接设备**：默认开机以 DHCP 客户端模式向上游主路由获取 IP，自动禁用自身的 DHCP Server / IPv6 RA 服务，即插即用不扰乱现有局域网。
- **内核网络参数优化** (`/etc/sysctl.d/60-honk-single-arm.conf`)：
  - 全局与 `br-lan` 接口关闭 `send_redirects`：防止单臂网关向局域网终端发送 ICMP 重定向，杜绝流量绕过透明代理。
  - 全局与 `br-lan` 接口关闭 `rp_filter`（反向路径过滤）：防止被代理的非对称路由报文被 Linux 内核直接丢弃。

### 4. 丰富内置应用与体验
- **iStore 应用商店生态**：支持一键安装各种扩展插件。
- **Docker 容器环境**：内置 Docker、Dockerman、containerd，充分发挥 2GB/4GB 内存性能。
- **LuCI 界面**：预装 Argon 主题、快速向导 (QuickStart)、网络向导 (NetWizard)、分区扩容 (PartExp)、安全关机 (PowerOff) 等。

---

## 三、 固件编译指南

### 方式一：本地编译

在 Ubuntu 22.04 / 24.04 等 Linux 环境下：

```bash
# 1. 克隆本仓库并切换到专用分支
git clone http://192.168.50.2:4000/Dragon/arm-istoreos.git -b orangepi-zero3-2512opencode
cd arm-istoreos

# 2. 更新并安装依赖 feed
./scripts/feeds update -a
./scripts/feeds install -a

# 3. 载入 Orange Pi Zero 3 专属配置并展开依赖
cp configs/orangepi-zero3-2512opencode.config .config
make defconfig

# 4. 下载依赖源码包
make download -j$(nproc)

# 5. 开始多线程编译
make -j$(nproc)
```

> 若编译遇到异常，可执行 `make -j1 V=s` 输出完整日志排查。  
> 编译产物位于：`bin/targets/sunxi/cortexa53/istoreos-25.12.6-sunxi-cortexa53-xunlong_orangepi-zero3-squashfs-sdcard.img.gz`。

### 方式二：GitHub Actions 云端全自动编译与发布

本项目自带自动化 CI 工作流（`.github/workflows/build-orangepi-zero3.yml`）：
1. 将分支推送到您的 GitHub 远程仓库：
   ```bash
   git push origin orangepi-zero3-2512opencode
   ```
2. 进入 GitHub 仓库页面的 **Actions** 标签页，点击 **Build & Release Orange Pi Zero 3 iStoreOS 25.12**。
3. 点击 **Run workflow**，选择 `orangepi-zero3-2512opencode` 分支触发编译。
4. 构建成功后，镜像及独立的 ImageBuilder 离线包将直接发布在 GitHub **Releases** 中。

### 方式三：使用 ImageBuilder 工具包在任意 Linux 主机极速二次打包（推荐，15秒完成）

如果您已有现成的 ImageBuilder 工具包（如 `opi-zero3-ib-kit.tar.gz`），可以在任何 x86_64 Linux 机器（包括 NAS、Debian、Ubuntu、fnOS、PVE 等）上**免源码、免长耗时编译**，仅需 15 秒重新组装固件：

1. 解压工具包与 ImageBuilder：
   ```bash
   tar -xzvf opi-zero3-ib-kit.tar.gz
   cd ib-bundle
   tar --zstd -xvf istoreos-imagebuilder-sunxi-cortexa53.Linux-x86_64.tar.zst
   cd istoreos-imagebuilder-sunxi-cortexa53.Linux-x86_64
   touch repositories
   ```
2. 下载额外插件（Tailscale 与 honk 全家桶）并建立索引：
   ```bash
   cd packages
   wget -nc https://downloads.openwrt.org/releases/25.12.6/packages/aarch64_cortex-a53/packages/tailscale-1.104.1-r1.apk
   BASE_URL="https://openwrt.daeuniverse.org/25.12/packages/aarch64_cortex-a53"
   for pkg in honk luci-app-honk luci-lib-daeuniverse luci-i18n-daeuniverse-zh-cn vmlinux-btf-builtin; do
     FILE=$(curl -sL "$BASE_URL/" | grep -oE "${pkg}-[0-9][^\"]*\\.apk" | head -n1)
     [ -n "$FILE" ] && wget -nc "$BASE_URL/$FILE"
   done
   cd ..
   make _check_keys
   make package_index
   ```
3. 一键极速打包：
   ```bash
   ALL_PKGS=$(cat ../istoreos-sunxi-cortexa53-xunlong_orangepi-zero3.manifest | cut -d' ' -f1 | tr '\n' ' ')
   EXTRA_PKGS="tailscale honk luci-app-honk luci-lib-daeuniverse luci-i18n-daeuniverse-zh-cn vmlinux-btf-builtin"
   make image PROFILE=xunlong_orangepi-zero3 PACKAGES="$ALL_PKGS $EXTRA_PKGS" FILES="../files"
   ```

> 详细目录层级解析、避坑指南及进阶定制请参阅独立文档：[IMAGEBUILDER_GUIDE.md](IMAGEBUILDER_GUIDE.md)。

---

## 四、 刷机与使用步骤

### 1. 刷写固件到 SD 卡
1. 下载或解压编译生成的固件 `...orangepi-zero3-squashfs-sdcard.img.gz`。
2. 使用 **BalenaEtcher**、**Raspberry Pi Imager** 或 **Rufus** 等工具将固件写入一张 MicroSD 卡（建议 Class 10 / A1 及以上规格）。
3. 将写好的 SD 卡插入香橙派，插上网线连接到主路由 LAN 口，连接 Type-C 电源（建议 5V/2A 及以上）开机。

### 2. 访问系统
- **网络模式**：默认作为旁路由运行，系统开机会自动向主路由申请 IP。
- **查找 IP**：登录上级主路由后台，在客户端列表中查找主机名为 `OrangePi-Zero3` 的设备 IP（例如 `192.168.1.150`）。
- **登录后台**：
  - 浏览器打开 `http://192.168.1.150/`
  - 默认用户名：`root`
  - 默认密码：`password`

### 3. 一键扩容用户存储空间
进入后台后，点击 **系统 -> 磁盘扩容 (PartExp)**，选择存储卡未分配的空间一键扩容，重启后即可充分利用 SD 卡全部容量安装 Docker 镜像和容器应用。

---

## 五、 安装与启用 honk 透明代理 (含 doona Web 面板)

固件内核已经完全具备所有依赖与 BTF 特性，您只需按以下 4 步即可在线安装并启用 `honk`：

### 1. 导入 daeuniverse 签名公钥
在香橙派的终端中（或通过后台 **系统 -> TTYD 终端**）执行：
```sh
wget -O /etc/apk/keys/daeuniverse.pem https://openwrt.daeuniverse.org/public-key.pem
```

### 2. 添加 daeuniverse 软件源
```sh
. /etc/openwrt_release
FEED=https://openwrt.daeuniverse.org/$(echo "$DISTRIB_RELEASE" | cut -d. -f1-2)
cat > /etc/apk/repositories.d/daeuniverse.list <<EOF
@daeuniverse $FEED/packages/$DISTRIB_ARCH/packages.adb
EOF
apk update
```
> *注：由于本固件内核已经内建 BTF，无需（也不要）添加官方的 `kmods` 仓库。*

### 3. 安装 honk 引擎与中文管理面板
```sh
apk add honk@daeuniverse luci-app-honk@daeuniverse luci-i18n-daeuniverse-zh-cn@daeuniverse
```

### 4. 启用服务并开始使用
```sh
/etc/init.d/honk enable
/etc/init.d/honk start
```

- **doona 独立 Web 面板**：在局域网电脑直接访问 `http://<香橙派IP>:9527/`（首次访问创建管理员账号，登录后可在线配置节点、订阅及规则）。
- **LuCI 控制页面**：可在 OpenWrt 后台通过 **服务 -> honk** 页面查看运行状态、服务日志与直接打开 doona 面板。
- **终端客户端配置**：将局域网需要走代理的电脑/手机的 **网关 (Gateway)** 和 **DNS** 设为香橙派的 IP 即可畅享 eBPF 透明加速。
