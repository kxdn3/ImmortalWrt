#!/bin/bash
#
# diy-part1.sh - Before Update feeds
#

# PassWall
echo 'src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main' >>feeds.conf.default
echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main' >>feeds.conf.default

# PushBot 全能推送
echo 'src-git pushbot https://github.com/zzsj0928/luci-app-pushbot.git' >>feeds.conf.default

# Fluent 主题
echo 'src-git fluent https://github.com/LazuliKao/luci-theme-fluent.git' >>feeds.conf.default

# Lucky（单独克隆到 package，避免与其他 feed 冲突）
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/luci-app-lucky
