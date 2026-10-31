# 2026-10-31 08:07 — Tenda BE12 Pro Release：恢复两个 WiFi 芯片温度

## 本次发布内容

Tenda BE12 Pro（MT7987A + MT7992，`mt_wifi7` 厂商驱动）恢复 LuCI 概览里的
两个 WiFi 芯片温度，并完成一次真机刷机验证。

相关提交：

- `57ee542` Restore mtwifi WiFi chip temperature readings
- `e9d4e82` Prefer the wiphy device for the mtwifi hwmon
- `ffbae67` Expose mtwifi temperature through procfs
- `20ff85c` Fix the procfs temperature API for Linux 6.12

## 背景

`mt_wifi7` 驱动只在内部为热保护读取芯片温度
（`RTMP_GET_TEMPERATURE()` → `HWCMD_ID_GET_TEMPERATURE`），没有任何用户态出口：

- 没有 hwmon / thermal zone / sysfs / proc 温度节点
- 旧的 WEXT 私有 ioctl `OID_GET_CPU_TEMPERATURE` 在这套构建里未注册
  （`/proc/net/wireless` 不存在）
- cfg80211 vendor 命令存在，但 OpenWrt 的 `iw` 没有 vendor 子命令，
  `mwctl` 也没有温度命令

autocore 的 `/sbin/tempinfo` 只认 `phy*/hwmon*/temp1_input`（mt76 提供），
所以此前的概览里只剩 CPU 温度。

## 实现

驱动补丁 `wrt_core/patches/mtwifi-temperature-proc.patch`
（构建时装为 `package/mtk/drivers/mt_wifi7/patches/900-add-temperature-proc.patch`）：

- 在 hwifi 下发 `MT_80211_DRIVER_REGISTER` 时创建
  `/proc/net/mt_wifi/`，每个 band 一个 `tempN`（只读）
- 读取时按需调用 `RTMP_GET_TEMPERATURE()`，输出**毫摄氏度**
- radio 未启动（`fRTMP_ADAPTER_START_UP` 未置位）或读到 0 时返回
  `-ENODATA`，避免接口关闭时卡在 MCU 超时
- `MT_80211_DRIVER_UNREGISTER` 时 `proc_remove()`

`/sbin/tempinfo` 增加回退：hwmon 路径为空时读
`/proc/net/mt_wifi/temp*`。

### 为什么不用 hwmon

`hwmon_device_register_with_info()` / `hwmon_device_unregister()` 是
`EXPORT_SYMBOL_GPL`，而 `mt_wifi` 是 `MODULE_LICENSE("Proprietary")`，
modpost 直接拒绝：

```text
ERROR: modpost: GPL-incompatible module mt_wifi.ko uses GPL-only symbol
       'hwmon_device_register_with_info'
```

procfs 的 `proc_mkdir` / `proc_create_data` / `proc_remove` 都是非 GPL 导出，
因此改走 procfs。

## 构建与刷机验证

CI `Build WRT`（run 41140776194，commit `20ff85c`）成功，耗时约 39 分钟，
产物 `26.10.31_06.57.45_tenda_be12_pro_immwrt`。

随后用该 `squashfs-sysupgrade.bin` 在一台 BE12 Pro 上做保留配置升级：

| 检查项 | 结果 |
| --- | --- |
| 固件标识 | `26.10.31_06.57.45_tenda_be12_pro_immwrt` |
| 镜像 sha256 | 与 CI 产物一致 |
| 配置保留 | `/etc/config/wireless` 升级前后逐字节一致 |
| 无线状态 | 12 个 VAP 全部起来，apcli 正常 |
| DAT 同步 | `mt7992.b0/b1.dat` 的 `MacAddress*` 与 uci 一致 |
| MAC 报错 | 无 `does not match` / `AP_BSS_NOT_READY` |

温度读数（刷机后实测）：

```text
$ cat /proc/net/mt_wifi/temp0 /proc/net/mt_wifi/temp1
51000
45000

$ tempinfo
CPU: 67.5°C, WiFi: 51.0°C 45.0°C
```

再次读取时数值随负载变化（49.0°C / 46.0°C），说明是实时值。

## 已知限制

- 温度只有在对应 radio 启动后才可读；全部接口关闭时概览仍只显示 CPU
- `sysupgrade` 默认不保留 `/root`，设备上的 `/root/rmac.sh` 需要单独恢复，
  或加进 `/etc/sysupgrade.conf`
- 温度来自驱动内部热保护同一条 MCU 命令，读取会占用一次 HW control 队列；
  正常刷新频率下无影响

## 回滚方式

删除 `wrt_core/patches/mtwifi-temperature-proc.patch`，并移除
`wrt_core/update.sh` 中的 `fix_mtwifi_temperature` 调用即可完全回退。

## 涉及文件

- `wrt_core/patches/mtwifi-temperature-proc.patch`
- `wrt_core/patches/tempinfo`
- `wrt_core/modules/target_fixes.sh`
- `wrt_core/update.sh`
- `changelogs/2026-10-30_2055_mtwifi-temperature.md`
- `changelogs/2026-10-31_0146_mtwifi-hwmon-parent.md`
- `changelogs/2026-10-31_0608_mtwifi-temperature-proc.md`
- `changelogs/2026-10-31_0650_mtwifi-proc-pde-data.md`
- `changelogs/2026-10-31_0807_release-tenda-be12-pro.md`
