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

## 依赖来源（已核实，24.10-SNAPSHOT / arm_cortex-a5_vfpv4）

| 组件 | 来源 |
|---|---|
| dockerd / docker / docker-compose / luci-app-dockerman | ImmortalWrt 官方 feed |
| bash / curl / ruby / ruby-yaml / unzip（OpenClash 依赖） | ImmortalWrt 官方 feed |
| libuci-lua / mount-utils / luci-lua-runtime（iStore 依赖） | ImmortalWrt 官方 feed |
| taskd / luci-lib-taskd / luci-lib-xterm | `linkease/istore` feed（官方源没有） |
| kmod-tun / kmod-veth / kmod-nft-tproxy | 随固件编译（不在 packages 源） |

## 注意事项

- **只支持 amlogic6.6**。meson6.6 的包架构是 `arm_cortex-a5_neon-vfpv4`，官方源查无此目录；
  amlogic6.12 会切到 `openwrt-25.12` 分支，但该分支 32 位 armv7 的 `base/`、`luci/` 是空的。
- **Docker 很占空间**：dockerd 60 MB + containerd 105 MB，建议把 `/opt/docker` 挂到外接存储。
- 默认地址 **192.168.1.1**，默认无密码（首次登录会要求设置）。
- 想加减组件，改 `Config/minimal.config` 末尾的包列表即可，`make defconfig` 会自动解析依赖。
