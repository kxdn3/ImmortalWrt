#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# 修改默认 IP 为 10.0.0.1
sed -i 's/192.168.1.1/10.0.0.1/g' package/base-files/files/bin/config_generate

# 默认主题改为 Argon（使用作者源 jerrykuku/luci-theme-argon 2.4.8，
# 已在 diy-part1.sh 中 clone 并移除官方 feed 同名包；fluent 仍保留可随时切回）
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 修改主机名（可选）
# sed -i 's/ImmortalWrt/MyRouter/g' package/base-files/files/bin/config_generate

# ========== 分区大小设置 ==========
# Kernel 分区 16 MiB
echo "CONFIG_TARGET_KERNEL_PARTSIZE=16" >> .config
# RootFS 分区 2048 MiB (2GB)
echo "CONFIG_TARGET_ROOTFS_PARTSIZE=2048" >> .config

# BIOS Boot Partition：源码默认是 256，强制改为 1024（避免 gdisk 警告）
sed -i 's/\t256$/\t1024/' target/linux/x86/image/Makefile
# 兼容可能存在的空格写法
sed -i 's/ 256$/ 1024/' target/linux/x86/image/Makefile

# ========== 默认 Shell 改为 zsh ==========
# 确保编译 zsh 包，并在首次启动时修改 root 的 shell
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-default-zsh << 'EOF'
#!/bin/sh
# 将 root 默认 shell 改为 zsh
if [ -x /usr/bin/zsh ]; then
    sed -i 's|/bin/ash|/usr/bin/zsh|g' /etc/passwd
fi
# ImmortalWrt 默认密码本就为空，这里确保保持为空
# （不设置密码即可）
exit 0
EOF
chmod +x files/etc/uci-defaults/99-default-zsh

# ========== 强制选中常用插件（在 .config 中追加） ==========
# 注意：这些需要你先有一个基础 .config（选择好目标设备），脚本会追加这些包
cat >> .config << 'EOF'

# === 用户要求的插件 ===
CONFIG_PACKAGE_luci-app-nikki=y
CONFIG_PACKAGE_nikki=y
CONFIG_PACKAGE_mihomo-meta=y
CONFIG_PACKAGE_luci-i18n-nikki-zh_Hans=y
CONFIG_PACKAGE_luci-app-lucky=y
CONFIG_PACKAGE_lucky=y
# CONFIG_PACKAGE_luci-theme-fluent is not set  # 默认主题为 argon
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-dockerman=y
CONFIG_PACKAGE_luci-app-pushbot=y
CONFIG_PACKAGE_ttyd=y
CONFIG_PACKAGE_luci-app-ttyd-strict=y
CONFIG_PACKAGE_luci-i18n-ttyd-strict-zh_Hans=y
CONFIG_PACKAGE_iputils-arping=y
CONFIG_PACKAGE_jq=y

# zsh 相关
CONFIG_PACKAGE_zsh=y
# CONFIG_PACKAGE_zsh-completions is not set  # 补全非必需

# 常用依赖/辅助
CONFIG_PACKAGE_docker=y
CONFIG_PACKAGE_dockerd=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_fdisk=y
CONFIG_PACKAGE_parted=y

# === SMB4 文件共享（用户要求，带中文界面 + Windows 网络发现）===
CONFIG_PACKAGE_luci-app-samba4=y
CONFIG_PACKAGE_samba4-server=y
CONFIG_PACKAGE_wsdd2=y
CONFIG_PACKAGE_luci-i18n-samba4-zh_Hans=y
CONFIG_PACKAGE_autosamba=y
EOF

# ========== 移除 coremark 包自带的「每天 4:00 跑分」定时任务 ==========
# coremark 包安装时会带上两个文件：
#   /etc/uci-defaults/xxx-coremark  首次开机往 /etc/crontabs/root 写入
#                                   "0 4 * * * /etc/coremark.sh"
#   /etc/coremark.sh                被上面那条 cron 调用的跑分脚本
# 而 busybox crond 在固件里是启用的（/etc/rc.d/S50cron），所以刷机后第一晚会跑两次
# CoreMark：4:00 包自带的 + 5:00 我们的 98_coremark_once（写 UCI + 主页显示）。
# 修复：改包 Makefile 的 install 段，不让这两个文件进入固件。
# 注意：feeds install 后 package/feeds/<feed>/<包名> 是符号链接，find 默认不跟随，
# 所以优先用 glob（能正确展开符号链接），再用 find -L 兜底。
CM_MK=$(ls package/feeds/*/coremark/Makefile 2>/dev/null | head -1)
[ -n "$CM_MK" ] || CM_MK=$(find -L package -maxdepth 5 -path "*coremark/Makefile" 2>/dev/null | head -1)
if [ -z "$CM_MK" ]; then
    echo "!! 未找到 coremark 包 Makefile，无法移除其自带的定时任务" >&2
    exit 1
fi
sed -i '\|INSTALL_BIN) \./coremark\.sh|d' "$CM_MK"
sed -i '\|INSTALL_BIN) \./coremark |d' "$CM_MK"
if grep -q 'INSTALL_BIN) \./coremark ' "$CM_MK"; then
    echo "!! coremark 包 install 段与预期不符（$CM_MK），请检查后再编译" >&2
    exit 1
fi
echo ">>> 已移除 coremark 包自带的 4:00 定时任务（避免与 5:00 一次性任务重复跑分）"

# ========== 主页「本地时间」去掉时区后缀（如 GMT+8）==========
# LuCI 状态页用 Intl.DateTimeFormat 渲染本地时间，timeStyle 取 'long'/'full' 时
# 会带上时区名（中文环境下 Asia/Shanghai 被渲染成 "GMT+8"），显示为：
#   "2026年10月15日 GMT+8 08:29:05"
# 改为 'medium' 后去掉时区名，只留日期+时分秒：
#   "2026年10月15日 08:29:05"
# 该文件由 luci-mod-status 包安装（构建时会被压缩），改 feed 源码即可让补丁随包进固件。
SYSJS=feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js
if [ -f "$SYSJS" ]; then
    sed -i "s/timeStyle: *(ts *== *0) *? *'long' *: *'full'/timeStyle: 'medium'/" "$SYSJS"
    if grep -q "timeStyle: 'medium'" "$SYSJS"; then
        echo ">>> 已去掉主页本地时间的时区后缀（GMT+8）"
    else
        echo "!! 10_system.js 补丁未生效（上游代码可能变动），请检查：$SYSJS" >&2
        exit 1
    fi
else
    echo "!! 未找到 $SYSJS，无法去掉本地时间的时区后缀" >&2
    exit 1
fi

# ==========
# 只保留 x86 物理机刷机包。追加在最后，覆盖前面可能打开的虚拟机镜像。
# ==========
cat >> .config << 'EOF'

# === 仅 x86 物理机整盘刷机镜像（ext4 + squashfs）===
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_DEVICE_generic=y
CONFIG_TARGET_ROOTFS_EXT4FS=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_TARGET_IMAGES_GZIP=y
CONFIG_GRUB_IMAGES=y
CONFIG_GRUB_EFI_IMAGES=y
# CONFIG_TARGET_ROOTFS_TARGZ is not set
# CONFIG_ISO_IMAGES is not set
# CONFIG_QCOW2_IMAGES is not set
# CONFIG_VDI_IMAGES is not set
# CONFIG_VMDK_IMAGES is not set
# CONFIG_VHDX_IMAGES is not set
# CONFIG_ONIE_INSTALLER_IMAGES is not set
EOF
