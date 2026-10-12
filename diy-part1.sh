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

# Lucky (sirpdboy 版)：仓库里同时有界面包和核心包，必须拆开
# 否则核心包嵌在界面包里，编译时扫不到
echo ">>> 添加 Lucky (sirpdboy 版)"
clone_pkg \
    https://github.com/sirpdboy/luci-app-lucky.git \
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

# ============================================================
# 摘掉 luci-app-dockerman 对 docker-compose 的依赖
# ------------------------------------------------------------
# 原因：上游 feeds/packages/utils/docker-compose 目前是坏的
#       （compose v5.5.1 的 go.mod 与 docker/cli@v29.7.2 不兼容，
#        Go 1.27 下大批依赖包无法解析），编译到最后阶段必然失败：
#         ERROR: package/feeds/packages/docker-compose failed to build.
#       而 luci-app-dockerman 的 ucode/htdocs 代码里并没有任何
#       compose 调用，它只是 LUCI_DEPENDS 里顺带声明了这个依赖。
# 处理：保留 Docker 引擎（dockerd / docker），仅移除界面里的
#       compose 依赖，让 dockerman 能正常编译。
# 注意：feeds/luci 在 "Update feeds" 阶段之后才被 sed，所以这段
#       放在 install feeds 之后调用（由 workflow 调用带 cleanup 参数
#       的分支之外单独执行）。这里先做 package/ 下的处理，
#       feeds/luci 下的处理放在 patch-dockerman 子命令里。
if [ "${1:-}" = "patch-dockerman" ]; then
    echo ">>> 摘掉 dockerman 的 docker-compose 依赖"
    dman="feeds/luci/applications/luci-app-dockerman/Makefile"
    if [ -f "$dman" ]; then
        # 删除 LUCI_DEPENDS 中以 +docker-compose 结尾的那一行（含行尾续行符）
        sed -i '/^[[:space:]]*+docker-compose[[:space:]]*\\[[:space:]]*$/d' "$dman"
        # 兜底：处理行内不带续行符的写法
        sed -i 's/[[:space:]]*+docker-compose\([[:space:]]*\\\)\?//g' "$dman"
        echo "    - 已处理 $dman"
        echo "    - 当前 LUCI_DEPENDS:"
        sed -n '/^LUCI_DEPENDS/,/^$/p' "$dman" | sed 's/^/      /'
    else
        echo "    ! 未找到 $dman（可能路径变动），跳过" >&2
    fi
    exit 0
fi
