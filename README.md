# ImmortalWrt云编译

![私人订制固件 · 只支持 Intel 网卡](docs/notice-banner-v3.png)

使用 GitHub Actions 云编译 **ImmortalWrt** 固件。

基于 [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) 模板。

## 当前配置

| 项目 | 内容 |
|------|------|
| 源码 | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) `master` |
| 目标 | **x86_64 物理机**（Generic） |
| 网卡支持 | **仅 Intel**（Realtek 驱动已移除，详见顶部横幅） |
| 刷机包 | ext4 / squashfs 各两份：`combined-efi`（UEFI）和 `combined`（纯 BIOS） |
| 不会产出 | ISO、rootfs.tar.gz、单独的 rootfs.img、VMDK、VDI、VHDX、QCOW2 |
| 默认 IP | **10.0.0.1** |
| 默认端口 | LAN = `eth0`，WAN = `eth1` |
| 默认主题 | **Argon**（固件内另含 Bootstrap 及暗/亮变体，可在界面切换） |
| 默认 Shell | **zsh** |
| 界面语言 | 跟随浏览器（`lang='auto'`）：中文浏览器自动显示简体中文，无需手动切换 |
| Kernel 分区 | 16 MiB |
| RootFS 分区 | 2048 MiB (2GB) |
| GRUB 引导区 / 分区对齐 (ALIGN) | 1024k（1 MiB；兼顾 GRUB core.img 嵌入空间与 SSD/NVMe 对齐） |

## 已集成插件

- **Nikki** (`luci-app-nikki`) — 代理
- **Lucky** (`luci-app-lucky`)
- **Argon 主题** (`luci-theme-argon`) — 默认主题
- **DiskMan** (`luci-app-diskman`)
- **DockerMan** (`luci-app-dockerman`，含 `docker` / `dockerd` / `containerd` / `runc` 运行时)
- **UPnP / NAT-PMP** (`luci-app-upnp`)
- **PushBot 全能推送** (`luci-app-pushbot`)
- **SMB4 文件共享** (`luci-app-samba4`，含 wsdd2 Windows 网络发现）
- **ttyd 网页终端** (`luci-app-ttyd-strict`)
- **nlbwmon 带宽监控** (`luci-app-nlbwmon`)

**其他内置工具**：`htop` `nano` `vim` `tcpdump` `iperf3` `ethtool` `lspci` `lsusb` `lscpu` `lm-sensors` `smartctl`（硬盘健康检测） `curl` `wget-ssl`；存储工具 `fdisk` `parted` `mkfs.ext4` / `tune2fs` / `resize2fs`（e2fsprogs）、`block-mount`（分区自动挂载）；Shell 另含 `bash`（默认仍为 `zsh`）。

## 内置自动化功能

**首次启动自动配置**（配置写入系统，重启不丢失）：

- **光猫管理页访问**：WAN 口（eth1）自动配置 192.168.0.2 / 192.168.1.2 双网段地址，局域网可直接访问桥接光猫管理页（192.168.0.1 或 192.168.1.1），已并入 wan 防火墙区
- **时区**：出厂默认为 UTC 时自动设为北京时间（GMT+8）

**每次开机自动生效**：

- **型号**：LuCI 状态页「型号」显示为「畅网P2」（覆盖 DMI 探测结果；不动机型标识 board_name，不影响 sysupgrade）
- **CPU / 网络调优**（`/etc/rc.local`，面向 J4125 等入门级 x86）：调频固定为 `performance`；物理网卡的队列中断轮询分到各 CPU（掩码按实际核数自适应）；提高软中断积压上限（`netdev_max_backlog=2048`）。RPS/RFS 不在此设置，交由固件内置的 `packet_steering` 服务处理（它按 CPU 拓扑自适应分配并在接口事件后自动重应用）

**定时任务**（busybox crond，条目写入 `/etc/crontabs/root`）：

- **CoreMark 跑分**：使用 coremark 包自带机制 —— 首次开机登记 `0 4 * * *` 条目，**下一个凌晨 4:00 跑分一次**，跑完由脚本自动移除该条目（一次性）。分数写入 `/etc/bench.log`，由 LuCI 状态页**「型号」行**读取显示，形如 `畅网P2 (CpuMark : 12643.587331  Scores)`
- **磁盘 TRIM**：每周日**凌晨 6:00** 对支持 discard 的文件系统执行 `fstrim -a`（结果写入系统日志，`logread | grep fstrim` 可查）

**界面调整**：

- 状态页「本地时间」显示星期几、且不带时区后缀（`2026年10月15日星期四 08:29:05`）；勾选「系统 → 系统 → 完整时区名称」后显示完整时区名（如 `… 中国标准时间 08:29:05`）
- 状态页「架构」行显示 CPU 型号 / 核心线程 / 频率 / 温度（如 `Intel(R) Celeron(R) J4125 CPU @ 2.00GHz x 4 C 4 T (2000MHz, 45°C)`），由 `autocore` 包提供的 `/sbin/cpuinfo` 生成。该包自带的 RPS/RFS 与网卡 offload 调优**已在首次开机禁用**（避免与内置 `packet_steering` 互相覆盖），网络调优统一由后者负责

## 镜像版本差异

| | **ext4 版** | **squashfs 版** |
|---|---|---|
| 根文件系统 | ext4 直接挂载 | squashfs 只读层 + overlay（f2fs，挂载带 `discard`，自带 TRIM） |
| **恢复出厂** | ❌ **不支持** —— 实测 `firstboot -y` 报 `MTD partition 'rootfs_data' not found`（x86 ext4 无此分区） | ✅ **支持** —— LuCI「系统 → 备份/刷写固件 → 恢复出厂设置」，或 `firstboot -y && reboot` |
| 适合 | 需要直接改根分区内容 | 需要恢复出厂能力 / 自动 TRIM |

> - 恢复出厂只清空 overlay 配置层，**不影响**磁盘上自行划分的其他分区（如影音存储分区）。
> - **跨固件升级**（从其他固件换到本固件）务必取消「保留配置」勾选 —— 旧固件的整套 `/etc/config` 会被原样带过来（含 `/etc/board-base.json`，会阻止本固件重新生成默认配置），从而出现拿不到 IP 等异常。

## 登录信息

- 地址：http://10.0.0.1
- 用户名：`root`
- 密码：**空**

## License

MIT © P3TERX
