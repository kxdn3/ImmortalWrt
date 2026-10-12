#!/bin/bash
#
# diy-part1.sh - Before Update feeds
#
# 集成方式说明：
#   * 标准 feed（仓库根目录每个子目录即一个包）用 src-git 添加，
#     例如 Nikki；这样 ./scripts/feeds update/install 能正确处理。
#   * 非标准 feed（如 PushBot 仓库根本身就是一个 Makefile）或单包仓库，
#     直接 git clone 到 package/ 下，不要写成 src-git，否则 feeds update
#     会报 "target pattern contains no '%'" 之类错误。
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

# 在 ./scripts/feeds update -a 之后调用：此时 feeds 已更新、install 尚未
# 运行，适合对 feed 内容做最后的修补（例如摘除失效依赖）。
if [ "${1:-}" = "cleanup" ]; then
    # ------------------------------------------------------------
    # 摘掉 luci-app-dockerman 对 docker-compose 的依赖
    # ------------------------------------------------------------
    # 上游 feeds/packages/utils/docker-compose 目前是坏的：compose
    # v5.5.1 的 go.mod 与 docker/cli@v29.7.2 不兼容，Go 1.27 下大批
    # 依赖包无法解析，编译到最后阶段必然失败：
    #   ERROR: package/feeds/packages/docker-compose failed to build.
    # 而 luci-app-dockerman 的 ucode/htdocs 代码里并无任何 compose
    # 调用，它只是 LUCI_DEPENDS 里顺带声明了这个依赖，摘掉即可。
    # 放在这里执行的时机是正确的：此时 feeds 已更新，install feeds
    # 尚未运行，改动会被 install 阶段读取。
    echo ">>> 摘掉 dockerman 的 docker-compose 依赖"
    dman="feeds/luci/applications/luci-app-dockerman/Makefile"
    if [ -f "$dman" ]; then
        sed -i '/^[[:space:]]*+docker-compose[[:space:]]*\\[[:space:]]*$/d' "$dman"
        sed -i 's/\([[:space:]]\)+docker-compose\([[:space:]]\|\\\|\$\)/\1\2/g' "$dman"
        echo "    - 已处理 $dman"
        sed -n '/^LUCI_DEPENDS/,/^$/p' "$dman" | sed 's/^/      /'
    else
        echo "    ! 未找到 $dman（可能路径变动），跳过"
    fi

    exit 0
fi

# Fluent 是标准 feed（包在 package/ 子目录），可以 src-git
echo ">>> 添加 Fluent 主题 feed"
grep -q 'src-git fluent ' feeds.conf.default || \
    echo 'src-git fluent https://github.com/LazuliKao/luci-theme-fluent.git;main' >> feeds.conf.default

# Nikki：基于 mihomo 的透明代理界面，标准 feed 结构，用 src-git 添加。
# 仓库自带 mihomo-meta / mihomo-alpha 内核与 geo 处理，不依赖 geoview，
# 也不依赖 xray/sing-box。选 luci-app-nikki 即自动带入 nikki + mihomo。
echo ">>> 添加 Nikki feed"
grep -q 'src-git nikki ' feeds.conf.default || \
    echo 'src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main' >> feeds.conf.default

# PushBot：仓库本身就是一个包（非标准 feed），直接 clone 到 package/
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
