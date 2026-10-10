# ImmortalWrt云编译

使用 GitHub Actions 云编译 **ImmortalWrt** 固件。

基于 [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) 模板。

## 当前配置

| 项目 | 内容 |
|------|------|
| 源码 | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) `master` |
| 目标 | **x86_64 物理机**（Generic） |
| 刷机包 | `*-generic-ext4-combined-efi.img.gz`（UEFI）<br>`*-generic-ext4-combined.img.gz`（纯 BIOS） |
| 不会产出 | squashfs、ISO、rootfs.tar.gz、VMDK、VDI、VHDX、QCOW2 |
| 默认 IP | **10.0.0.1** |
| 首次登录密码 | **空**（直接回车） |
| 默认 Shell | **zsh** |
| Kernel 分区 | 16 MiB |
| RootFS 分区 | 2048 MiB (2GB) |
| BIOS Boot Partition | 1024k |

### 已集成插件
- **PassWall** (`luci-app-passwall`)
- **Lucky (sirpdboy 版)** (`luci-app-lucky`)
- **Fluent 主题** (`luci-theme-fluent`)
- **DiskMan** (`luci-app-diskman`)
- **DockerMan** (`luci-app-dockerman`)
- **PushBot 全能推送** (`luci-app-pushbot`)

## 使用方法

### 1. 开始编译

1. 打开仓库 **Actions** 页面
2. 选择 **ImmortalWrt云编译**
3. 点击 **Run workflow** → **Run workflow**
4. 等待 1.5~3 小时
5. 完成后在 Artifacts 或 Releases 下载固件

解压出 `.img` 后，用写盘工具**整盘写入**目标硬盘（不要写到某一个分区）。BIOS 里关掉 Secure Boot，启动模式选 UEFI。老 BIOS 机器用不带 `-efi` 的那一个。

### 2. 自定义修改

- `diy-part1.sh`：添加第三方源（已配置好）
- `diy-part2.sh`：修改 IP、分区、默认 shell、追加插件等
- `.github/workflows/openwrt-builder.yml`：可切换分支（如 `openwrt-24.10`）。上传前会丢掉非刷机包
- `.config`：已经是 x86_64 物理机配置，不要把虚拟机镜像选项再打开

## 登录信息

- 地址：http://10.0.0.1
- 用户名：`root`
- 密码：**空**

## License

MIT © P3TERX
