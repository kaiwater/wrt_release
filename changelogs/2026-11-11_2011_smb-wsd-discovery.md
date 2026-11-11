# 2026-11-11 — CS-02：SMB 名字发现（Windows WSD + macOS Bonjour）

## 现象

京东云雅典娜 02（`jdcloud_ipq60xx`，RE-CS-02 / AX6600）两台设备：

- `192.168.2.150` / `AX6600-P1`
- `192.168.2.151` / `AX6600-P2`

Windows 的“网络”和 macOS 的“网络”里都看不到，只能用 `\\192.168.2.x`
或 `smb://192.168.2.x` 访问共享。

## 根因（设备实测）

### 1. wsdd2 绑错接口

```text
ksmbd.@globals[0].interface='wan'      ->  interfaces = br-wan-bypass
wsdd2 启动参数                          ->  -i br-lan
```

`wsdd2` 的 init 固定 `network_get_device ifname lan`，只看 UCI 的 `lan`
（`br-lan`，192.168.12.1/22）；而 SMB 实际挂在上游网段的 `br-wan-bypass`
（192.168.2.150/23）。WSD 组播（UDP 3702）和 LLMNR（UDP 5355）都发在
192.168.2.x，`wsdd2` 收不到。

### 2. macOS 要的不是 WSD，是 mDNS

macOS Finder 的“网络”走 Bonjour（`_smb._tcp`，UDP 5353）：

- `umdns` 只配了 `network='lan'`，mDNS 只在 `br-lan` 上；
- ksmbd 的 `procd_add_mdns` 虽有注册，但 `_smb._tcp` 实际没有广播出去；
- `avahi-daemon` 在跑，但没有 `/etc/avahi/services/smb.service`；
- fw4 的 `wan` zone 只放行了 3702，5353/5355 都被 REJECT。

## 变更

### 1. 功能包（仅 CS-02）

```text
wrt_core/deconfig/fragments/wsdd2.config
  CONFIG_PACKAGE_wsdd2=y

wrt_core/deconfig/fragments/smb_avahi.config
  CONFIG_PACKAGE_ksmbd-avahi-service=y
```

只加到：

```text
wrt_core/compilecfg/jdcloud_ipq60xx_immwrt.ini
wrt_core/compilecfg/jdcloud_ipq60xx_libwrt.ini
```

### 2. 构建期修正 wsdd2 init（通用、安全）

`wrt_core/modules/service_fixes.sh` 新增 `fix_wsdd2_interface()`，在
`stage_post_install_package_fixes` 阶段修改
`feeds/packages/net/wsdd2/files/wsdd2.init`：

```sh
smb_net="$(uci -q get ksmbd.@globals[0].interface)"
smb_net="${smb_net%% *}"
smb_net="${smb_net:-lan}"
network_get_device ifname "$smb_net"
```

跟随 ksmbd 的 `interface`，未配置时回落到 `lan`；其他机型行为不变。
函数可重复执行，上游结构变化时只告警不失败。

### 3. CS-02 专用运行前置

`wrt_core/patches/994_smb_discovery`（安装到 `/etc/uci-defaults/`，
由 `fix_default_set()` 注入），只在 `board_name=jdcloud,re-cs-02` 时执行：

- 防火墙放行 `wan` 的 UDP `3702 5353 5355`（限定 wan 直连网段，
  例如 `192.168.2.0/23`）；
- `umdns.@umdns[0].network` 追加 `wan`，让它同时监听 `br-wan-bypass`
  （umdns 会自动补 5353 规则）；
- 确保 `avahi-daemon` 开机自启；
- `/etc/avahi/services/smb.service` 由 `ksmbd-avahi-service` 包安装。

### 4. 文档与排查脚本

- `docs/smb-discovery-deps.md`：依赖包清单与运行前置。
- `tools/smb-discovery-check.sh`：新增 wsdd2/ksmbd 接口一致性、WSD 自探测、
  mDNS/avahi/umdns 和防火墙检查。

### 5. 范围收敛（按 SMB 后端，不按 USB）

| 机型 | SMB 后端 | 发现依赖 |
|---|---|---|
| `jdcloud_ipq60xx_immwrt/libwrt`（CS-02） | ksmbd | `wsdd2` + `smb_avahi`（全套） |
| `aliyun_ap8220_immwrt/libwrt` | ksmbd | 仅 `wsdd2`（自动 select）；暂不加 `smb_avahi` |
| `xiaomi_ax3600_immwrt/libwrt` | 无（无 USB） | 移除 `samba_ksmbd`，不再需要 |
| samba4 机型（ax6000/n1/x64 等） | samba4 | 上游默认 WSD/NetBIOS/Avahi |

AX3600 的两个 ini 从 `CONFIG_FRAGMENTS` 中去掉了 `samba_ksmbd`：

```text
- nss,nss_mem_512m,samba_ksmbd,proxy
+ nss,nss_mem_512m,proxy
```

`jdcloud_ax6000`（无 USB、共享 eMMC）保留 samba4 默认的发现能力，不动。

## 验收（已在两台 CS-02 上执行）

设备固件：`26.11.05_09.56.36_jdcloud_ipq60xx_libwrt`。

### Windows（WSD + LLMNR）

```text
wsdd2 -i br-wan-bypass  （两台）
XAddrs: http://192.168.2.150:3702/262fc304-...
XAddrs: http://192.168.2.151:3702/7de82794-...

.151 -> .150  AX6600-P1  => 192.168.2.150
.150 -> .151  AX6600-P2  => 192.168.2.151
224.0.0.252:5355 多播    => 正常应答

192.168.2.150:445 open
192.168.2.151:445 open
```

### macOS（Bonjour/mDNS）

修复后从 Mac 上执行：

```text
$ dns-sd -B _smb._tcp local
... _smb._tcp.  AX6600-P1
... _smb._tcp.  AX6600-P2

$ dns-sd -L AX6600-P2 _smb._tcp local
AX6600-P2._smb._tcp.local. can be reached at AX6600-P2.local.:445

$ dns-sd -G v4 AX6600-P1.local
AX6600-P1.local.  192.168.2.150

$ dns-sd -G v4 AX6600-P2.local
AX6600-P2.local.  192.168.2.151
```

### 防火墙

```text
ip saddr 192.168.2.0/23 udp dport { 3702, 5353, 5355 } accept \
  comment "!fw4: Allow-WSD-LLMNR-LAN"
udp dport 5353 accept   # umdns 自动规则（wan/lan 各一条）
```

## 运行期改动的落点

两台设备上已实际修改（重启后仍生效）：

- `/etc/init.d/wsdd2`：改为跟随 ksmbd 接口
  （原文件备份 `/root/wsdd2.init.orig.bak`）
- `/etc/config/firewall`：新增 `Allow-WSD-LLMNR-LAN`
- `/etc/config/umdns`：`network='lan wan'`
- `/etc/avahi/services/smb.service`：新增（对应 `ksmbd-avahi-service`）

## 未做的事

- 本机没有跑完整固件编译（macOS，且 shell 侧无法 git clone GitHub）；
  但 `fix_wsdd2_interface()` 已用设备上取回的原始 `wsdd2.init` 做过逐字节
  diff 验证，生成结果与设备当前运行文件一致。
- 未刷写新固件；下次构建后建议在 CS-02 上复跑
  `tools/smb-discovery-check.sh`。
- 没有默认打开 ksmbd 的 `allow_guest_ipc`。

## 涉及文件

- `wrt_core/deconfig/fragments/wsdd2.config`（新增）
- `wrt_core/deconfig/fragments/smb_avahi.config`（新增）
- `wrt_core/compilecfg/jdcloud_ipq60xx_immwrt.ini`
- `wrt_core/compilecfg/jdcloud_ipq60xx_libwrt.ini`
- `wrt_core/compilecfg/xiaomi_ax3600_immwrt.ini`
- `wrt_core/compilecfg/xiaomi_ax3600_libwrt.ini`
- `wrt_core/modules/service_fixes.sh`（`fix_wsdd2_interface`）
- `wrt_core/modules/target_fixes.sh`（注入 994 脚本）
- `wrt_core/update.sh`（调用 `fix_wsdd2_interface`）
- `wrt_core/patches/994_smb_discovery`（新增）
- `docs/smb-discovery-deps.md`（新增）
- `tools/smb-discovery-check.sh`（新增）
- `README.md`
- `docs/package-inventory.md`
- `changelogs/2026-11-11_2011_smb-wsd-discovery.md`
