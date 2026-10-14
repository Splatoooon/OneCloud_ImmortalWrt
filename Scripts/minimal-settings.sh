#!/bin/bash
# ============================================================
# DIY_P2_SH —— 只做时区和 NTP 的国内化
# 不做的事（与原项目对比）：
#   - 不写死 root 密码（原项目 hash 全网公开）
#   - 不做 53 端口 DNS 全量劫持
#   - 不改 WiFi 默认 SSID/密码
#   - 不改 argon 配色、不换 banner
# ============================================================
set -e

[ -d ./scripts ] || cd openwrt

mkdir -p package/base-files/files/etc/uci-defaults

cat > package/base-files/files/etc/uci-defaults/99-minimal-settings <<'UCI'
uci -q batch <<'EOF'
set system.@system[0].hostname='OneCloud'
set system.@system[0].timezone='CST-8'
set system.@system[0].zonename='Asia/Shanghai'
delete system.ntp.server
add_list system.ntp.server='ntp.ntsc.ac.cn'
add_list system.ntp.server='ntp.aliyun.com'
add_list system.ntp.server='cn.pool.ntp.org'
commit system
EOF
exit 0
UCI

chmod +x package/base-files/files/etc/uci-defaults/99-minimal-settings
echo ">>> 系统默认设置已写入（仅时区/NTP/主机名）"
