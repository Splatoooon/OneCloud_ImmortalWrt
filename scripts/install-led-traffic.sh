#!/bin/bash
# 一键安装：玩客云 LED 流量指示灯服务
# 用法：bash install-led-traffic.sh
set -e

BASE='https://testingcf.jsdelivr.net/gh/Splatoooon/OneCloud_ImmortalWrt@master/scripts'
MIRROR='https://raw.githubusercontent.com/Splatoooon/OneCloud_ImmortalWrt/master/scripts'

[ "$(id -u)" = 0 ] || { echo "请用 root 运行（sudo -i）"; exit 1; }

command -v curl >/dev/null || { echo "缺少 curl，先执行: apt install -y curl"; exit 1; }

fetch() {  # $1 = 文件名
    if curl -kfsSL --connect-timeout 10 "$BASE/$1" -o "/tmp/$1" 2>/dev/null; then return 0; fi
    echo "CDN 不通，换备用源..."
    curl -kfsSL --connect-timeout 15 "$MIRROR/$1" -o "/tmp/$1"
}

echo "==> 下载脚本"
fetch led-clash-traffic.sh
fetch led-clash-traffic.service

install -m 0755 /tmp/led-clash-traffic.sh /usr/local/bin/led-clash-traffic.sh
install -m 0644 /tmp/led-clash-traffic.service /etc/systemd/system/led-clash-traffic.service

echo "==> 启动服务"
systemctl daemon-reload
systemctl enable --now led-clash-traffic.service
sleep 2
systemctl status led-clash-traffic.service --no-pager -l || true

echo
echo "安装完成。灯的含义："
echo "  绿灯闪烁 = Clash 有流量，越快越急     绿灯常亮 = 在线但无流量"
echo "  红灯常亮 = 代理挂了                    蓝灯 = 关闭"
echo
echo "前台看实时速率（Ctrl+C 退出）："
echo "  systemctl stop led-clash-traffic.service && led-clash-traffic.sh -v"
