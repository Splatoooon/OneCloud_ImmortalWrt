# 最小化固件：Docker + iStore + OpenClash

本分支在保持原版 ImmortalWrt 不变的前提下，只增加 Docker、iStore、OpenClash。

## 和 `master` 上 `all-quiker.yml` 的区别

| 挂载点 | 原值 | 本分支 |
|---|---|---|
| DIY_P1 | `Scripts/setup.sh`（末尾调 Packages.sh + Handles.sh） | `Scripts/minimal-setup.sh`（只加 istore + openclash） |
| DIY_P2 | `Scripts/Settings.sh`（写死密码、劫持 53 端口） | `Scripts/minimal-settings.sh`（仅时区与 NTP） |
| DIY_P3 / P5 | `Scripts/false` | 维持 `false` |
| DIY_P4 | `Scripts/openclash32.sh` | `Scripts/minimal-openclash-core.sh` |
| OWRT_FILES | `onecloud/files`（100+ 预置配置） | `files-minimal`（仅一个 rc.local） |
| OWRT_CFG | `Config/quicker-amlogic.config` | `Config/minimal.config` |

还额外做了一件事：`lede6.6/target/linux/amlogic/meson8b/config-6.6` 里
`CGROUP_DEVICE` 和 `CGROUP_FREEZER` 原本是 `# ... is not set`，
Docker 需要这两个选项，工作流里用 sed 改回了 `=y`。

## 怎么编译

1. Settings → Actions → General
   - 启用 Actions
   - Workflow permissions 改为 **Read and write**
2. Actions → **OneCloud 最小固件（ImmortalWrt + Docker + iStore + OpenClash）**
   → Run workflow → 选 `minimal-build` 分支
3. 首次约 2–4 小时（无 ccache），第二次起 30–60 分钟
4. 产物在 Releases 的 `OpenWrt_minimal_immortalwrt_<日期>`，取 `*.xz` 用双 USB 公头线刷机

## 依赖来源（已核实，ImmortalWrt 24.10-SNAPSHOT）

| 组件 | 来源 |
|---|---|
| dockerd / docker / docker-compose / luci-app-dockerman | ImmortalWrt 官方 feed |
| bash / curl / ruby / ruby-yaml / unzip（OpenClash 依赖） | ImmortalWrt 官方 feed |
| libuci-lua / mount-utils / luci-lua-runtime（iStore 依赖） | ImmortalWrt 官方 feed |
| taskd / luci-lib-taskd / luci-lib-xterm | `linkease/istore` feed（官方源没有） |
| kmod-tun / kmod-veth / kmod-nft-tproxy | 随固件编译（不在 packages 源） |

## 包架构与软件源（重要）

`lede6.6/target/linux/{amlogic,meson}/meson8b/target.mk` 两条线内容一致：

```makefile
CPU_TYPE:=cortex-a5
CPU_SUBTYPE:=neon-vfpv4
```

所以**固件自身的包架构是 `arm_cortex-a5_neon-vfpv4`**，而 ImmortalWrt 官方
`24.10-SNAPSHOT` 只有 `arm_cortex-a5_vfpv4` 目录（neon 版 404，两条线都是如此）。

本分支的 uci-defaults 在首次启动时自动往 `/etc/opkg.conf` 追加一行：

```
arch arm_cortex-a5_vfpv4 5
```

优先级 5 低于本架构 10，`vfpv4` 指令集是 `neon-vfpv4` 的子集，官方包可直接安装运行。
（没改 `CPU_SUBTYPE` 是为了保留 NEON 优化，且避免全量重编。）

刷好后确认：

```sh
opkg print-architecture      # 应同时看到 neon-vfpv4(10) 与 vfpv4(5)
```

软件源（PKU 镜像）写入 `/etc/opkg/distfeeds.conf`：

```sh
cat > /etc/opkg/distfeeds.conf <<'EOF'
src/gz immortalwrt_base https://mirrors.pku.edu.cn/immortalwrt/releases/24.10-SNAPSHOT/packages/arm_cortex-a5_vfpv4/base
src/gz immortalwrt_luci https://mirrors.pku.edu.cn/immortalwrt/releases/24.10-SNAPSHOT/packages/arm_cortex-a5_vfpv4/luci
src/gz immortalwrt_packages https://mirrors.pku.edu.cn/immortalwrt/releases/24.10-SNAPSHOT/packages/arm_cortex-a5_vfpv4/packages
src/gz immortalwrt_routing https://mirrors.pku.edu.cn/immortalwrt/releases/24.10-SNAPSHOT/packages/arm_cortex-a5_vfpv4/routing
src/gz immortalwrt_telephony https://mirrors.pku.edu.cn/immortalwrt/releases/24.10-SNAPSHOT/packages/arm_cortex-a5_vfpv4/telephony
EOF
opkg update
```

**`kmod-*` 不要从源里装**——内核模块必须与固件的 vermagic（`6.6.157`）严格一致，
源里的版本对不上，装了轻则功能失效重则起不来。

## 注意事项

- **只编 amlogic6.6 一条线**。amlogic6.12 会切到 `openwrt-25.12` 分支，该分支
  32 位 armv7 的 `base/`、`luci/` 是空的，等于没有软件源。
- 固件里没有 MosDNS / OpenClash 之外的代理插件（HomeProxy、SSR-Plus 等都不在），
  需要的话从各自 GitHub 仓库取 ipk。
- **Docker 很占空间**：dockerd 60 MB + containerd 105 MB，建议把 `/opt/docker` 挂到外接存储。
- 默认地址 **192.168.5.254** / 网关 **192.168.5.1**，默认无密码（首次登录会要求设置）。
  （网关只影响设备自身出网；若还想给 LAN 客户端下发 DNS，见下方说明）
- 改 IP / 网关：编辑 `Scripts/minimal-settings.sh` 里 uci-defaults 的 `network.lan` 段。
- 想加减组件，改 `Config/minimal.config` 末尾的包列表即可，`make defconfig` 会自动解析依赖。
