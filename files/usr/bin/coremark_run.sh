#!/bin/sh
# 由 micrond 每天凌晨 05:00 调用（见 /usr/lib/micron.d/coremark）
# 一次性任务：跑完一次后创建 /etc/coremark_done，之后每次被调用都直接退出
# 跑分失败（无分数）不创建 marker，次日 05:00 自动重试

[ -f /etc/coremark_done ] && exit 0

/bin/coremark >/tmp/coremark.log 2>&1
SCORE=$(grep -m1 -E "^CoreMark [0-9]" /tmp/coremark.log | awk '{print $4}')

if [ -n "$SCORE" ]; then
    # 注意：本固件的 uci 不会自动创建新配置文件，先建空文件再 set
    [ -f /etc/config/coremark ] || : > /etc/config/coremark
    uci -q delete coremark.result
    uci set coremark.result=coremark
    uci set coremark.result.score="$SCORE"
    uci set coremark.result.timestamp="$(date '+%Y-%m-%d %H:%M')"
    uci commit coremark
    touch /etc/coremark_done
    logger -t coremark "score=$SCORE, 任务完成并取消"
else
    logger -t coremark "跑分失败，详见 /tmp/coremark.log，次日 05:00 重试"
fi

exit 0
