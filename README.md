# Actions-ImmortalWrt

使用 GitHub Actions 云编译 **ImmortalWrt** 固件。

基于 [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) 模板。

## 当前配置

| 项目 | 内容 |
|------|------|
| 源码 | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) `master` |
| 默认 IP | **10.0.0.1** |
| 首次登录密码 | **空**（直接回车） |
| 默认 Shell | **zsh** |
| Kernel 分区 | 16 MiB |
| RootFS 分区 | 2048 MiB (2GB) |
| BIOS Boot Partition | 1024k（源码默认） |

### 已集成插件
- **PassWall** (`luci-app-passwall`)
- **Lucky** (`luci-app-lucky`)
- **Fluent 主题** (`luci-theme-fluent`)
- **DiskMan** (`luci-app-diskman`)
- **DockerMan** (`luci-app-dockerman`)
- **PushBot 全能推送** (`luci-app-pushbot`)

## 使用方法

### 1. 准备 `.config` 文件（必须）

当前仓库的 `.config` 是空的，你需要先生成一个针对你设备的配置：

1. 本地或用 GitHub Codespaces / 其他编译环境克隆 ImmortalWrt
2. 执行 `./scripts/feeds update -a && ./scripts/feeds install -a`
3. `make menuconfig` 选择你的目标设备（例如 x86_64）
4. 把生成的 `.config` 上传覆盖仓库根目录的 `.config`

或者在 Actions 中开启 SSH（修改 workflow 添加 tmate）进行在线 `make menuconfig`。

### 2. 开始编译

1. 打开仓库 **Actions** 页面
2. 选择 **OpenWrt Builder**
3. 点击 **Run workflow** → **Run workflow**
4. 等待 1.5~3 小时
5. 完成后在 Artifacts 或 Releases 下载固件

### 3. 自定义修改

- `diy-part1.sh`：添加第三方源（已配置好）
- `diy-part2.sh`：修改 IP、分区、默认 shell、追加插件等
- `.github/workflows/openwrt-builder.yml`：可切换分支（如 `openwrt-24.10`）

## 登录信息

- 地址：http://10.0.0.1
- 用户名：`root`
- 密码：**空**

## License

MIT © P3TERX
