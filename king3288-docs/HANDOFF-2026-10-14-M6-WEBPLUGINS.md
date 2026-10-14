# KING3288 原生 iStoreOS — M6 常用 Web 插件补齐（2026-10-14）

## 基线与执行范围
- 全工程总基线：Project `KING3288_HANDOFF.md` §25；子基线 `KING3288_OPENWRT_ADAPTATION_HANDOFF.md` §11；承接原生仓库 Git `13b8124b73`（Docker 默认内置、新刷镜像首启 DHCP 客户端）。
- 仓库：`/home/dragon/king3288-build/king3288-istoreos`，`king3288-istoreos-24.10`，iStoreOS 24.10.8 / Linux 6.6.144 / ARMv7 musl OPKG。
- **当前正在运行的 SD** 仍是 M3 rootfs + M5 在线安装包，LAN 由用户手动设置为静态 `192.168.50.202/24`、网关和 DNS `192.168.50.3`、DHCP 服务器关闭。当前 SD/eMMC/U-Boot/Trust/网络配置**均未操作**。
- 用户新镜像目标：第一次启动 LAN DHCP 客户端，关闭本机 DHCP 服务；之后用户手动静态旁路由设置持久化，不在每次启动时重设；允许 Docker 修改防火墙规则。SD p2 自动扩容仍在其他软件包适配后，等待用户 Orange Pi 脚本。

## 本轮完成：5 个常用 Web 与国际化包
- 与 Zero3 保存的 `configs/orangepi-zero3-final-packages.txt` 的 157 项清单逐项对比：Docker 默认集成后 **129/157**；本轮完成后 **134/157**。其余 23 项多数为 Btrfs/RAID 相关依赖，用户已决定不强制移植，另外剩 `luci-app-netwizard`/中文（可能重复 QuickStart）、`luci-app-partexp`/中文（安全 SD 扩容阶段再处理）、`kmod-button-hotplug`。
- 新增并默认内置：`luci-app-ttyd`、`luci-i18n-ttyd-zh-cn`、`luci-app-poweroffdevice`、`luci-i18n-poweroffdevice-zh-cn`、`istoreos-intl`。原来的 `ttyd` 后台服务已经是 rootfs 内置，这次只补 Web UI/中文。
- Zero3 复制的 `package/custom/luci-app-poweroffdevice/root/usr/share/rpcd/acl.d/luci-app-poweroffdevice.json` 原始内容有两处不合法的尾逗号；仅删除这两处逗号，`json.loads` 通过，权限策略本身保持不变。该插件在 Web 界面由用户主动点击并二次确认后才向 `/sbin/poweroff` 发请求；仅完成离线源/菜单/ACL 验收，未实机点击测试。
- 源码配置审计：`CONFIG_PACKAGE_*=y` 从 **306 → 311**，仅新增上述 5 项，原有 306 项完全保留，无新增 `kmod`、Btrfs、RAID、mdadm 或 startdhns。
- 主机完整编译 `make -j4`，`build_dir/king3288-m6-webplugins/fullbuild.rc` 显示 `M6_WEB_PLUGINS_FULLBUILD_RC=0`；5 个 IPK 均生成。
- 目标 rootfs manifest **296** 个实际包；全部新增包进入 manifest；压缩文件 **147,027,070 bytes**、SHA256 `a3547ed7cb8e8b152bfdc2488c3feaa8884b81d447b877a78041036a34bbd2ff`，`gzip -t` 通过。
- 用 Python 从实际 rootfs tar.gz 读取验证：关机与 ttyd LuCI 菜单文件存在、关机 rpcd ACL 能被严格 JSON 解析、原有 QuickStart `S92quickstart`、OpenClash/Mihomo、Tailscale、Docker/Dockerman 均存在；新镜像板级 `ucidef_set_interface_lan 'eth0' 'dhcp'`、`90-king3288-firstboot-lan-docker` 一次性关闭 DHCPv4/DHCPv6/RA、`99-king3288-tailscale-disabled` 均保留。
- 可复现配置 `king3288-configs/m6-webplugins.diffconfig`；本轮编译和前置快照 `build_dir/king3288-m6-webplugins/`；校验输出 `/tmp/king3288-m6-webplugins-validate.log`；校验程序 `/tmp/king3288-m6-webplugins-validate.py`。

## 后续和验收边界
- 仅证明 ARMv7 编译、rootfs 包、菜单和 JSON ACL 正确，**没有刷 SD 或实机打开页面**，不能声称关机、ttyd Web 终端已在开发板上通过运行验证。
- `luci-app-netwizard` 会修改网络设置，须核对与 QuickStart 手动向导的重复和触发机制再决定是否默认内置；用户当前静态配置不得更改。`luci-app-partexp` 属于 SD 分区扩容风险功能，留 M7 安全扩容时与用户 Orange Pi 脚本一起处理，不自动操作分区。
- 后续 M6 可按需求继续基础网络监控/备份/IPv6 或 USB 普通存储；NAS/RAID/Btrfs 非强制；M7/M8 按用户顺序执行。
