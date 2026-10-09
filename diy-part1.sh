#!/bin/bash
#
# diy-part1.sh - Before Update feeds
#
# 参考 OpenWrt-x86/diy-mini.sh：
# 第三方仓库如果不是标准 feed（包在子目录），就直接克隆到 package/。
# 不要写成 src-git，否则 ./scripts/feeds update 会失败：
#   - xiaorouji/openwrt-passwall 已迁到 Openwrt-Passwall 组织，旧地址 404
#   - pushbot 仓库根目录就是 Makefile，当 feed 索引会报
#     "target pattern contains no '%'"
#
set -e

clone_pkg() {
    local repo="$1"
    local dir="$2"
    local attempt

    echo ">>> Clone $repo -> $dir"
    for attempt in 1 2 3; do
        rm -rf "$dir"
        if git clone --depth=1 "$repo" "$dir"; then
            return 0
        fi
        echo ">>> Clone $repo 失败, 重试 $attempt/3"
        sleep 5
    done

    echo ">>> Clone $repo 彻底失败" >&2
    return 1
}

remove_paths() {
    local p
    for p in "$@"; do
        if [ -e "$p" ]; then
            rm -rf "$p"
            echo "    - removed $p"
        fi
    done
}

# 在 ./scripts/feeds update -a 之后调用：
# 删掉 feeds 里与 package/ 第三方包同名的包，再只重建索引（不重新拉取）
if [ "${1:-}" = "cleanup" ]; then
    echo ">>> 删除与第三方包冲突的 feed 包"
    remove_paths \
        feeds/luci/applications/luci-app-passwall \
        feeds/packages/net/chinadns-ng \
        feeds/packages/net/dns2socks \
        feeds/packages/net/geoview \
        feeds/packages/net/hysteria \
        feeds/packages/net/ipt2socks \
        feeds/packages/net/microsocks \
        feeds/packages/net/naiveproxy \
        feeds/packages/net/shadow-tls \
        feeds/packages/net/shadowsocks-rust \
        feeds/packages/net/shadowsocksr-libev \
        feeds/packages/net/simple-obfs \
        feeds/packages/net/sing-box \
        feeds/packages/net/tcping \
        feeds/packages/net/v2ray-geodata \
        feeds/packages/net/v2ray-plugin \
        feeds/packages/net/xray-core \
        feeds/packages/net/xray-plugin

    echo ">>> 重建 feed 索引"
    ./scripts/feeds update -i
    exit 0
fi

# Fluent 是标准 feed（包在 package/ 子目录），可以 src-git
echo ">>> 添加 Fluent 主题 feed"
grep -q 'src-git fluent ' feeds.conf.default || \
    echo 'src-git fluent https://github.com/LazuliKao/luci-theme-fluent.git;main' >> feeds.conf.default

# PassWall
echo ">>> 添加 PassWall"
clone_pkg \
    https://github.com/Openwrt-Passwall/openwrt-passwall-packages \
    package/openwrt-passwall-packages
clone_pkg \
    https://github.com/Openwrt-Passwall/openwrt-passwall \
    package/luci-app-passwall

# PushBot：仓库本身就是一个包
echo ">>> 添加 PushBot"
clone_pkg \
    https://github.com/zzsj0928/luci-app-pushbot \
    package/luci-app-pushbot

# Lucky：仓库里同时有界面包和核心包，必须拆开
# 否则核心包嵌在界面包里，编译时扫不到
echo ">>> 添加 Lucky"
clone_pkg \
    https://github.com/gdy666/luci-app-lucky.git \
    package/tmp-lucky

if [ -d package/tmp-lucky/lucky ]; then
    rm -rf package/lucky
    mv package/tmp-lucky/lucky package/lucky
else
    echo "    ! 警告: lucky 仓库里没有 lucky/ 子目录" >&2
    exit 1
fi
rm -rf package/luci-app-lucky
mv package/tmp-lucky package/luci-app-lucky

echo ">>> 修复第三方包的相对路径"
find package -maxdepth 5 -name Makefile \
    -exec sed -i \
    's|\.\./\.\./luci.mk|$(TOPDIR)/feeds/luci/luci.mk|g' {} \;
find package -maxdepth 5 -name Makefile \
    -exec sed -i \
    's|\.\./\.\./lang/golang/golang-package.mk|$(TOPDIR)/feeds/packages/lang/golang/golang-package.mk|g' {} \;
