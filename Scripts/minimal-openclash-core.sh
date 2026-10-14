#!/bin/bash
# ============================================================
# DIY_P4_SH —— 预置 OpenClash 的 armv7 内核与地理数据
# 好处：刷完不用再联网下内核，直接可用
# 不需要就把工作流里的 DIY_P4_SH 改回 Scripts/false
# ============================================================
set -e

[ -d ./files ] || cd openwrt
mkdir -p files/etc/openclash/core

CLASH_DEV_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/dev/clash-linux-armv7.tar.gz"
CLASH_TUN_URL=$(curl -fsSL "https://api.github.com/repos/vernesong/OpenClash/contents/master/premium?ref=core" \
  | grep download_url | grep armv7 | awk -F '"' '{print $4}')
CLASH_META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-armv7.tar.gz"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
GEO_MMDB_URL="https://github.com/alecthw/mmdb_china_ip_list/raw/release/lite/Country.mmdb"

echo ">>> 下载 clash 内核（dev / tun / meta）"
wget -qO- "$CLASH_DEV_URL"  | tar xOvz  > files/etc/openclash/core/clash
wget -qO- "$CLASH_TUN_URL"  | gunzip -c > files/etc/openclash/core/clash_tun
wget -qO- "$CLASH_META_URL" | tar xOvz  > files/etc/openclash/core/clash_meta

echo ">>> 下载地理数据"
wget -qO- "$GEOIP_URL"    > files/etc/openclash/GeoIP.dat
wget -qO- "$GEOSITE_URL"  > files/etc/openclash/GeoSite.dat
wget -qO- "$GEO_MMDB_URL" > files/etc/openclash/Country.mmdb

chmod +x files/etc/openclash/core/*
ls -lh files/etc/openclash/core
