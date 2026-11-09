# Orange Pi Zero 3 - ImageBuilder 新主机使用与定制指南

本指南用于在任意新的 Linux x86_64 主机（如 Debian、Ubuntu、fnOS、PVE、物理机或 VPS）上，使用预打包的 ImageBuilder 工具包快速离线组装出定制的 **Orange Pi Zero 3 - iStoreOS 25.12.6** 固件。

整个打包过程在本地完成，**免去长达数小时的源码全编译**，仅需 **10~15 秒** 即可生成包含所有定制补丁与插件的完整刷机镜像。

---

## 一、 环境依赖准备

在新主机上，只需安装最基本的解压和网络工具：

```bash
# Debian / Ubuntu / fnOS / Proxmox VE
sudo apt update && sudo apt install -y zstd tar wget curl

# CentOS / RHEL / Fedora
# sudo dnf install -y zstd tar wget curl

# Arch Linux
# sudo pacman -S --needed zstd tar wget curl
```

---

## 二、 目录结构与层级关系

获取并解压分发包（如 `opi-zero3-ib-kit.tar.gz`）：

```bash
tar -xzvf opi-zero3-ib-kit.tar.gz
cd ib-bundle
```

`ib-bundle` 内部包含以下核心文件：

```text
ib-bundle/
├── files/                                               <- 定制根文件系统覆盖层 (sysctl 旁路由优化、Docker 菜单修正等)
│   ├── etc/
│   │   ├── sysctl.d/60-honk-single-arm.conf             <- 关闭 send_redirects 与 rp_filter
│   │   └── uci-defaults/99-bypass-router                <- 旁路由初始网络配置
│   ├── usr/share/luci/menu.d/luci-app-dockerman.json    <- Docker 一级菜单规范化 (order: 35)
│   └── www/luci-static/resources/dockerman/common.js    <- Docker 路由重定向到 admin/docker
├── istoreos-sunxi-cortexa53-xunlong_orangepi-zero3.manifest <- 323 个官方基础软件包清单
└── istoreos-imagebuilder-sunxi-cortexa53.Linux-x86_64.tar.zst <- ImageBuilder 核心构建包
```

解压 ImageBuilder 核心压缩包：

```bash
tar --zstd -xvf istoreos-imagebuilder-sunxi-cortexa53.Linux-x86_64.tar.zst
cd istoreos-imagebuilder-sunxi-cortexa53.Linux-x86_64
touch repositories
```

> **注意目录层级**：此时位于 `ib-bundle/istoreos-imagebuilder-sunxi-cortexa53.Linux-x86_64`，其上一级 `..` 即为 `ib-bundle`，包含 `files/` 和 `.manifest`。

---

## 三、 下载扩展包并更新签名索引

固件除了系统默认的 323 个基础包外，还集成了：
- **Tailscale** 异地组网工具
- **honk** 与 **luci-app-honk** eBPF 透明代理全家桶
- **vmlinux-btf-builtin**（声明内核已内建 BTF）

进入 `packages` 目录进行下载与签名：

```bash
# 1. 切换到 packages 目录
cd packages

# 2. 下载 Tailscale (OpenWrt 官方发布源)
wget -nc https://downloads.openwrt.org/releases/25.12.6/packages/aarch64_cortex-a53/packages/tailscale-1.104.1-r1.apk

# 3. 动态获取并下载 daeuniverse 官方最新软件包 (自动适配滚动更新哈希，杜绝 404)
BASE_URL="https://openwrt.daeuniverse.org/25.12/packages/aarch64_cortex-a53"
for pkg in honk luci-app-honk luci-lib-daeuniverse luci-i18n-daeuniverse-zh-cn vmlinux-btf-builtin; do
  FILE=$(curl -sL "$BASE_URL/" | grep -oE "${pkg}-[0-9][^\"]*\\.apk" | head -n1)
  if [ -n "$FILE" ]; then
    echo "正在下载最新版本: $FILE ..."
    wget -nc "$BASE_URL/$FILE"
  else
    echo "未解析到软件包: $pkg，请检查网络"
  fi
done

# 4. 生成本地 apk 包索引
../staging_dir/host/bin/apk mkndx --allow-untrusted --output packages.adb *.apk

# 5. 使用本地 ImageBuilder 私钥对索引签名
../staging_dir/host/bin/apk --allow-untrusted adbsign --sign-key ../keys/local-private-key.pem packages.adb

# 6. 返回 ImageBuilder 根目录
cd ..
```

---

## 四、 一键组装固件 (极速打包)

在 `istoreos-imagebuilder-sunxi-cortexa53.Linux-x86_64` 目录下执行：

```bash
# 1. 提取官方 323 个基础软件包列表
ALL_PKGS=$(cat ../istoreos-sunxi-cortexa53-xunlong_orangepi-zero3.manifest | cut -d' ' -f1 | tr '\n' ' ')

# 2. 追加额外打包的组件
EXTRA_PKGS="tailscale honk luci-app-honk luci-lib-daeuniverse luci-i18n-daeuniverse-zh-cn vmlinux-btf-builtin"

# 3. 执行 ImageBuilder 构建
make image \
  PROFILE=xunlong_orangepi-zero3 \
  PACKAGES="$ALL_PKGS $EXTRA_PKGS" \
  FILES="../files"
```

大约等待 10~15 秒，终端将提示镜像构建完成。

---

## 五、 构建产物与固件验证

构建生成的固件文件位于：
```bash
bin/targets/sunxi/cortexa53/istoreos-25.12.6-sunxi-cortexa53-xunlong_orangepi-zero3-squashfs-sdcard.img.gz
```

### 固件特性确认：
1. **体积**：约 108 MB。
2. **软件包总数**：329 个（323 个系统全功能基础包 + 6 个扩展包）。
3. **内核内建 BTF**：内核已内建 `/sys/kernel/btf/vmlinux`，完全无需安装会引发 vermagic 冲突的外部 `vmlinux-btf` kmod。
4. **单臂网关优化**：包含 `/etc/sysctl.d/60-honk-single-arm.conf`，已关闭 `send_redirects` 和 `rp_filter`，避免流量重定向或被内核丢包。
5. **Docker 菜单规范化**：
   - Docker 位于顶层一级导航（小鲸鱼图标）。
   - 菜单权重 `order: 35`，规范排列在 **iStore (31)** 与 **服务 (40)** 之间。
   - 所有子链接与重定向正常指向 `admin/docker`。

---

## 六、 常见问题与避坑指南 (FAQ)

### Q1: 运行 `../staging_dir/host/bin/apk` 提示 `No such file or directory`？
- **原因**：当前终端所处目录不正确。
- **解决**：该相对路径是专为在 `packages` 子目录下执行而设计的。请先确认 `pwd`：
  - 如果在 `packages` 目录，执行：`../staging_dir/host/bin/apk ...`
  - 如果在 ImageBuilder 根目录，执行：`./staging_dir/host/bin/apk ...`

### Q2: 下载 `luci-app-honk` 等包时报 HTTP 404？
- **原因**：`daeuniverse` 官方仓库的 LuCI 插件采用每日自动构建与滚动发布机制，包名中的 Git commit hash（如 `~6742962`、`~546cb35`）会不定期更新，硬编码旧链接会失效。
- **解决**：使用本文档“第三节”提供的动态 `curl | grep` 循环命令，自动解析上游当前最新的包名并下载。

### Q3: 打包时报错 `Failed to open repositories: No such file or directory`？
- **原因**：新版本 apk 构建时会检查当前目录是否存在 `repositories` 文件。
- **解决**：在 ImageBuilder 根目录下执行 `touch repositories` 创建空文件即可消除该报错。

### Q4: 如何烧录固件？
- 使用 **BalenaEtcher**、**Raspberry Pi Imager** 或 **Rufus** 将生成的 `.img.gz` 直接烧录到 MicroSD 卡即可，无需手动解压。
- 首次开机香橙派通过 DHCP 从主路由获取 IP，访问后台后使用 **系统 -> 磁盘扩容 (PartExp)** 即可一键扩展可读写空间。
