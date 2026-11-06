# 2026-11-06 12:07 — 禁止 geodata .dat 进入 rootfs

## 结论

三台目标设备（AP8220 / AX6600 / BE12 Pro）的 rootfs 里**没有** geo `.dat`，只有 overlay 里有运行期数据：

```text
/overlay/upper/usr/share/v2ray/geoip.dat
/overlay/upper/usr/share/v2ray/geosite.dat
```

这是刻意的边界：rootfs 不打包 `.dat`，运行期由 PassWall 下载到 overlay。

## 谁会往 rootfs 放 geo .dat

本仓库相关来源只有一个：

| 包 | 内容 | 进入 rootfs 的条件 |
|---|---|---|
| `v2ray-geoip` | `geoip.dat` | 被选中 |
| `v2ray-geosite` | `geosite.dat` | 被选中 |

这两个包由 `v2ray-geodata` 源包提供，`luci-app-passwall` 通过 Kconfig 选项间接选择：

```text
config PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geodata
    select PACKAGE_v2ray-geoip
    select PACKAGE_v2ray-geosite
    default n
```

因为默认是 `n`，所以三个型号一直没把 `.dat` 打进镜像。但这是“依赖上游默认值”，上游一旦调整默认值，rootfs 就会悄悄多出约 28 MB 未压缩数据。

其他相关包确认不携带 `.dat`：

| 包 | 行为 |
|---|---|
| `geoview` | 只有一个 7.7 MB 的 Go 二进制，读/转换 `.dat`，不携带数据 |
| `xray-core` / `sing-box` | 只有可执行文件 |
| `luci-app-homeproxy` | 依赖 `sing-box`，使用规则集，不带 `.dat` |
| `nikki` | 使用 nftables 文本规则（`geoip_cn.nft`） |
| `luci-app-openclash` | 运行期下载 `Country.mmdb`，不是 `.dat` |

仓库里唯一显式选择 `v2ray-geoip` / `v2ray-geosite` 的是旧的手工配置：

```text
wrt_core/deconfig/redmi_ax6000_immwrt21.config
```

该配置不属于本次三个型号，本次未改动。

## 变更

`light_apps` 增加显式关闭：

```text
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geodata is not set
# CONFIG_PACKAGE_v2ray-geoip is not set
# CONFIG_PACKAGE_v2ray-geosite is not set
```

作用：

- 不再依赖 PassWall 的 `default n`
- 即使上游把默认值改成 `y`，三台设备的 rootfs 也不会出现 `.dat`
- 运行期行为不变，PassWall 仍可下载 `.dat` 到 overlay
- `chnlist` / `chnroute` / `chnroute6` / `gfwlist` 这些文本规则保持原样，压缩率高，继续放在 overlay

## 验证

合并后的配置（三个型号）确认：

```text
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geodata = n
CONFIG_PACKAGE_v2ray-geoip = n
CONFIG_PACKAGE_v2ray-geosite = n
```

镜像与设备侧抽查：

- 解包 `26.11.05_09.59.05_aliyun_ap8220_immwrt` 的 rootfs：无 `geoip.dat` / `geosite.dat` / `.srs` / `.mmdb`
- 解包 `26.11.05_09.56.36_jdcloud_ipq60xx_libwrt` 的 rootfs：同上
- 设备 `/rom` 扫描：只存在 MediaTek WiFi 相关的 `mt7992*.dat`，与代理无关

## 说明

- overlay 里的 `.dat` 无法避免，PassWall 运行时需要；它受 `/etc/sysupgrade.conf` 的 `/usr/share/v2ray/` 保护，sysupgrade 后会保留
- 更新时 PassWall 会把旧数据备份到 `/tmp/bak_v2ray`，那是内存 tmpfs，不占 flash
- 本次只改仓库，未触发编译

## 涉及文件

- `wrt_core/deconfig/fragments/light_apps.config`
- `README.md`
- `changelogs/2026-11-06_1207_rootfs-geodata-guard.md`
