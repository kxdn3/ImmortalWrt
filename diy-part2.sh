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

# ========== 引导区大小 / 分区对齐：256 → 1024（1 MiB）==========
# target/linux/x86/image/Makefile 里 gen_image_generic.sh 的最后一个参数是 ALIGN，
# 上游默认 256（KiB）。它同时决定两件事：
#   1) 分区对齐 —— ptgen -l 决定分区 1 的起始位置：256 → 0.25 MiB，1024 → 1 MiB 边界
#      （1 MiB 对齐是 SSD/NVMe 最佳实践，gdisk 也不会报对齐告警）
#   2) GRUB 引导区 —— Build/grub-install 用 grub-bios-setup 把 core.img 嵌进
#      「MBR 之后、分区 1 之前」的间隙，该间隙大小恰好等于此 ALIGN 值
# 注意上游该行缩进是两个 Tab（故按 \t 匹配），另保留空格写法兜底。
ALIGN_MK=target/linux/x86/image/Makefile
if grep -qE '^[[:space:]]+256$' "$ALIGN_MK"; then
    sed -i 's/\t256$/\t1024/' "$ALIGN_MK"
    sed -i 's/ 256$/ 1024/' "$ALIGN_MK"
elif ! grep -qE '^[[:space:]]+1024$' "$ALIGN_MK"; then
    # 既不是 256 也不是 1024 → 上游可能改了默认值或改了缩进，必须报错而不是静默放过
    echo "!! 未找到上游默认的 ALIGN=256（也不是 1024），请检查：$ALIGN_MK" >&2
    exit 1
fi
if grep -qE '^[[:space:]]+1024$' "$ALIGN_MK"; then
    echo ">>> 引导区 / 分区对齐已设为 1024（1 MiB）"
else
    echo "!! ALIGN 替换未生效（分区对齐与 GRUB 引导区大小会回落到上游默认）" >&2
    exit 1
fi

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

# ========== CoreMark 跑分：改用 coremark 包自带方案（不改包）==========
# 包自带完整闭环（不再需要任何自定义代码）：
#   /etc/uci-defaults/xxx-coremark  首启写入 crontab "0 4 * * * /etc/coremark.sh"
#   /etc/coremark.sh                跑分 → 结果写入 /etc/bench.log → 自删 crontab 条目
#   LuCI 状态页 10_system.js        「型号」行 = model + readfile('/etc/bench.log')
# 此前曾改包 Makefile 移除这两个文件、另建 5:00/micrond/widget 一套方案，
# 现全部撤除，回归上游原生实现（零自定义维护）。

# ========== miniupnpd 补丁适配上游 2.3.11 ==========
# 上游 feeds/packages 把 miniupnpd 升到 2.3.11（仅改 Makefile，未刷新补丁集），
# 导致构建时 020 补丁应用失败（5/7 hunk FAILED）而中止编译。
# 逐条在真实 2.3.11 源码上试打核实后处理：
#   010-upnp-igdv2-compat.patch  可正常应用（offset 若干）           → 保留
#   020-descr-filter-fix.patch   改动已并入上游（patch 报 previously applied）→ 删除
#   030-allow-private-fix.patch  同上                                → 删除
#   040-improve-logging.patch    仅 miniupnpd.c 的 help 文本/日志措辞与上游冲突
#                                （上游自行改写了同样几行），其余 11 个文件的日志
#                                级别改进仍有效 → 剔除 miniupnpd.c 段落后续用
#   900-...-format-xml...        可正常应用                          → 保留
# 参考：官方 openwrt/packages 已整体删除该补丁目录；此处取最小干预，保留仍生效的改动。
MUP=feeds/packages/net/miniupnpd/patches
if [ -d "$MUP" ]; then
    rm -f "$MUP/020-descr-filter-fix.patch" "$MUP/030-allow-private-fix.patch"
    P040="$MUP/040-improve-logging.patch"
    if [ -f "$P040" ] && grep -q '^--- a/miniupnpd\.c$' "$P040"; then
        awk '
          /^--- a\/miniupnpd\.c$/ { skip = 1; next }
          /^--- a\//              { skip = 0 }
          skip != 1               { print }
        ' "$P040" > "$P040.new" && mv "$P040.new" "$P040"
        if [ -s "$P040" ] && ! grep -q '^--- a/miniupnpd\.c$' "$P040"; then
            echo ">>> miniupnpd 补丁已适配 2.3.11（020/030 已合并故删除，040 剔除 miniupnpd.c 段）"
        else
            echo "!! miniupnpd 040 补丁裁剪结果异常，请检查：$P040" >&2
            exit 1
        fi
    else
        echo ">>> miniupnpd 补丁已适配（020/030 已删除；040 无需裁剪或缺失）"
    fi
else
    echo "!! 未找到 $MUP（feeds 结构变动？）" >&2
fi

# ========== 状态页「本地时间」：加星期几 + 默认去掉时区后缀（GMT+8）==========
# 上游用 Intl.DateTimeFormat(undefined, {dateStyle, timeStyle, hourCycle, timeZone}) 渲染：
#   dateStyle: 'medium'                → "2026年10月15日"
#   timeStyle: (ts == 0) ? 'long' : 'full'
#       ts 是 uci 的 clock_timestyle（界面上那个「完整时区名称」复选框）：
#         未勾选 → 'long' → 带时区偏移，即 "GMT+8"
#         勾选   → 'full' → 带完整时区名
# 改为：
#   dateStyle: 'full'                  → "2026年10月15日星期四"（多出星期几）
#   timeStyle: (ts == 0) ? 'medium' : 'full'
#       → 默认（未勾选）不显示任何时区；勾选后仍显示完整时区名（复选框功能保留）
# 结果：默认 "2026年10月15日星期四 08:29:05"；勾选后 "…星期四 中国标准时间 08:29:05"
#
# 注意：dateStyle/timeStyle 与 weekday 等组件选项互斥（同时用会抛 Invalid option），
# 所以星期几只能靠 dateStyle:'full' 带出，不能另加 weekday。
#
# 待改代码同源出现在三个文件，都要改（feed 源码在构建时会被压缩，改源码即可随包进固件）：
#   1) luci-mod-status  状态 → 概览「本地时间」      （核心）
#   2) luci-mod-system  系统 → 系统 的本地时间预览   （保持与状态页一致）
#   3) luci-base 系统日志页的时间戳                  （只去时区，不加星期，避免每行变长）
patch_localtime() {
    _f="$1"; _name="$2"
    if [ ! -f "$_f" ]; then
        echo "!! 未找到 $_name（$_f），无法修改本地时间显示" >&2
        exit 1
    fi
    sed -i "s/dateStyle: 'medium',/dateStyle: 'full',/" "$_f"
    sed -i "s/timeStyle: (ts == 0) ? 'long' : 'full',/timeStyle: (ts == 0) ? 'medium' : 'full',/" "$_f"
    if grep -q "dateStyle: 'full'," "$_f" && grep -q "timeStyle: (ts == 0) ? 'medium' : 'full'," "$_f"; then
        echo ">>> $_name：已加上星期几，默认不再显示时区后缀"
    else
        echo "!! $_name 补丁未生效（上游代码可能变动），请检查：$_f" >&2
        exit 1
    fi
}

patch_localtime \
    feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js \
    "状态页本地时间"
patch_localtime \
    feeds/luci/modules/luci-mod-system/htdocs/luci-static/resources/view/system/system.js \
    "系统设置页本地时间"

# 系统日志页：同样的格式化代码，只去掉时区后缀，日期保持紧凑（不给每行日志加星期几）
LOGJS=feeds/luci/modules/luci-base/htdocs/luci-static/resources/tools/views.js
if [ -f "$LOGJS" ]; then
    sed -i "s/timeStyle: (ts == 0) ? 'long' : 'full',/timeStyle: (ts == 0) ? 'medium' : 'full',/" "$LOGJS"
    if grep -q "timeStyle: (ts == 0) ? 'medium' : 'full'," "$LOGJS"; then
        echo ">>> 系统日志时间戳：已去掉时区后缀（日期保持紧凑，不加星期）"
    else
        echo "!! 系统日志时间戳补丁未生效（上游代码可能变动），请检查：$LOGJS" >&2
        exit 1
    fi
else
    echo "!! 未找到 $LOGJS，系统日志时间戳将仍显示时区后缀（继续编译）" >&2
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
