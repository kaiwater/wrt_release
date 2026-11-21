# 2026-11-21 — LibWrt 25.12-nss 重编（000a4e74）与 ksmbd

## 上游

LibWrt 从 `6c363ced06ee` 更新到 `000a4e74b17e`，共 21 个提交：

```text
2e32ec94  Merge Official Source
d29902b7  Merge immortalwrt/openwrt-25.12 into 25.12-nss
7cd348b8  ipq-wifi: update to latest HEAD
f27bf848  ipq-wifi: add Aruba AP-325 BDF
8dda6aaf  ipq-wifi: add BDFs for IPQ4019 Aruba boards
2a768141  px5g-mbedtls: fix the subjectAltName extension
60c494ad  px5g-mbedtls: reject unsupported -addext values
```

其余为 airoha / rockchip / imx / mpc85xx / ipq40xx 等平台补丁。

## 配置

- AX6600 / CS-02：原本就有 `light_apps`
- AP8220 / AX3600 LibWrt：本次补上 `light_apps`

清理内容不变：iStore / QuickStart / lucky / xray-core 及相关 i18n、
PassWall 的 xray 后端和 v2ray geo 数据包。

## SMB：kernel 模式 ksmbd

带 USB 的 profile 已改为 `samba_ksmbd`：

```text
kmod-fs-ksmbd + ksmbd-server（ksmbd.mountd）+ luci-app-ksmbd
```

不再使用 samba4 的 `smbd` / `nmbd`，内存和 CPU 占用更低。

快速设置说明：

```text
docs/ksmbd-quickstart.md
```

覆盖 LuCI 路径、`ksmbd.adduser`、UCI 共享配置、Windows/macOS 访问和
常见排错。AX3600 没有 USB，未启用 ksmbd。

## 构建

本次重编三台：

```text
jdcloud_ipq60xx_libwrt   AX6600 / CS-02
aliyun_ap8220_libwrt     AP8220
xiaomi_ax3600_libwrt     AX3600
```

日志在 QNAP：

```text
/mnt/qnap/logs/<device>-<timestamp>.log
```

## 验证（2026-11-21）

三台设备均用 sysupgrade 保留配置升级：

- CS-02（AX6600）双机：版本 `r38340-000a4e74b1`，内核 6.12.116，配置保留
  （67 / 69 个 config），LAN 地址不变，无线正常，`ksmbd` 运行中，
  `luci-app-quickfile` 未安装、`luci-app-filemanager` 在
- AP8220：P1、P3 已升级验证（66 / 65 个 config，12 个无线接口，
  `ksmbd` 运行中）；P2 按计划留到夜间升级
- AX3600：首版构建的 manifest 被随后 AP8220 的构建覆盖，重编后重新刷机，
  版本 `26.11.21_13.57.33`，配置保留（60 个 config），7 个无线接口

构建产物覆盖问题已在 `build.sh` 修复：构建成功后按 profile 复制到
`artifacts/<profile>/`，见 `2026-11-21_1410_artifact-keep-per-profile.md`。

## Release

```text
26.11.21_13.01.22_jdcloud_ipq60xx_libwrt
26.11.21_13.41.40_aliyun_ap8220_libwrt
26.11.21_13.57.33_xiaomi_ax3600_libwrt
```

## 注意

- 本次只重编 LibWrt 线；VIKINGYFY / chasey 两条线没有上游变化
- ksmbd 的共享目录必须先挂载并存在，否则服务启动后客户端会看到空列表
- release notes 会通过 `wrt_core/release_changelog.sh` 自动带上本文件
