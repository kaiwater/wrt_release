# 编译指南

本仓库用于按设备配置自动拉取 OpenWrt / ImmortalWrt / LiBwrt 源码、应用自定义补丁与软件包配置，并输出固件到 `firmware/` 目录。

## 1. 环境准备

推荐使用 Ubuntu LTS 或其他主流 Linux 发行版。OpenWrt 编译对磁盘空间、内存和文件系统大小写敏感性有要求，建议预留充足磁盘空间并在原生 Linux 文件系统中编译。

## 2. 安装编译依赖

```bash
sudo apt -y update
sudo apt -y full-upgrade
sudo apt install -y dos2unix libfuse-dev
sudo bash -c 'bash <(curl -sL https://build-scripts.immortalwrt.org/init_build_environment.sh)'
```

容器构建还需要已安装并可正常运行的 Docker。

## 3. 获取源码

```bash
git clone https://github.com/kaiwater/wrt_release.git
cd wrt_release
```

## 4. 编译用法

### 交互式选择

直接运行脚本会列出当前 `wrt_core/compilecfg/*.ini` 与 `wrt_core/deconfig/*.config` 同时存在的设备配置，并提示选择构建模式：

```bash
./build.sh
```

### 直接指定设备

```bash
./build.sh <设备配置名> [debug|container|container_debug|config_preview]
```

构建模式说明：

| 模式 | 命令示例 | 说明 |
| --- | --- | --- |
| 默认 | `./build.sh x64_immwrt` | 拉取源码、应用配置、下载依赖并完整编译固件。 |
| `debug` | `./build.sh x64_immwrt debug` | 执行到 `make defconfig` 后停止，用于检查配置，不产出固件。 |
| `container` | `./build.sh x64_immwrt container` | 使用 Docker 容器执行完整构建，减少本机环境差异。 |
| `container_debug` | `./build.sh x64_immwrt container_debug` | 在 Docker 容器中执行 debug 流程并进入交互 shell。 |
| `config_preview` | `./build.sh x64_immwrt config_preview` | 只预览配置片段组合，不拉取源码、不写构建目录。 |

可通过环境变量临时追加或移除配置片段：

```bash
ADD_CONFIG_FRAGMENTS=docker_deps ./build.sh gemtek_w1701k_immwrt config_preview
REMOVE_CONFIG_FRAGMENTS=proxy ./build.sh x64_immwrt config_preview
```

GitHub Actions 的手动构建也提供 `add_fragments` 与 `remove_fragments` 输入项，语义与上述环境变量一致。

`Build WRT` / `Release WRT` 的 `model` 输入选择 `libwrt_all` 时，会并行构建三个 LiBwrt 机型：`jdcloud_ipq60xx_libwrt`（ipq60xx / RE-CS-02）、`aliyun_ap8220_libwrt`（ipq807x / 1G NSS 档位）和 `xiaomi_ax3600_libwrt`（ipq807x / 512M NSS 档位）。

选择 `immwrt_all` 时，会并行构建三个 VIKINGYFY main 机型：`jdcloud_ipq60xx_immwrt`、`aliyun_ap8220_immwrt` 和 `xiaomi_ax3600_immwrt`。VIKINGYFY 与 LibWrt 的 ath11k/NSS patch 在构建脚本中按 `REPO_URL` / `BUILD_DIR` 分开处理：VIKINGYFY 使用自带的 `999-922`，不会再修改 LibWrt 的 `199-003`；只有 LibWrt 才应用 12.5 结构体 define 和 RX 过滤修正。

`compile_base.config` 默认使用 apk（`CONFIG_USE_APK=y`）。immortalwrt / LiBwrt 25.12 系列上游本身以 apk 为默认；仍使用 opkg 的旧分支（如 padavanonly 21.02/24.10）会忽略该符号，保持原有 opkg 构建。

编译完成后，脚本会从 `<BUILD_DIR>/bin/targets/` 收集固件文件到仓库根目录的 `firmware/`。每次完整构建前会清理旧的目标固件文件，`firmware/Packages.manifest` 会被移除。

默认管理地址为 `192.168.50.1/24`（也写作 `192.168.50.1/255.255.255.0`，简写为 `50.1/24` 时指同一网段）。默认 WiFi 密码为 `kaiwater/wrt_release`。

每次构建会写入 `/etc/wrt_release`，包含 `RELEASE_ID`、`BUILD_DATE`、`BUILD_MODEL`、`SOURCE_REPO`、`SOURCE_BRANCH`、`SOURCE_REV`、`BUILD_RUN` 等字段；首次启动后会把这些字段追加到 `/etc/openwrt_release`，因此可以直接用：

```sh
cat /etc/wrt_release
ubus call system board
```

确认设备运行的是哪一次构建。GitHub Release 的 tag 使用同一个 `RELEASE_ID`。

## 5. 支持设备

设备配置名来自 `wrt_core/compilecfg/` 和 `wrt_core/deconfig/` 中同名文件。当前支持：

| 厂商 / 平台 | 设备 | 配置名 |
| --- | --- | --- |
| 京东云 | 雅典娜(02) - VIKINGYFY main | `jdcloud_ipq60xx_immwrt` |
| 京东云 | 雅典娜(02) - LiBwrt | `jdcloud_ipq60xx_libwrt` |
| 京东云 | 百里 / AX6000 | `jdcloud_ax6000_immwrt` |
| 阿里云 | AP8220 | `aliyun_ap8220_immwrt` |
| 阿里云 | AP8220 - LiBwrt | `aliyun_ap8220_libwrt` |
| Linksys | MX4200v1、MX4200v2、MX4300 | `linksys_mx4x00_immwrt` |
| Link | NN6000v2 | `link_nn6000v2_immwrt` |
| 奇虎 | 360v6 | `qihoo_360v6_immwrt` |
| 红米 | AX5 | `redmi_ax5_immwrt` |
| 红米 | AX6 | `redmi_ax6_immwrt` |
| 红米 | AX6 - LiBwrt | `redmi_ax6_libwrt` |
| 小米 | AX3600 - VIKINGYFY main | `xiaomi_ax3600_immwrt` |
| 小米 | AX3600 - LiBwrt | `xiaomi_ax3600_libwrt` |
| Tenda | BE12 Pro（MT7987A + MT7992 / mtwifi） | `tenda_be12_pro_immwrt` |
| 红米 | AX6000 | `redmi_ax6000_immwrt21` |
| CMCC（中国移动） | RAX3000M | `cmcc_rax3000m_immwrt` |
| 斐讯 | N1 | `n1_immwrt` |
| 兆能 | M2 | `zn_m2_immwrt` |
| 兆能 | M2 - LiBwrt | `zn_m2_libwrt` |
| Gemtek | W1701K | `gemtek_w1701k_immwrt` |
| x86 | X64 | `x64_immwrt` |

示例：

```bash
./build.sh jdcloud_ipq60xx_immwrt
./build.sh aliyun_ap8220_libwrt
./build.sh redmi_ax6_libwrt container
```

## 6. 配置来源

每个设备由两类文件共同定义：

- `wrt_core/compilecfg/<设备配置名>.ini`：定义源码仓库、分支、构建目录、默认配置片段、可选提交哈希和容器 SDK 镜像。
- `wrt_core/deconfig/<设备配置名>.config`：定义 OpenWrt 目标平台、设备和软件包配置。

不同设备会使用不同上游源码，例如 `VIKINGYFY/immortalwrt`、`immortalwrt/immortalwrt`、`LiBwrt/LibWrt`、`padavanonly/immortalwrt-mt798x`、`chasey-dev/immortalwrt-mt798x-rebase` 或本仓库维护的特定分支。`BUILD_TARGET_SDK` 未配置时，容器构建默认使用 `immortalwrt/sdk:openwrt-25.12`。

部分上游（如 Tenda BE12 Pro / mtwifi）要求使用上游完整 defconfig 作为基底，再叠加设备增量。此类设备在 `.ini` 中使用 `BASE_CONFIG` 指向仓库内的 defconfig，并用 `BASE_CONFIG_FILTER` 排除不需要的机型；构建时顺序为“上游 base config → 设备 delta → compile_base → fragments”。

构建时会按顺序组合配置：

1. 设备专用 `.config`
2. `compile_base.config`
3. `wrt_core/deconfig/fragments/<name>.config` 中的有效配置片段

默认片段由 `compilecfg/*.ini` 的 `CONFIG_FRAGMENTS` 指定：

- 所有设备默认包含 `proxy`。
- IPQ60xx / IPQ807x 设备默认额外包含 `nss`。
- 512MB 内存的 IPQ807x 设备（如 AX3600）额外包含 `nss_mem_512m`，用于把 `nss` 中的 1G NSS 内存档位覆盖为 512M；该片段必须排在 `nss` 之后。
- `nss` 默认使用 12.5 NSS 固件/驱动（与 qosmio NSS-12.5 feed 和 VIKINGYFY 当前版本一致）。如果需要 NSS mesh (802.11s)、WDS 或 IPQ807x RMNET，请在 `nss` 之后追加 `nss_fw_11_4`，切回 11.4 固件/驱动。
- SMB 共享默认使用轻量的 `samba_ksmbd`（`ksmbd-server` + `luci-app-ksmbd`）；需要完整 Samba4 时用 `samba4` 替换，两者不要同时启用。
- USB 支持按设备启用：CS-02 / AP8220 使用 `usb_storage`（USB 3.0 + 存储/网络 kmod），AX3600 没有 USB 口，不启用该 fragment。
- 只有已显式选择 Dockerman 或明确适合运行 Docker 的设备默认包含 `docker_deps`，用于预置手动安装 Docker 所需的运行依赖，避免 NAND 空间紧张或无 USB 设备被默认加入 Docker 依赖。

`ADD_CONFIG_FRAGMENTS` 会在默认片段后追加，`REMOVE_CONFIG_FRAGMENTS` 会从最终片段中移除对应配置片段。移除只表示“不追加这个 fragment”，不会反向修改设备 `.config` 或 `compile_base.config` 中已经写明的配置。

## 7. 三方插件

三方插件主要通过 feeds 机制加入，其中 small-package 源自：

```text
https://github.com/kenzok8/small-package.git
```

相关增删和同步逻辑位于 `wrt_core/update.sh` 编排的 `wrt_core/modules/` 静态阶段。配置片段只选择 Kconfig，不负责 clone 仓库、修改 feeds 或安装 feeds。

## 8. 项目结构说明

- `build.sh`：主编译入口，负责设备选择、模式选择、配置组合、容器构建和固件收集。
- `firmware/`：完整构建后的固件输出目录，由脚本自动创建和刷新。
- `wrt_core/build_container.sh`：容器内构建入口。
- `wrt_core/update.sh`：源码更新、feeds 调整、软件包同步和补丁应用主流程。
- `wrt_core/pre_clone_action.sh`：GitHub Actions 预克隆辅助脚本。
- `wrt_core/compilecfg/`：设备构建元信息 `.ini`。
- `wrt_core/deconfig/`：设备和共享默认配置 `.config`。
- `wrt_core/deconfig/fragments/`：可组合配置片段。
- `wrt_core/modules/`：模块化脚本，包括仓库准备、网络重试、feeds/custom_feed、源码修正、LuCI 修正、服务修正、验证、Docker、CUPS 等静态职责模块。
- `wrt_core/patches/`：补丁、默认设置、Wi-Fi 初始化、NSS 诊断、PBR 规则和其他构建时注入文件。

## 9. OAF（应用过滤）功能使用说明

OAF 的 `appfilter` 服务、`kmod-oaf` 内核模块和 LuCI 页面默认都已安装，且 `appfilter` 随系统启动。默认配置中应用过滤、MAC 过滤、记录开关均为关闭，但服务本身会运行并加载 `kmod-oaf`，所以正常情况下：

```sh
lsmod | grep oaf
```

应能看到 `oaf` 模块。

如果需要启用过滤功能：

1. 打开 LuCI → 服务 → OAF → 高级设置
2. 按需勾选「应用过滤」「MAC 过滤」或「记录」，点击保存
3. 如 OAF 与 NSS 硬件加速冲突，可在同一页面勾选「禁用 HNAT」

也可以直接用 SSH 启用应用过滤：

```sh
uci set fwx.appfilter.enable='1'
uci commit fwx
/etc/init.d/appfilter restart
lsmod | grep oaf
```

如果 `lsmod` 仍为空，依次检查：

```sh
/etc/init.d/appfilter status
logread | grep -i appfilter
modprobe oaf; echo "modprobe exit=$?"
dmesg | tail -30
```

`modprobe` 返回非 0 时，把 `dmesg` 中的 `oaf` / `Unknown symbol` 信息发出来，才能判断是模块依赖还是内核配置问题。

## 10. NSS 12.5 的 station dump 速率

NSS 12.5 的 `nss_wifili` peer stats 结构体比旧版多 16 字节。构建脚本会给 ath11k 增加：

```make
-DNSS_FIRMWARE_VERSION_12_5
```

使其与 qca-nss-drv、ECM 使用相同的结构体布局。否则运行一段时间、客户端数量变化后，`iw dev ... station dump` 可能丢失：

- `rx bitrate`
- `tx bitrate`
- `expected throughput`
- 部分 RX/TX 计数和信号值

同时 `qca-nss-pbuf` 的 `stats_disable` 默认改为 `0`，避免它启动/重启时关闭 ath11k 统计。

另外，LibWrt 原补丁在 `frame_control` 无效时会丢弃所有 RX rate 更新，导致 TX 速率恢复后 RX 仍为 0。构建脚本已参考 VIKINGYFY 的 `999-922-ath11k-nss-fix-station-rate-reporting.patch`，改为只在 firmware 明确提供有效 `frame_control` 时才过滤非数据帧。

如果更看重极限 Wi-Fi 吞吐，可以手动关闭统计：

```sh
uci set pbuf.opt.stats_disable='1'
uci commit pbuf
/etc/init.d/qca-nss-pbuf restart
```

检查当前状态：

```sh
iw dev phy0-ap0 station dump
cat /sys/kernel/debug/ath11k/*/nss_stats 2>/dev/null
cat /sys/kernel/debug/ath11k/*/stats_disable 2>/dev/null
```
