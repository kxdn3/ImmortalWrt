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
| BIOS Boot Partition | 1024k |

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

首次启动自动执行一次（重启不丢失；恢复出厂后下次开机会自动重新配置）：

- **光猫管理页访问**：WAN 口（eth1）自动配置 192.168.0.2 / 192.168.1.2 双网段地址，局域网可直接访问桥接光猫管理页（192.168.0.1 或 192.168.1.1），已并入 wan 防火墙区
- **主机名**：预设为「畅网P2」
- **CoreMark 跑分**：首次启动后凌晨 5:00 自动跑分一次，分数显示在 LuCI 主页「CoreMark 跑分」卡片，跑完自动取消任务

## 登录信息

- 地址：http://10.0.0.1
- 用户名：`root`
- 密码：**空**

## License

MIT © P3TERX
