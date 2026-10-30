# 2026-10-31 06:08 — WiFi 温度改用 procfs（hwmon 是 GPL-only）

## 背景

CI run `41101482784`（`Build - tenda_be12_pro_immwrt`，commit `e9d4e82`）在
`kmod-mt_wifi7` 编译的 modpost 阶段失败：

```text
ERROR: modpost: GPL-incompatible module mt_wifi.ko uses GPL-only symbol 'hwmon_device_unregister'
ERROR: modpost: GPL-incompatible module mt_wifi.ko uses GPL-only symbol 'hwmon_device_register_with_info'
ERROR: package/mtk/drivers/mt_wifi7 failed to build.
```

原因：`mt_wifi` 是闭源模块，`os/linux/rt_main_dev.c` 里是
`MODULE_LICENSE("Proprietary")`，而 `hwmon_device_register_with_info()` /
`hwmon_device_unregister()` 在 6.12 是 `EXPORT_SYMBOL_GPL`，非 GPL 模块
不能用。前一版把 hwmon 挂在 wiphy / PCI 设备上的方案整体不可行。

## 变更

驱动补丁改为 **procfs** 出口（`wrt_core/patches/mtwifi-temperature-proc.patch`，
原 `mtwifi-hwmon-temperature.patch` 重命名）：

- 在 `mt_wifi_hwmon_register()` / `mt_wifi_hwmon_unregister()` 的位置改为
  `mt_wifi_temp_register()` / `mt_wifi_temp_unregister()`
- 首次注册时 `proc_mkdir("mt_wifi", init_net.proc_net)` 建
  `/proc/net/mt_wifi/`，每个 band 建一个只读文件 `tempN`
  （`proc_create_data`，data 指向该 band 的 `RTMP_ADAPTER`）
- 读取时按需调用 `RTMP_GET_TEMPERATURE()`，输出**毫摄氏度**（和 hwmon
  `temp1_input` 同单位，方便 `/1000`）
- radio 未启动（`fRTMP_ADAPTER_START_UP` 未置位）或读到 0 时返回
  `-ENODATA`，避免接口关闭时 `cat` 卡在 MCU 超时
- `MT_80211_DRIVER_UNREGISTER` 时 `proc_remove()`
- `rtmp.h` 的 `hwmon_dev` 字段改为 `temp_proc`

`wrt_core/patches/tempinfo`：hwmon 回退分支换成读
`/proc/net/mt_wifi/temp*`。

`wrt_core/modules/target_fixes.sh`：补丁名与提示同步更新为
`900-add-temperature-proc.patch`。

## 为什么 procfs 可以

`fs/proc/generic.c` 中下列导出均为 **非 GPL**（已核对 6.12 源码）：

```text
EXPORT_SYMBOL(proc_mkdir);
EXPORT_SYMBOL(proc_create_data);
EXPORT_SYMBOL(proc_remove);
```

驱动里本来就有 `proc_mkdir` / `proc_create_data` 的用法，因此链接没有问题。

## 影响范围

- 仅影响 `mt_wifi7`（BE12 Pro）构建；其他平台不变
- 温度只在 radio 启动后可见；接口全关时 `tempinfo` 仍只显示 CPU

## 已验证

- 对上游原始源码包 `patch -p1 --dry-run` 通过，实际应用后函数内容正确
- procfs 三个导出的 GPL 属性已从内核源码确认
- `sh -n wrt_core/patches/tempinfo`、`bash -n wrt_core/modules/target_fixes.sh`
- 模拟 `/proc/net/mt_wifi/temp0=45000`、`temp1=47000`，`tempinfo` 输出
  `WiFi: 45.0°C 47.0°C`

## 未验证

- 需要重新跑 CI 确认 `kmod-mt_wifi7` 编译通过（这次的重点）
- 刷机后确认 `/proc/net/mt_wifi/temp0`、`temp1` 存在且数值合理

## 风险与回滚

- 若模块卸载前未收到 `MT_80211_DRIVER_UNREGISTER`，proc 节点会残留；
  正常使用不会卸载该模块
- 回滚：删除补丁并移除 `update.sh` 中的 `fix_mtwifi_temperature` 调用

## 涉及文件

- `wrt_core/patches/mtwifi-temperature-proc.patch`（由 hwmon 版重命名）
- `wrt_core/patches/tempinfo`
- `wrt_core/modules/target_fixes.sh`
- `changelogs/2026-10-31_0608_mtwifi-temperature-proc.md`
