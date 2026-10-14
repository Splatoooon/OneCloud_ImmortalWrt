#!/bin/bash
# ============================================================
# DIY_P4_SH —— 预置 OpenClash 内核（armv7）与地理数据
# 好处：刷完不用再联网下内核，直接可用
#
# 2026-10 注：vernesong/OpenClash 的 core 分支已改版。
#   旧路径 core/master/dev/... 与 core/master/premium/... 均已下线（404），
#   现役路径只有 {master,dev}/{meta,smart}/clash-linux-armv7.tar.gz。
#   luci-app-openclash 现在也只用 clash_meta，不再需要 clash / clash_tun。
#
# 不需要就把工作流里的 DIY_P4_SH 改回 Scripts/false
# ============================================================
set -e

[ -d ./files ] || cd openwrt
mkdir -p files/etc/openclash/core

CORE_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-armv7.tar.gz"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
GEO_MMDB_URL="https://github.com/alecthw/mmdb_china_ip_list/raw/release/lite/Country.mmdb"

echo ">>> 下载 clash_meta 内核"
wget -qO- "$CORE_URL" | tar xOvz > files/etc/openclash/core/clash_meta
chmod +x files/etc/openclash/core/clash_meta

echo ">>> 下载地理数据（失败不中断，刷好后可在界面里再下载）"
wget -qO- "$GEOIP_URL"    > files/etc/openclash/GeoIP.dat    || { echo "  GeoIP 失败，跳过";       rm -f files/etc/openclash/GeoIP.dat; }
wget -qO- "$GEOSITE_URL"  > files/etc/openclash/GeoSite.dat  || { echo "  GeoSite 失败，跳过";     rm -f files/etc/openclash/GeoSite.dat; }
wget -qO- "$GEO_MMDB_URL" > files/etc/openclash/Country.mmdb || { echo "  Country.mmdb 失败，跳过"; rm -f files/etc/openclash/Country.mmdb; }

ls -lh files/etc/openclash/core files/etc/openclash
