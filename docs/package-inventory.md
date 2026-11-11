# 跨机型软件包清单

- 生成时间：2026-11-09
- 版本来源：`26.11.05_09.56.36_jdcloud_ipq60xx_libwrt`、`26.11.05_09.59.05_aliyun_ap8220_immwrt`、`26.10.31_06.57.45_tenda_be12_pro_immwrt` 的 manifest
- 共享基础包来自 `compile_base.config`，其余来自 fragments

## 1. 共享基础包（compile_base.config）

| 包 | libwrt | ap8220 | be12 |
|---|---|---|---|
| `dmesg` | 2.41.5-r1 | 2.42.2-r1 | 2.41.5-r1 |
| `proto-bonding` | 2021.04.09-r1 | 2021.04.09-r1 | 2021.04.09-r1 |
| `luci-proto-wireguard` | 26.298.29275~c84adb9 | 26.302.04020~df794c7 | 26.298.29275~c84adb9 |
| `luci-proto-relay` | 26.298.29275~c84adb9 | 26.302.04020~df794c7 | 26.298.29275~c84adb9 |
| `luci-lib-ipkg` | 26.298.29275~c84adb9 | 26.302.04020~df794c7 | 26.298.29275~c84adb9 |
| `libopenssl-legacy` | 3.5.9-r1 | 3.5.9-r1 | 3.5.9-r1 |
| `ucode-mod-math` | 2026.01.16~85922056-r2 | 2026.07.09~b885dd0f-r1 | 2026.01.16~85922056-r2 |
| `default-settings` | 29 | 29 | 29 |
| `default-settings-chn` | 29 | 29 | 29 |
| `coremark` | 2025.05.01~1f483d5b-r1 | 2025.05.01~1f483d5b-r1 | 2025.05.01~1f483d5b-r1 |
| `iptables-nft` | 1.8.10-r3 | 1.8.10-r4 | 1.8.10-r3 |
| `ip6tables-nft` | 1.8.10-r3 | 1.8.10-r4 | 1.8.10-r3 |
| `zerotier` | 1.16.2-r1 | 1.16.2-r1 | 1.16.2-r1 |
| `luci-app-istorex` | 0.6.6 | 0.6.6 | - |
| `luci-app-lucky` | 3.0.0-r31 | 3.0.0-r31 | 3.0.0-r30 |
| `luci-app-oaf` | 7.0-r2 | 7.0-r2 | 7.0-r2 |
| `luci-app-pbr` | 1.2.2-r20 | 1.2.2-r20 | 1.2.2-r20 |
| `luci-app-smartdns` | 1.2026.48.3-r1 | 1.2026.48.3-r1 | 1.2026.48.2-r2 |
| `luci-app-ttyd` | 26.298.29275~c84adb9 | 26.302.04020~df794c7 | 26.298.29275~c84adb9 |
| `luci-app-upnp` | 26.298.29275~c84adb9 | 26.302.04020~df794c7 | 26.298.29275~c84adb9 |
| `luci-app-wol` | 26.298.29275~c84adb9 | 26.302.04020~df794c7 | 26.298.29275~c84adb9 |
| `luci-app-filemanager` | 26.298.29275~c84adb9 | 26.302.04020~df794c7 | 26.298.29275~c84adb9 |
| `kmod-fs-exfat` | 6.12.112-r1 | 6.18.55-r1 | 6.12.112-r1 |
| `kmod-fs-vfat` | 6.12.112-r1 | 6.18.55-r1 | 6.12.112-r1 |
| `kmod-netlink-diag` | 6.12.112-r1 | 6.18.55-r1 | 6.12.112-r1 |
| `kmod-inet-diag` | 6.12.112-r1 | 6.18.55-r1 | 6.12.112-r1 |
| `kmod-tls` | 6.12.112-r1 | 6.18.55-r1 | 6.12.112-r1 |
| `kmod-tun` | 6.12.112-r1 | 6.18.55-r1 | 6.12.112-r1 |
| `htop` | 3.5.3-r1 | 3.5.3-r1 | 3.5.3-r1 |
| `fuse-utils` | 2.9.9-r2 | 2.9.9-r2 | 2.9.9-r2 |
| `ntfs3-mount` | 10 | 10 | 10 |
| `openssh-sftp-server` | 10.6_p1-r2 | 10.6_p1-r1 | 10.6_p1-r1 |
| `tcpdump` | 4.99.6-r1 | 4.99.7-r1 | 4.99.6-r1 |
| `sgdisk` | 1.0.10-r1 | 1.0.10-r1 | 1.0.10-r1 |
| `openssl-util` | 3.5.9-r1 | 3.5.9-r1 | 3.5.9-r1 |
| `resize2fs` | 1.47.3-r1 | 1.47.4-r1 | 1.47.3-r1 |
| `qrencode` | 4.1.1-r2 | 4.1.1-r2 | 4.1.1-r2 |
| `smartmontools-drivedb` | 7.5-r1 | 7.5-r1 | - |
| `mii-tool` | 2.10-r2 | 2.10-r2 | 2.10-r2 |
| `xl2tpd` | 1.3.18-r2 | 1.3.18-r3 | 1.3.18-r2 |
| `xz-utils` | 5.8.3-r1 | 5.8.4-r2 | 5.8.3-r1 |
| `luci-app-adguardhome` | 25.266.24360~3610820 | 25.266.24360~3610820 | 25.266.24360~3610820 |
| `luci-app-autoreboot` | 26.298.29275~c84adb9 | 26.302.04020~df794c7 | 26.298.29275~c84adb9 |
| `luci-app-diskman` | 0.2.13-r1 | 0.2.13-r1 | - |
| `luci-app-vlmcsd` | 26.298.29275~c84adb9 | 26.302.04020~df794c7 | 26.298.29275~c84adb9 |
| `at` | 3.2.5-r1 | 3.2.5-r1 | 3.2.5-r1 |
| `bash` | 5.3-r5 | 5.3-r5 | 5.3-r5 |
| `bc` | 1.08.2-r1 | 1.08.2-r2 | 1.08.2-r1 |
| `bind-dig` | 9.20.30-r1 | 9.20.30-r1 | 9.20.30-r1 |
| `btop` | 1.4.7-r1 | 1.4.7-r1 | 1.4.7-r1 |
| `coreutils` | 9.9-r2 | 9.11-r1 | 9.9-r2 |
| `coreutils-base64` | 9.9-r2 | 9.11-r1 | 9.9-r2 |
| `coreutils-cksum` | 9.9-r2 | 9.11-r1 | 9.9-r2 |
| `coreutils-nohup` | 9.9-r2 | 9.11-r1 | 9.9-r2 |
| `coreutils-shuf` | 9.9-r2 | 9.11-r1 | 9.9-r2 |
| `hostapd-utils` | 2025.08.26~ca266cc2-r6 | 2026.08.07~831364bf-r4 | 2025.08.26~ca266cc2-r6 |
| `iperf3` | 3.22-r1 | 3.22-r1 | 3.22-r1 |
| `kmod-zram` | 6.12.112-r1 | 6.18.55-r1 | 6.12.112-r1 |
| `zram-swap` | 32 | 32 | 32 |
| `nano` | 9.3-r1 | 9.3-r3 | 9.3-r1 |
| `screen` | 5.0.1-r1 | 5.0.1-r1 | 5.0.1-r1 |
| `socat` | 1.8.1.1-r1 | 1.8.1.1-r1 | 1.8.1.1-r1 |
| `umdns` | 2026.10.04~defe7ccf-r1 | 2026.10.04~defe7ccf-r1 | 2026.10.04~defe7ccf-r1 |
| `unzip` | 6.0-r9 | 6.0-r9 | 6.0-r9 |
| `wget-ssl` | 1.25.0-r3 | 1.25.0-r5 | 1.25.0-r3 |
| `luci-app-commands` | 26.298.29275~c84adb9 | 26.302.04020~df794c7 | 26.298.29275~c84adb9 |
| `luci-app-ddns` | 26.298.29275~c84adb9 | 26.302.04020~df794c7 | 26.298.29275~c84adb9 |
| `luci-app-socat` | 1.0-r6 | 1.0-r6 | 1.0-r6 |
| `luci-app-zerotier` | 26.298.29275~c84adb9 | 26.302.04020~df794c7 | 26.298.29275~c84adb9 |
| `luci-i18n-zerotier-zh-cn` | 26.298.29275~c84adb9 | 26.302.04020~df794c7 | 26.298.29275~c84adb9 |
| `luci-theme-bootstrap` | 26.298.29275~c84adb9 | 26.302.04020~df794c7 | 26.298.29275~c84adb9 |
| `luci-theme-argon` | 2.4.3-r20250722 | 2.4.3-r20250722 | 2.4.3-r20250722 |

合计 72 项。

## 2. 片段附加包

### proxy

使用机型：`aliyun_ap8220_immwrt`、`aliyun_ap8220_libwrt`、`cmcc_rax3000m_immwrt`、`gemtek_w1701k_immwrt`、`jdcloud_ax6000_immwrt`、`jdcloud_ipq60xx_immwrt`、`jdcloud_ipq60xx_libwrt`、`link_nn6000v2_immwrt`、`linksys_mx4x00_immwrt`、`n1_immwrt`、`qihoo_360v6_immwrt`、`redmi_ax5_immwrt`、`redmi_ax6_immwrt`、`redmi_ax6_libwrt`、`supergateway_s20m_immwrt`、`tenda_be12_pro_immwrt`、`x64_immwrt`、`xiaomi_ax3600_immwrt`、`xiaomi_ax3600_libwrt`、`zn_m2_immwrt`、`zn_m2_libwrt`

| 包 | libwrt | ap8220 | be12 |
|---|---|---|---|
| `luci-app-passwall` | 26.11.3-r1 | 26.11.3-r1 | 26.10.29-r1 |
| `sing-box` | 1.15.0_alpha13-r1 | 1.15.0_alpha13-r1 | 1.15.0_alpha13-r1 |

### nss

使用机型：`aliyun_ap8220_immwrt`、`aliyun_ap8220_libwrt`、`jdcloud_ipq60xx_immwrt`、`jdcloud_ipq60xx_libwrt`、`link_nn6000v2_immwrt`、`linksys_mx4x00_immwrt`、`qihoo_360v6_immwrt`、`redmi_ax5_immwrt`、`redmi_ax6_immwrt`、`redmi_ax6_libwrt`、`xiaomi_ax3600_immwrt`、`xiaomi_ax3600_libwrt`、`zn_m2_immwrt`、`zn_m2_libwrt`

| 包 | libwrt | ap8220 | be12 |
|---|---|---|---|
| `sqm-scripts-nss` | 20240510-r1 | - | - |
| `kmod-qca-mcs` | 6.12.112.12.5.2024.09.04~e1c59f7-r2 | 6.18.55.13.1.2025.10.08~da120b1-r3 | - |
| `MAC80211_MESH` | - | - | - |
| `kmod-qca-nss-drv-igs` | 6.12.112.12.5.2024.09.11~51be82d-r8 | 6.18.55.12.5.5.2024.09.12~51be82d-r13 | - |
| `kmod-qca-nss-drv-l2tpv2` | 6.12.112.12.5.2024.09.11~51be82d-r8 | 6.18.55.12.5.5.2024.09.12~51be82d-r13 | - |
| `kmod-qca-nss-drv-lag-mgr` | 6.12.112.12.5.2024.09.11~51be82d-r8 | 6.18.55.12.5.5.2024.09.12~51be82d-r13 | - |
| `kmod-qca-nss-drv-pppoe` | 6.12.112.12.5.2024.09.11~51be82d-r8 | 6.18.55.12.5.5.2024.09.12~51be82d-r13 | - |
| `kmod-qca-nss-drv-pptp` | 6.12.112.12.5.2024.09.11~51be82d-r8 | 6.18.55.12.5.5.2024.09.12~51be82d-r13 | - |

### nss_mem_512m

使用机型：`xiaomi_ax3600_immwrt`、`xiaomi_ax3600_libwrt`

### nss_fw_11_4

### samba_ksmbd

使用机型：`aliyun_ap8220_immwrt`、`aliyun_ap8220_libwrt`、`jdcloud_ipq60xx_immwrt`、`jdcloud_ipq60xx_libwrt`

| 包 | libwrt | ap8220 | be12 |
|---|---|---|---|
| `ksmbd-server` | 3.5.6-r1 | 3.5.7-r1 | - |
| `luci-app-ksmbd` | 26.298.29275~c84adb9 | 26.302.04020~df794c7 | - |

### samba4

| 包 | libwrt | ap8220 | be12 |
|---|---|---|---|
| `luci-app-samba4` | - | - | - |

### usb_storage

使用机型：`aliyun_ap8220_immwrt`、`aliyun_ap8220_libwrt`、`jdcloud_ipq60xx_immwrt`、`jdcloud_ipq60xx_libwrt`

| 包 | libwrt | ap8220 | be12 |
|---|---|---|---|
| `kmod-usb3` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-usb-dwc3` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-usb-dwc3-qcom` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-usb2` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-usb-ehci` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-usb-ohci` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-usb-acm` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-usb-net-huawei-cdc-ncm` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-usb-net-ipheth` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-usb-net-rndis` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-usb-net-asix-ax88179` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-usb-net-rtl8152` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-usb-net-sierrawireless` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-usb-serial-qualcomm` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-usb-storage` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-usb-storage-extras` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-usb-storage-uas` | 6.12.112-r1 | 6.18.55-r1 | - |
| `usbutils` | 019-r1 | 020-r1 | - |
| `usbmuxd` | 2025.02.01~523f7004-r1 | 2025.02.01~523f7004-r1 | - |

### docker_deps

使用机型：`jdcloud_ax6000_immwrt`、`jdcloud_ipq60xx_immwrt`、`jdcloud_ipq60xx_libwrt`、`link_nn6000v2_immwrt`、`n1_immwrt`、`x64_immwrt`

| 包 | libwrt | ap8220 | be12 |
|---|---|---|---|
| `fuse-overlayfs` | 1.15-r1 | - | - |
| `kmod-crypto-acompress` | 6.12.112-r1 | 6.18.55-r1 | 6.12.112-r1 |
| `kmod-crypto-blake2b` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-crypto-xxhash` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-fs-btrfs` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-lib-lzo` | 6.12.112-r1 | 6.18.55-r1 | 6.12.112-r1 |
| `kmod-lib-raid6` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-lib-xor` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-lib-xxhash` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-lib-zlib-deflate` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-lib-zlib-inflate` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-lib-zstd` | 6.12.112-r1 | 6.18.55-r1 | - |
| `kmod-br-netfilter` | 6.12.112-r1 | - | - |
| `kmod-ipt-nat` | 6.12.112-r1 | - | 6.12.112-r1 |
| `kmod-ipt-nat6` | 6.12.112-r1 | - | - |
| `kmod-ipt-physdev` | 6.12.112-r1 | - | - |
| `kmod-nf-ipvs` | 6.12.112-r1 | - | - |
| `kmod-nf-nat6` | 6.12.112-r1 | - | - |
| `kmod-nft-queue` | 6.12.112-r1 | - | - |
| `kmod-dummy` | 6.12.112-r1 | - | 6.12.112-r1 |
| `kmod-veth` | 6.12.112-r1 | - | - |
| `iptables-mod-extra` | 1.8.10-r3 | - | 1.8.10-r3 |
| `nftables` | - | - | - |
| `kmod-nft-nat` | 6.12.112-r1 | 6.18.55-r1 | 6.12.112-r1 |
| `kmod-nft-netdev` | 6.12.112-r1 | - | - |
| `iptables-nft` | 1.8.10-r3 | 1.8.10-r4 | 1.8.10-r3 |
| `ip6tables-nft` | 1.8.10-r3 | 1.8.10-r4 | 1.8.10-r3 |

### light_apps

使用机型：`aliyun_ap8220_immwrt`、`jdcloud_ipq60xx_libwrt`、`tenda_be12_pro_immwrt`

| 包 | libwrt | ap8220 | be12 |
|---|---|---|---|
| `luci-app-passwall_INCLUDE_SingBox` | - | - | - |

关闭：`luci-app-istorex`、`luci-app-store`、`luci-app-quickstart`、`quickstart`、`luci-app-lucky`、`lucky`、`luci-app-passwall_INCLUDE_Xray`、`xray-core`、`luci-app-passwall_INCLUDE_V2ray_Geodata`、`v2ray-geoip`、`v2ray-geosite`

### tenda_be12_pro_minimal

使用机型：`tenda_be12_pro_immwrt`

关闭：`luci-app-diskman`、`smartmontools-drivedb`、`sgdisk`、`resize2fs`、`kmod-fs-exfat`、`kmod-fs-vfat`

## 3. 机型与片段

| 机型 | fragments |
|---|---|
| `aliyun_ap8220_immwrt` | nss, samba_ksmbd, usb_storage, proxy, light_apps |
| `aliyun_ap8220_libwrt` | nss, samba_ksmbd, usb_storage, proxy |
| `cmcc_rax3000m_immwrt` | proxy |
| `gemtek_w1701k_immwrt` | proxy |
| `jdcloud_ax6000_immwrt` | docker_deps, proxy |
| `jdcloud_ipq60xx_immwrt` | nss, samba_ksmbd, wsdd2, smb_avahi, usb_storage, docker_deps, proxy |
| `jdcloud_ipq60xx_libwrt` | nss, samba_ksmbd, wsdd2, smb_avahi, usb_storage, docker_deps, proxy, light_apps |
| `link_nn6000v2_immwrt` | nss, docker_deps, proxy |
| `linksys_mx4x00_immwrt` | nss, proxy |
| `n1_immwrt` | docker_deps, proxy |
| `qihoo_360v6_immwrt` | nss, proxy |
| `redmi_ax5_immwrt` | nss, proxy |
| `redmi_ax6_immwrt` | nss, proxy |
| `redmi_ax6_libwrt` | nss, proxy |
| `supergateway_s20m_immwrt` | proxy |
| `tenda_be12_pro_immwrt` | proxy, light_apps, tenda_be12_pro_minimal |
| `x64_immwrt` | docker_deps, proxy |
| `xiaomi_ax3600_immwrt` | nss, nss_mem_512m, proxy |
| `xiaomi_ax3600_libwrt` | nss, nss_mem_512m, proxy |
| `zn_m2_immwrt` | nss, proxy |
| `zn_m2_libwrt` | nss, proxy |

## 4. 上游更新检查（2026-11-09）

对比对象：本次构建 manifest 中的版本 vs 各上游最新 release / 主分支。

| 包 | 构建内版本 | 上游最新 | 状态 | 说明 |
|---|---|---|---|---|
| `xray-core` | 26.10.31 | **26.11.9**（11-09） | 可更新 | 新增 XDRIVE 传输、默认 Chrome 155+ 指纹 |
| `luci-app-passwall` | 26.11.3 | 主分支 11-08 | 可更新 | 节点 DNS 提取、分享链接解析、主题布局修复等 |
| `tailscale` | 1.104.1 | **1.104.5**（11-03） | 可更新 | 仅 LibWrt 机型包含 |
| `sing-box` | 1.15.0-alpha13 | 1.15.0-alpha13 | 最新 | 稳定版为 1.14.4 |
| `lucky` | 3.5.0 | 3.5.0（10-29） | 最新 | |
| `geoview` | 0.2.9 | 0.2.9（10-28） | 最新 | |
| `smartdns` | 48.4 | 48.4（08-05） | 最新 | |
| `zerotier` | 1.16.2 | 1.16.2（05-28） | 最新 | |
| `appfilter` / OAF | 7.0.2 | 主分支 10-28 | 基本最新 | 上游 release 仍为 7.0.1 |
| `luci-app-adguardhome` | 25.266 | — | 仅 LuCI | 未打包 AdGuardHome 二进制（`INCLUDE_binary=n`） |

补充：

- `kenzok8/small-package` 在 11-05 之后有大量 `update` 提交（到 11-09），主要是个别包版本号刷新，下次构建会自然带上
- LuCI / OpenWrt 基础包跟随各自 feed 分支：LibWrt 与 BE12 当前为 `26.298`，AP8220 为 `26.302`，每次构建会自动刷新，没有单独的 changelog 需要跟踪

### 建议

- 无安全紧急项
- 下次构建值得顺带带上：`xray-core 26.11.9`、`passwall` 的 LuCI 修复
- `tailscale` 只影响 LibWrt 机型，需要时再更新
