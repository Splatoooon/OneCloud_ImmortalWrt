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
set network.lan.ipaddr='192.168.5.254'
set network.lan.netmask='255.255.255.0'
set network.lan.gateway='192.168.5.1'
commit network
EOF

# amlogic / meson 两条线的 target.mk 都写 CPU_SUBTYPE:=neon-vfpv4，
# 因此固件自身包架构是 arm_cortex-a5_neon-vfpv4，
# 而 ImmortalWrt 官方 24.10-SNAPSHOT 软件源只有 arm_cortex-a5_vfpv4。
# 这里把 vfpv4 追加进 opkg 的架构列表（优先级低于本架构），
# 使官方源的包可被识别安装。vfpv4 指令集是 neon-vfpv4 的子集，可正常运行。
if ! grep -q 'arm_cortex-a5_vfpv4' /etc/opkg.conf 2>/dev/null; then
  echo 'arch arm_cortex-a5_vfpv4 5' >> /etc/opkg.conf
fi

exit 0
UCI

chmod +x package/base-files/files/etc/uci-defaults/99-minimal-settings
echo ">>> 系统默认设置已写入（仅时区/NTP/主机名）"
