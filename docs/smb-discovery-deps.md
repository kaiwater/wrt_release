# wsdd2 / ksmbd 名字发现依赖清单（jdcloud_ipq60xx / CS-02 / AX6600）

适用机型：`jdcloud_ipq60xx_immwrt`、`jdcloud_ipq60xx_libwrt`（京东云雅典娜 02，
RE-CS-02 / AX6600）。其他机型不在本清单范围内。

范围约定（按 SMB 后端，不按 USB）：

- CS-02（ksmbd）：全套，`wsdd2` + `ksmbd-avahi-service` + `avahi-dbus-daemon` + `umdns`。
- AP8220（ksmbd）：暂只保留 `wsdd2`（Windows）；macOS 需要时再追加 `smb_avahi`。
- AX3600：无 USB，已移除 `samba_ksmbd`，不需要本清单。
- samba4 机型（ax6000/n1/x64 等）：上游默认已带 WSD/NetBIOS/Avahi，不需要额外片段。

## 0. 先给结论

- **`wsdd2` 本身没有运行期依赖**，只链接 libc（上游 Makefile 里没有 `DEPENDS`）。
- 看起来很多依赖，其实全部来自 `ksmbd-server → kmod-fs-ksmbd`，这些在启用
  `samba_ksmbd` 片段时就已经被 Kconfig 自动拉进来了。
- 需要“补丁”显式声明的，通常只有一项：**`wsdd2`**。其余是供核对/审计用的完整闭包。

## 0.1 运行前置（比依赖更重要）

装包只解决“有没有”，下面两条决定“能不能被发现”：

1. **wsdd2 必须和 ksmbd 绑在同一接口。**
   上游 `wsdd2.init` 固定用 UCI 的 `lan`；如果 ksmbd 配在 `wan`
   （CS-02 的 `br-wan-bypass`），WSD/LLMNR 会广播到错误的网桥。
   本仓库由 `wrt_core/modules/service_fixes.sh` 的 `fix_wsdd2_interface()`
   在构建期改成跟随 `ksmbd.@globals[0].interface`（默认回落到 `lan`）。

2. **该接口所在 firewall zone 要放行 UDP 3702 / 5353 / 5355。**
   fw4 的 `wan` zone 默认 `input=REJECT`。CS-02 由
   `wrt_core/patches/994_smb_discovery` 在首次启动时补一条
   `Allow-WSD-LLMNR` 规则（仅 `jdcloud,re-cs-02`，限定 wan 直连网段）。

3. **macOS 需要 mDNS（`_smb._tcp`），不是 WSD。**
   `ksmbd-avahi-service` 安装 `/etc/avahi/services/smb.service`；
   `umdns` 同时监听 `lan wan`，否则 `AX6600-P1.local` 和 `_smb._tcp`
   只在 br-lan 上可见。CS-02 的 `994_smb_discovery` 会完成这两项配置。

自检：

```sh
ps w | grep '[w]sdd2'                  # 看 -i 是否等于 ksmbd 的接口设备
uci get ksmbd.@globals[0].interface    # 期望 wan（CS-02）
uci get umdns.@umdns[0].network        # 期望包含 wan（CS-02 为 lan wan）
nft list ruleset | grep -E '3702|5353|5355'
```

## 1. 功能包（patch 需要显式带上的）

| Kconfig 符号 | 作用 | 来源 |
|---|---|---|
| `CONFIG_PACKAGE_wsdd2=y` | Windows：WSD（UDP 3702）+ LLMNR（UDP 5355） | `feeds/packages/net/wsdd2` |
| `CONFIG_PACKAGE_ksmbd-avahi-service=y` | macOS：mDNS `_smb._tcp`（UDP 5353） | `feeds/packages/net/ksmbd-tools` |
| `CONFIG_PACKAGE_avahi-dbus-daemon=y` | mDNS 守护进程（`avahi-daemon` 的默认变体） | `feeds/packages/libs/avahi` |
| `CONFIG_PACKAGE_umdns=y` | `.local` 主机名解析 | `feeds/base/network/services/umdns` |

`ksmbd-server` 的 Makefile 里有 `select PACKAGE_wsdd2`，理论上会自动选中；本仓库
额外用 `wrt_core/deconfig/fragments/wsdd2.config` 固定，避免上游改动后静默丢失。
`ksmbd-avahi-service` 由 `wrt_core/deconfig/fragments/smb_avahi.config` 固定，
它依赖的 `avahi-daemon` 由已安装的 `avahi-dbus-daemon` 提供（`PROVIDES`）。

## 2. 已有但必须确保存在的功能包

| Kconfig 符号 | 说明 |
|---|---|
| `CONFIG_PACKAGE_ksmbd-server=y` | `ksmbd.mountd`，kmod 模式的用户态服务 |
| `CONFIG_PACKAGE_luci-app-ksmbd=y` | LuCI 页面（`+luci-base +ksmbd-server`） |
| `CONFIG_PACKAGE_kmod-fs-ksmbd` | `ksmbd.ko`，由 `ksmbd-server` 依赖自动拉入 |

## 3. 用户态运行期依赖

| Kconfig 符号 | 包名（ABI） | 说明 |
|---|---|---|
| `libnl-core` | `libnl-core200` | `+libpthread`（musl 下由 libc 提供） |
| `libnl-genl` | `libnl-genl200` | 依赖 `libnl-core200` |
| `wsdd2` | `wsdd2` | 只依赖 `libc` |
| `ksmbd-avahi-service` | `ksmbd-avahi-service` | 只装 `/etc/avahi/services/smb.service` |
| `avahi-daemon` | `avahi-dbus-daemon` | 由 `ksmbd-avahi-service` 依赖；`avahi-dbus-daemon` 已 `PROVIDES` |
| `umdns` | `umdns` | 基础镜像已带，负责 `.local` 解析 |
| `libiconv-full` | `libiconv-full` | 仅 `CONFIG_BUILD_NLS=y` 时 |
| `libintl-full` | `libintl-full` | 仅 `CONFIG_BUILD_NLS=y` 时 |

> `libiconv-full` / `libintl-full` 在 musl + 默认 `CONFIG_BUILD_NLS` 未开时不会出现。

## 4. `kmod-fs-ksmbd` 的内核模块闭包

### 4.1 直接依赖（15 个）

```text
kmod-nls-base
kmod-nls-utf8
kmod-crypto-md5
kmod-crypto-hmac
kmod-crypto-ecb
kmod-crypto-des
kmod-crypto-sha256
kmod-crypto-cmac
kmod-crypto-sha512
kmod-crypto-aead
kmod-crypto-ccm
kmod-crypto-gcm
kmod-asn1-decoder
kmod-oid-registry
kmod-fs-smbfs-common
```

### 4.2 传递依赖（12 个）

```text
kmod-crypto-hash       # md5/hmac/sha256/cmac/sha512/manager/ghash/rng
kmod-crypto-manager    # hmac/ecb/ctr
kmod-crypto-ctr        # ccm/gcm
kmod-crypto-ghash      # gcm
kmod-crypto-null       # gcm
kmod-crypto-gf128      # ghash
kmod-crypto-seqiv      # ctr
kmod-crypto-rng        # seqiv/geniv
kmod-crypto-geniv      # seqiv
kmod-crypto-sha3       # rng
kmod-fs-netfs          # smbfs-common
kmod-nls-ucs2-utils    # smbfs-common
```

### 4.3 依赖关系（便于核对）

```text
kmod-fs-ksmbd
├── kmod-nls-base
├── kmod-nls-utf8
├── kmod-crypto-md5      → kmod-crypto-hash
├── kmod-crypto-hmac     → kmod-crypto-hash, kmod-crypto-manager
├── kmod-crypto-ecb      → kmod-crypto-manager
├── kmod-crypto-des
├── kmod-crypto-sha256   → kmod-crypto-hash
├── kmod-crypto-cmac     → kmod-crypto-hash
├── kmod-crypto-sha512   → kmod-crypto-hash
├── kmod-crypto-aead
├── kmod-crypto-ccm      → kmod-crypto-ctr, kmod-crypto-aead
├── kmod-crypto-gcm      → kmod-crypto-ctr, kmod-crypto-ghash, kmod-crypto-null
├── kmod-asn1-decoder
├── kmod-oid-registry
└── kmod-fs-smbfs-common → kmod-fs-netfs, kmod-nls-ucs2-utils

kmod-crypto-manager → kmod-crypto-aead, kmod-crypto-hash
kmod-crypto-ctr     → kmod-crypto-manager, kmod-crypto-seqiv
kmod-crypto-seqiv   → kmod-crypto-aead, kmod-crypto-rng, kmod-crypto-geniv
kmod-crypto-rng     → kmod-crypto-hash, kmod-crypto-hmac, kmod-crypto-sha512, kmod-crypto-sha3
kmod-crypto-ghash   → kmod-crypto-gf128, kmod-crypto-hash
```

## 5. 构建期依赖（不是装到设备上的）

| 包 | 用途 |
|---|---|
| `glib2` | `ksmbd-tools` 的 `PKG_BUILD_DEPENDS`（只影响编译） |
| `meson` / `ninja` / `pkg-config` | OpenWrt 主机工具，构建系统自带 |
| `kmod-fs-ksmbd` 对应的内核选项 | 由 `KCONFIG` 自动处理，无需手写 |

`wsdd2` 是单文件 C 程序，直接用 `$(TARGET_CC)` 编译，不需要额外 host 依赖。

## 6. patch/清单里怎么写

最小写法（推荐）：

```text
CONFIG_PACKAGE_wsdd2=y
CONFIG_PACKAGE_ksmbd-avahi-service=y
CONFIG_PACKAGE_avahi-dbus-daemon=y
CONFIG_PACKAGE_umdns=y
```

要求“依赖写全”的场合，按第 1 + 2 + 3 节列即可；第 4 节的 kmod 闭包由
`kmod-fs-ksmbd` 的 Kconfig `DEPENDS` 自动展开，重复写不会改变结果，只用于审计。

## 7. 版本参考

| 包 | jdcloud_ipq60xx_libwrt | jdcloud_ipq60xx_immwrt |
|---|---|---|
| `ksmbd-server` | 3.5.6-r1 | 3.5.7-r1 |
| `wsdd2` | 以构建 manifest 为准（约 `2023.12.21~b676d8ac-r2`） | 同左 |
| `ksmbd-avahi-service` | 随 `ksmbd-tools` 版本 | 同左 |
| `avahi-dbus-daemon` | 0.9_rc5-r1 | 0.9_rc5-r1 |
| `libnl` | 3.12.0（ABI 200） | 3.12.0（ABI 200） |

> 版本值来自 `docs/package-inventory.md` 与当前 feed；以实际 `bin/targets/.../manifest`
> 为准。
