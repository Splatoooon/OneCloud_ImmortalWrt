#!/bin/bash
# ============================================================
# DIY_P1_SH —— 只引入 iStore 与 OpenClash 两个第三方源
# 其余全部保持 ImmortalWrt 官方 feeds 原样
# 原项目的 Packages.sh / Handles.sh 不再被调用
# ============================================================
set -e

[ -d ./scripts ] || cd openwrt

echo ">>> [1/3] 追加 iStore feed（istore-ui 由 Makefile 编译时自动下载，无需额外 feed）"
grep -q "linkease/istore" feeds.conf.default 2>/dev/null || \
  echo "src-git istore https://github.com/linkease/istore;main" >> feeds.conf.default

echo ">>> [2/3] 拉取 OpenClash 本体（dev 分支）"
rm -rf package/luci-app-openclash
git clone --depth 1 --single-branch --branch dev \
  https://github.com/vernesong/OpenClash.git /tmp/OpenClash
mv /tmp/OpenClash/luci-app-openclash package/luci-app-openclash
rm -rf /tmp/OpenClash

echo ">>> [3/3] 更新并安装 feeds"
./scripts/feeds update -a
./scripts/feeds install -a

echo ">>> 第三方源注入完成，当前 feeds："
cat feeds.conf.default
