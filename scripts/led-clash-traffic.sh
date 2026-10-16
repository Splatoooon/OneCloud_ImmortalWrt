#!/bin/bash
# =====================================================================
# 玩客云 RGB LED × Clash 流量指示灯（Armbian + ShellCrash）
#
#   绿灯：闪烁速度 = Clash 实时流量，流量越大闪得越急；完全空闲时常亮
#   红灯：常亮 = 代理挂了（端口不在监听）
#   蓝灯：常灭
#
# 流量来源（自动选择）：
#   1) mihomo / sing-box 的 External Controller API  -> http://127.0.0.1:9999/traffic
#      （端口与 secret 自动从 /etc/ShellCrash/configs/ShellCrash.cfg 读取）
#   2) API 取不到但代理还在跑时，回退统计网卡总流量 /proc/net/dev
#
# 用法：
#   led-clash-traffic.sh        # 后台常驻（给 systemd 用）
#   led-clash-traffic.sh -v     # 前台运行并打印速率，调试用
# =====================================================================

# ---------------------- 可调参数 ----------------------
INTERVAL=2        # 采样间隔（秒）
DOWN_FAIL=2       # 连续几次检测不到端口才判定"代理挂了"（防抖）
EMA=6             # 平滑系数 0~9，越大越迟钝（6 = 新值占 40%）
NETIF=eth0        # 回退方案用的网卡名（ip a 看一下）
VERBOSE=0

# 流量档位：速率阈值(KB/s) -> 亮/灭毫秒数（0 表示常亮）
T1=5     D1=0       # 空闲            -> 绿灯常亮
T2=50    D2=900     # 5~50 KB/s       -> 极慢闪
T3=200   D3=500     # 50~200 KB/s     -> 1 Hz
T4=500   D4=300     # 200~500 KB/s
T5=2000  D5=180     # 0.5~2 MB/s
T6=5000  D6=110     # 2~5 MB/s
                 D7=60      # >5 MB/s   -> 急闪
# -----------------------------------------------------

[ "$1" = "-v" ] && VERBOSE=1

LED_BASE=/sys/class/leds

# ---------- LED 设备探测（兼容不同 dts 命名） ----------
find_led() {
    local c=$1 d
    for d in "$LED_BASE/onecloud:$c:alive" "$LED_BASE/onecloud:$c" "$LED_BASE/$c"; do
        [ -d "$d" ] && { printf '%s' "$d"; return 0; }
    done
    d=$(ls -d "$LED_BASE"/*"$c"* 2>/dev/null | head -1)
    [ -n "$d" ] && { printf '%s' "$d"; return 0; }
    return 1
}

R=$(find_led red)    || { echo "找不到红色 LED"; exit 1; }
G=$(find_led green)  || { echo "找不到绿色 LED"; exit 1; }
B=$(find_led blue)   || B=""

log() { [ "$VERBOSE" = 1 ] && echo "$@"; }
[ "$VERBOSE" = 1 ] && echo "R=$R  G=$G  B=$B"

# ---------- LED 状态机（只在状态变化时写 sysfs） ----------
G_MODE=""; G_MS=0; R_STATE=""

set_green() {          # $1 = 毫秒，0 = 常亮
    local ms=$1
    if [ "$ms" -eq 0 ]; then
        [ "$G_MODE" = "on" ] && return 0
        echo none > "$G/trigger" 2>/dev/null
        echo 1    > "$G/brightness" 2>/dev/null
        G_MODE="on"
    else
        [ "$G_MODE" = "blink" ] && [ "$G_MS" = "$ms" ] && return 0
        echo timer > "$G/trigger"    2>/dev/null
        echo "$ms" > "$G/delay_on"   2>/dev/null
        echo "$ms" > "$G/delay_off"  2>/dev/null
        G_MODE="blink"; G_MS="$ms"
    fi
}

green_off() {
    [ "$G_MODE" = "off" ] && return 0
    echo none > "$G/trigger"    2>/dev/null
    echo 0    > "$G/brightness" 2>/dev/null
    G_MODE="off"
}

set_red() {            # $1 = 1 亮 / 0 灭
    [ "$R_STATE" = "$1" ] && return 0
    echo none > "$R/trigger"    2>/dev/null
    echo "$1" > "$R/brightness" 2>/dev/null
    R_STATE="$1"
}

# ---------- 读取 ShellCrash 配置 ----------
CRASHDIR=""
for d in /etc/ShellCrash /usr/share/ShellCrash /root/ShellCrash /opt/ShellCrash; do
    [ -f "$d/configs/ShellCrash.cfg" ] && { CRASHDIR="$d"; break; }
done
if [ -z "$CRASHDIR" ] && [ -f /etc/profile ]; then
    p=$(sed -n 's/.*CRASHDIR=\([^ ]*\).*/\1/p' /etc/profile 2>/dev/null | head -1)
    [ -n "$p" ] && [ -d "$p" ] && CRASHDIR="$p"
fi

DB_PORT=9999; SECRET=""; MIX_PORT=7890
if [ -n "$CRASHDIR" ]; then
    . "$CRASHDIR/configs/ShellCrash.cfg" 2>/dev/null
    [ -z "$db_port"  ] && db_port=9999
    [ -z "$mix_port" ] && mix_port=7890
    DB_PORT="$db_port"; SECRET="${secret:-}"; MIX_PORT="$mix_port"
fi
log "CRASHDIR=$CRASHDIR  API=127.0.0.1:$DB_PORT  代理端口=$MIX_PORT"

# ---------- 流量采样 ----------
# mihomo / sing-box 的 /traffic 返回 {"down":N,"up":N}，是开机以来的累加字节数
get_traffic() {
    local json down up
    json=$(curl -s -m 2 -H "Authorization: Bearer $SECRET" \
           "http://127.0.0.1:$DB_PORT/traffic" 2>/dev/null) || return 1
    down=$(printf '%s' "$json" | sed -n 's/.*"down":[[:space:]]*\([0-9]\{1,\}\).*/\1/p')
    up=$(printf '%s'   "$json" | sed -n 's/.*"up":[[:space:]]*\([0-9]\{1,\}\).*/\1/p')
    [ -z "$down" ] && [ -z "$up" ] && return 1
    printf '%s' $(( ${down:-0} + ${up:-0} ))
}

# 回退：网卡总字节数（rx + tx），不依赖任何工具
get_netdev() {
    awk -v i="$NETIF" '{ gsub(":","",$1); if ($1==i) { print $2+$10; exit } }' /proc/net/dev 2>/dev/null
}

# 端口是否在监听（读 /proc/net/tcp，第 4 列 0A = LISTEN，无需 ss/netstat）
port_open() {
    local hex
    hex=$(printf '%04X' "$1")
    awk -v p="$hex" 'NR>1 { split($2,a,":"); if (a[2]==p && $4=="0A") f=1 } END { exit !f }' \
        /proc/net/tcp 2>/dev/null
}

# ---------- 速率(字节/秒) -> 闪烁毫秒 ----------
calc_ms() {
    local kb=$1
    if   [ "$kb" -lt "$T1" ]; then printf '%s' "$D1"
    elif [ "$kb" -lt "$T2" ]; then printf '%s' "$D2"
    elif [ "$kb" -lt "$T3" ]; then printf '%s' "$D3"
    elif [ "$kb" -lt "$T4" ]; then printf '%s' "$D4"
    elif [ "$kb" -lt "$T5" ]; then printf '%s' "$D5"
    elif [ "$kb" -lt "$T6" ]; then printf '%s' "$D6"
    else printf '%s' "$D7"
    fi
}

# ---------- 退出清理 ----------
cleanup() {
    [ -n "$B" ] && { echo none > "$B/trigger" 2>/dev/null; echo 0 > "$B/brightness" 2>/dev/null; }
    green_off
    set_red 0
    log "已退出，LED 全部熄灭"
    exit 0
}
trap cleanup TERM INT

# ---------- 初始化：蓝灯关闭 ----------
if [ -n "$B" ]; then
    echo none > "$B/trigger"    2>/dev/null
    echo 0    > "$B/brightness" 2>/dev/null
fi
set_red 0
green_off

# ---------- 主循环 ----------
prev=0; avg=0; fails=0

while true; do
    if port_open "$MIX_PORT"; then
        fails=0
    else
        fails=$((fails + 1))
    fi

    if [ "$fails" -ge "$DOWN_FAIL" ]; then
        # 代理挂了 -> 红灯常亮，绿灯灭
        green_off; set_red 1
        log "$(date +%H:%M:%S) 代理未监听 $MIX_PORT -> 红灯报警"
        prev=0; avg=0
        sleep "$INTERVAL"
        continue
    fi

    total=$(get_traffic); src="api"
    if [ -z "$total" ]; then
        total=$(get_netdev); src="netdev"
    fi
    if [ -z "$total" ]; then
        # 两个源都取不到，保守显示空闲常亮
        set_red 0; set_green 0
        sleep "$INTERVAL"
        continue
    fi

    if [ "$prev" -gt 0 ] && [ "$total" -ge "$prev" ]; then
        bps=$(( (total - prev) / INTERVAL ))
    else
        bps=0        # 首次采样，或内核重启后计数归零
    fi
    prev=$total

    # 指数平滑，避免抖动导致灯乱跳
    if [ "$avg" -eq 0 ]; then avg=$bps; else avg=$(( (avg * EMA + bps * (10 - EMA)) / 10 )); fi

    kb=$(( avg / 1024 ))
    ms=$(calc_ms "$kb")

    set_red 0
    set_green "$ms"

    if [ "$VERBOSE" = 1 ]; then
        if [ "$ms" -eq 0 ]; then
            printf '%s  src=%-6s %6s KB/s  -> 绿灯常亮\n' "$(date +%H:%M:%S)" "$src" "$kb"
        else
            printf '%s  src=%-6s %6s KB/s  -> 绿灯 %sms/%sms\n' "$(date +%H:%M:%S)" "$src" "$kb" "$ms" "$ms"
        fi
    fi

    sleep "$INTERVAL"
done
