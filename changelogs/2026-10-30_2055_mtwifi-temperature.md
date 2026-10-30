# 2026-10-30 20:55 — BE12 Pro 恢复 WiFi 芯片温度（mt_wifi7 hwmon）

## 背景

在 Tenda BE12 Pro（mtwifi / MT7987A + MT7992）上，LuCI「状态 → 概览」的温度
只剩 CPU 一项，原来 mt76 固件里的两个 WiFi 温度不见了。

排查结论：与 MAC 随机化无关，是驱动差异。LuCI 概览的温度来自
`/sbin/tempinfo`，其中 WiFi 部分读的是：

```sh
/sys/class/ieee80211/phy*/hwmon*/temp1_input
```

这是 mt76 驱动注册的 hwmon。当前固件用的是 `mt_wifi7` 厂商驱动，源码包里
（`mt7993_20250613-415824.tar.xz`）确认：

| 能力 | 位置 | 用户态可达 |
| --- | --- | --- |
| `RTMP_GET_TEMPERATURE()` → `HWCMD_ID_GET_TEMPERATURE` | `hw_ctrl/hw_ctrl_cmd.c` | 否（内部函数） |
| `OID_GET_CPU_TEMPERATURE` (0x09A1) | `ap/ap_cfg.c` | 否（需要 `iwpriv`，固件未装） |
| cfg80211 vendor cmd `GET_RADIO_CPU_TEMPRETURE` | `os/linux/cfg80211/cfg80211_vndr_cmm.c` | 否（`iw` 无 vendor 命令） |
| RvR 仪表盘 `Current Temperature` | `common/cmm_rvr_dbg.c` | 否（`mwctl` 无对应命令） |
| hwmon / thermal zone | — | 完全没有 |

`mt_wifi.ko` 中 `hwmon` / `thermal_zone` 符号引用数为 0，内核 DT 的
`thermal-zones` 也只有 `cpu-thermal`、`eth2p5g-thermal`，所以这套固件里
WiFi 温度本来就没有出口。

## 变更

### 1. 新增驱动补丁

`wrt_core/patches/mtwifi-hwmon-temperature.patch`（构建时装入
`package/mtk/drivers/mt_wifi7/patches/900-add-hwmon-temperature.patch`）：

- `mt_wifi/include/rtmp.h`：`RTMP_ADAPTER` 增加 `void *hwmon_dev`
- `mt_wifi/os/linux/cfg80211/cfg80211drv.c`：
  - 在 hwifi 下发 `MT_80211_DRIVER_REGISTER` 时，用
    `hwmon_device_register_with_info()` 注册一个 hwmon，父设备取
    `wiphy_dev(wiphy)`（hwifi 设置的 PCI function device）。没有用
    `OS_Cookie->mac_dev`，因为该字段在 `HWIFI_SUPPORT` 未定义时不存在，
    会让补丁在别的配置下编译失败
  - `temp1_input` 读回调调用 `RTMP_GET_TEMPERATURE()`，返回毫摄氏度
  - 只有 `fRTMP_ADAPTER_START_UP`（radio 已启动）才去问 MCU，否则返回
    `-ENODATA`，避免接口全关时 sysfs 读取阻塞在 3 秒超时上
  - `MT_80211_DRIVER_UNREGISTER` 时注销
  - 整体由 `IS_REACHABLE(CONFIG_HWMON)` 保护

每个 band（adapter）注册一个 hwmon，所以两个 radio 各有一个
`temp1_input`，路径为：

```text
/sys/bus/pci/devices/<pci-addr>/hwmon/hwmonN/temp1_input
/sys/class/ieee80211/phy0/device/hwmon/hwmonN/temp1_input
```

### 2. tempinfo 回退路径

`wrt_core/patches/tempinfo`：原有 `phy*/hwmon*/temp1_input` 读不到时，再尝试
`phy0/device/hwmon/hwmon*/temp1_input`（厂商驱动把 hwmon 挂在 PCI 设备上）。
mt76/ipq 平台行为不变；只有原路径为空才走回退，不会重复计数。

### 3. 构建注入

- `wrt_core/modules/target_fixes.sh`：新增 `fix_mtwifi_temperature()`，检测到
  `package/mtk/drivers/mt_wifi7` 才安装补丁，其他源码树直接跳过
- `wrt_core/update.sh`：在 `stage_pre_install_source_fixes()` 中调用

## 影响范围

- 仅影响使用 `chasey-dev/immortalwrt-mt798x-rebase`（`mt_wifi7`）的
  BE12 Pro 构建
- `tempinfo` 改动对所有平台生效，但只是在原路径为空时多试一次，属于纯回退
- 与现有 MAC 随机化配置（UCI / DAT）无交集

## 已验证

- 补丁对上游原始源码包（`mt7993_20250613-415824`）`patch -p1 --dry-run` 通过，
  实际 patch 后文件内容正确
- 补丁只改 2 个文件，未触碰驱动其他逻辑
- `sh -n wrt_core/patches/tempinfo`
- `bash -n wrt_core/modules/target_fixes.sh`
- `bash -n wrt_core/update.sh`
- 回退路径只在 `wifi_temp` 为空时执行，已验证脚本语法与变量作用域
- 用模拟 sysfs 目录验证 `tempinfo` 三种情况：只有 mt76 路径（单值）、
  只有厂商 `phy0/device/hwmon` 路径（两个值）、都没有（不输出 WiFi）

## 未验证

- **未编译**：本地没有 SDK / 容器环境，驱动补丁能否一次编译通过需要 CI 验证
- **未刷机验证**：hwmon 节点是否按预期出现在
  `phy0/device/hwmon/`、温度值是否正常、`tempinfo` 是否输出
  `CPU: xx.x°C, WiFi: xx.x°C xx.x°C`，都需要刷入后确认

刷入后自检：

```sh
ls /sys/class/ieee80211/phy0/device/hwmon/
cat /sys/class/ieee80211/phy0/device/hwmon/hwmon*/temp1_input
tempinfo
```

## 风险与回滚

- 编译失败：删除
  `wrt_core/patches/mtwifi-hwmon-temperature.patch`，并移除 `update.sh` 中
  `fix_mtwifi_temperature` 调用即可完全回滚
- 运行期：hwmon 读取会在进程上下文阻塞等待 MCU 回复；radio 关闭时已用
  `-ENODATA` 挡住。最坏情况单次读取等待一个 MCU 超时
- 若 hwmon 父设备路径与预期不同，`tempinfo` 仍会回退，最多是继续只显示 CPU
  温度，不会引入错误数据
- hwmon 在 radio 重启时不会重复注册（`hwmon_dev` 指针判重），模块卸载依赖
  `MT_80211_DRIVER_UNREGISTER`；正常使用不会卸载该模块

## 涉及文件

- `wrt_core/patches/mtwifi-hwmon-temperature.patch`（新增）
- `wrt_core/patches/tempinfo`
- `wrt_core/modules/target_fixes.sh`
- `wrt_core/update.sh`
