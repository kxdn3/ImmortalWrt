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

# 默认主题改为 Fluent（如果编译了该主题）
# sed -i 's/luci-theme-bootstrap/luci-theme-fluent/g' feeds/luci/collections/luci/Makefile

# 修改主机名（可选）
# sed -i 's/ImmortalWrt/MyRouter/g' package/base-files/files/bin/config_generate

# ========== 分区大小设置 ==========
# Kernel 分区 16 MiB
echo "CONFIG_TARGET_KERNEL_PARTSIZE=16" >> .config
# RootFS 分区 2048 MiB (2GB)
echo "CONFIG_TARGET_ROOTFS_PARTSIZE=2048" >> .config
# BIOS Boot Partition 已在现代源码中默认 1024k，无需额外设置

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
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-app-lucky=y
CONFIG_PACKAGE_luci-theme-fluent=y
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-dockerman=y
CONFIG_PACKAGE_luci-app-pushbot=y

# zsh 相关
CONFIG_PACKAGE_zsh=y
CONFIG_PACKAGE_zsh-completions=y

# 常用依赖/辅助
CONFIG_PACKAGE_docker=y
CONFIG_PACKAGE_dockerd=y
CONFIG_PACKAGE_luci-lib-docker=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_fdisk=y
CONFIG_PACKAGE_parted=y
EOF
