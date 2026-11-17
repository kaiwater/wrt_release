# 2026-11-18 — mt_wifi 温度 procfs 接口与双 band 结论

## 背景

RAX3000M / WR30U 概览页的 WiFi 温度长期是两个相同值，例如
`WiFi: 48°C/48°C`。之前怀疑 mtwifi 在两个 band 上有独立温度寄存器，
本次把温度来源、版本差异和负载表现都测了一遍。

## 温度来源

`iwpriv <if> stat` 的温度来自固件，不是 hwmon，也不是 SoC thermal zone：

```text
iwpriv ra0 stat
  -> RTPRIV_IOCTL_STAT
  -> RTMPIoctlStatistics()
  -> HcGetBandByWdev()              // 取 VIF 的 band
  -> RTMP_GET_TEMPERATURE()
  -> HWCMD_ID_GET_TEMPERATURE
  -> MtCmdGetThermalSensorResult()
  -> EXT_CID 0x2c / EXT_CMD_ID_THERMAL_FEATURE_CTRL
  -> FW 返回 u4SensorResult
```

驱动只是把固件返回的整数摄氏度打印出来。

## 双 band 实测

### 固件版本对比

在 MT7981 上分别替换三版 WACPU 固件，驱动不变：

| 固件 | 同一时刻两路 |
|---|---|
| 20240823 | 相同 |
| 20250408 | 相同 |
| 20260601 | 相同 |

ADC 读数也总是相同（如 66/66、73/73、74/74）。

### 5G 打流

在 5G band 上跑持续测速：

```text
峰值下行约 548 Mbps
上行业务约 80-100 Mbps
```

打流期间 1 秒采样，共 188 个点：

```text
空闲：46-48°C
负载：50-52°C
max |temp0 - temp1| = 0.0
```

结论：

- 温度确实反映 Wi-Fi 芯片发热，负载下上升 4-6°C
- 两个 band 共用同一路热传感，不是两个独立寄存器
- 之前的 `48/46` 是同一个值在 46↔48 跳变时被两次读取跨过，
  不是稳定的 band 差异
- 硬件上 2.4G/5G 基带在 MT7981 内，射频是单颗 MT7976 双频 FEM

## 补丁

### 驱动 mt_wifi（7.6.7.3 / 7.6.7.2）

新增：

```text
/proc/net/mt_wifi/temp0
/proc/net/mt_wifi/temp1
```

- 毫摄氏度输出，和 hwmon `temp1_input` 同单位
- 读时按 band 调 `RTMP_GET_TEMPERATURE`，与 `iwpriv stat` 同一条
  MCU 查询，数值一致
- 文件数由 `DBDC_BAND_NUM` 决定，单 band 只有 `temp0`
- radio 未启动或固件无值时返回 `-ENODATA`
- 在 `rbus_prop_dev` / `rbus_main_dev` / `wbsys_main_dev` 三个
  main-dev 变体中注册，卸载时移除
- 只用 procfs：模块是 `Proprietary`，6.12 的 hwmon/thermal 注册
  符号是 GPL-only，modpost 会拒绝

### autocore tempinfo

`get_mtwifi_temp()` 优先读 `/proc/net/mt_wifi/temp*`：

- 全部文件读取成功才使用 proc 结果
- 没有 proc 或任一文件读取失败时，整体回退到原来的
  `iwpriv ... stat` 路径
- 显示格式保持 `46°C/46°C` 不变

## 落地

补丁已进入自有构建仓库 `kaiwater/immortalwrt-mt798x-25.12`
的 `25.12` 分支：

```text
283e709 mtk: mt_wifi: expose per-band chip temperature through procfs
bd2df2d autocore: prefer mt_wifi procfs temperature
```

上游 PR 已关闭，不再提交 chasey-dev，仅保留自有仓库。

## 灰度

四台 RAX/WR30U 仅替换 `mt_wifi.ko`（未刷整机）：

```text
RAX3000Me
RAX3000M-128
RAX3000M-256
WR30U
```

结果：

```text
temp0/temp1 均可读
tempinfo 与 iwpriv 输出一致
VIF 数量与升级前相同
dmesg 无模块加载错误
```

读取开销：

```text
cat /proc/net/mt_wifi/temp0  约 2.8 ms/次
iwpriv ra0 stat              约 2.3 ms/次
无后台轮询，只有读取时才发 MCU 查询
```

## 后续

- 下一轮完整构建会自动带上驱动补丁和 tempinfo 改动
- 已灰度的设备保留当前 ko，下次整机升级时由构建产物覆盖
