#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Add a feed source
# PassWall
echo 'src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages' >>feeds.conf.default
echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default

# Lucky
echo 'src-git lucky https://github.com/gdy666/luci-app-lucky' >>feeds.conf.default

# PushBot (全能推送)
echo 'src-git pushbot https://github.com/zzsj0928/luci-app-pushbot' >>feeds.conf.default

# Fluent Theme
echo 'src-git fluent https://github.com/LazuliKao/luci-theme-fluent' >>feeds.conf.default

# 常用额外插件源 (diskman / dockerman 等)
echo 'src-git kenzok8 https://github.com/kenzok8/openwrt-packages' >>feeds.conf.default
