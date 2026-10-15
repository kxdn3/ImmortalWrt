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
| 默认主题 | **Argon** |
| 默认 Shell | **zsh** |
| Kernel 分区 | 16 MiB |
| RootFS 分区 | 2048 MiB (2GB) |
| 分区对齐 (ALIGN) | 1024k（避免 gdisk 对齐告警） |

## 已集成插件

- **Nikki** (`luci-app-nikki`) — 代理
- **Lucky** (`luci-app-lucky`)
- **Argon 主题** (`luci-theme-argon`) — 默认主题
- **DiskMan** (`luci-app-diskman`)
- **DockerMan** (`luci-app-dockerman`)
- **PushBot 全能推送** (`luci-app-pushbot`)
- **SMB4 文件共享** (`luci-app-samba4`，含 wsdd2 Windows 网络发现）
- **ttyd 网页终端** (`luci-app-ttyd-strict`)
- **nlbwmon 带宽监控** (`luci-app-nlbwmon`)

## 内置自动化功能

**首次启动自动配置**（配置写入系统，重启不丢失）：

- **光猫管理页访问**：WAN 口（eth1）自动配置 192.168.0.2 / 192.168.1.2 双网段地址，局域网可直接访问桥接光猫管理页（192.168.0.1 或 192.168.1.1），已并入 wan 防火墙区
- **时区**：出厂默认为 UTC 时自动设为北京时间（GMT+8）
- **CoreMark 跑分**：首次启动后凌晨 5:00 自动跑分一次，分数显示在 LuCI 主页「CoreMark 跑分」卡片，跑完自动取消任务

**每次开机自动生效**：

- **型号**：LuCI 状态页「型号」显示为「畅网P2」（覆盖 DMI 探测结果；不动机型标识 board_name，不影响 sysupgrade）

**定时任务**（micrond）：

- **磁盘 TRIM**：每周日凌晨 6:00 对支持 discard 的文件系统执行 `fstrim -a`（结果写入系统日志，`logread | grep fstrim` 可查）

**界面调整**：

- 状态页「本地时间」显示星期几、且不带时区后缀（`2026年10月15日星期四 08:29:05`）；勾选「系统 → 系统 → 完整时区名称」后显示完整时区名（如 `… 中国标准时间 08:29:05`）

## 登录信息

- 地址：http://10.0.0.1
- 用户名：`root`
- 密码：**空**

## License

MIT © P3TERX
