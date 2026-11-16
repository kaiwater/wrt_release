# 2026-11-17 — LibWrt AP8220/AX3600 补上 light_apps

## 问题

AP8220 和 AX3600 的 LibWrt 配置缺少 `light_apps` 片段，导致以下软件包仍进入镜像：

```text
luci-app-istorex
luci-app-store
luci-app-quickstart
luci-app-lucky
lucky
quickstart
xray-core
```

已在实际 manifest 中确认。

## 修复

补充 `light_apps` 到：

```text
aliyun_ap8220_libwrt
xiaomi_ax3600_libwrt
xiaomi_ax3600_immwrt
jdcloud_ipq60xx_immwrt
```

AP8220 的 immwrt 与 CS-02 的 LibWrt 之前已经包含该片段，这次主要补齐同类机型的缺口。

## 影响

下一次构建会移除：

- iStore / iStoreX / store
- QuickStart
- lucky
- xray-core
- PassWall 的 Xray 后端（保留 sing-box）
- v2ray geo 数据包

当前已升级的 AP8220/AX3600 固件仍包含这些包；需要重新构建并刷机才会生效。

## 待确认

以下非当前活跃机型仍没有 `light_apps`，暂未改动：

```text
redmi_ax6_libwrt
zn_m2_libwrt
```
