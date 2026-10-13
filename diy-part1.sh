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

    # ------------------------------------------------------------
    # 删掉官方 feed 里的 luci-theme-argon，改用作者源（jerrykuku）
    # ------------------------------------------------------------
    # 上面已把 jerrykuku 的 argon clone 到 package/luci-theme-argon，
    # 这里把 feeds/luci/themes/luci-theme-argon 删掉，否则 feeds install 时
    # 会和作者源出现同名包（luci-theme-argon）冲突 / 互相覆盖。
    # 注意：必须在 feeds update 之后、feeds install 之前执行（本 cleanup 模式即此时机）。
    echo ">>> 移除官方 luci-theme-argon（改作者源）"
    off_argon="feeds/luci/themes/luci-theme-argon"
    if [ -d "$off_argon" ]; then
        rm -rf "$off_argon"
        echo "    - 已移除 $off_argon"
    else
        echo "    ! 未找到 $off_argon（可能路径变动），跳过"
    fi

    exit 0
fi

# Fluent 是标准 feed（包在 package/ 子目录），可以 src-git
echo ">>> 添加 Fluent 主题 feed"
grep -q 'src-git fluent ' feeds.conf.default || \
    echo 'src-git fluent https://github.com/LazuliKao/luci-theme-fluent.git;main' >> feeds.conf.default

# Argon 用作者源（jerrykuku/luci-theme-argon），不要用 ImmortalWrt 官方 feed。
# 作者源版本 2.4.8（beta.1，2026-10-09 发布，仍在持续更新），官方 feed 停在 2.4.7（2026-08-24）。
# 仓库根目录即 Makefile（单包仓库，已用 $(TOPDIR)/feeds/luci/luci.mk 绝对路径），直接 clone 到
# package/；同时在 cleanup 阶段删掉官方 feed 里的同名包，避免重复/冲突。
echo ">>> 添加 Argon 主题（作者源 jerrykuku）"
clone_pkg \
    https://github.com/jerrykuku/luci-theme-argon \
    package/luci-theme-argon

# Nikki：基于 mihomo 的透明代理界面，标准 feed 结构，用 src-git 添加。
# 仓库自带 mihomo-meta / mihomo-alpha 内核与 geo 处理，不依赖 geoview，
# 也不依赖 xray/sing-box。选 luci-app-nikki 即自动带入 nikki + mihomo。
echo ">>> 添加 Nikki feed"
grep -q 'src-git nikki ' feeds.conf.default || \
    echo 'src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main' >> feeds.conf.default

# luci-app-ttyd-strict：LuCI2 界面的 ttyd（带 zh_Hans 翻译、rpcd 后端），
# 只做界面层，不带 init/UCI 文件，不跟官方 ttyd 包冲突。
echo ">>> 添加 luci-app-ttyd-strict"
clone_pkg \
    https://github.com/rabbitrogi/luci-app-ttyd-strict \
    package/luci-app-ttyd-strict

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
