# 2026-10-31 01:46 — mtwifi hwmon 改挂 wiphy，对齐 mt76 布局

## 背景

上一版 `mtwifi-hwmon-temperature.patch` 把 hwmon 注册在 PCI function 设备上，
温度节点出现在：

```text
/sys/class/ieee80211/phy0/device/hwmon/hwmonN/temp1_input
```

并靠 `tempinfo` 新增的回退分支读取。

调研公开实现后发现，mt76（MT7996）是把 hwmon 直接挂在 wiphy 上：

```text
/sys/class/ieee80211/phy0/hwmonN/temp1_input
# hwmon name: mt7996_phy0.0 / mt7996_phy0.1 / mt7996_phy0.2
```

第三方 LuCI 管理器（`woziwrt/mt7996-wifi7-manager`）也是按
`phy*/hwmon*/name` + `temp1_input` 扫描的。这正好也是 autocore `tempinfo`
原始 glob 的路径。

## 变更

`wrt_core/patches/mtwifi-hwmon-temperature.patch` 中
`mt_wifi_hwmon_register()` 改为两级：

1. 优先 `hwmon_device_register_with_info(&wiphy->dev, ...)`，节点落在
   `phyN/hwmonN`，和 mt76 一致，`tempinfo` 原始路径直接命中
2. 若 wiphy 设备此时还不能作为父设备（注册失败），回退到
   `wiphy_dev(wiphy)`，即 PCI function 设备（`phyN/device/hwmonN`）

`wrt_core/patches/tempinfo` 的回退分支保留，作为第 2 种布局的兜底。

## 影响范围

- 只影响使用 `mt_wifi7` 的 BE12 Pro 构建
- 其他平台不变；`tempinfo` 回退分支只在原路径为空时执行

## 已验证

- 补丁对上游原始源码包（`mt7993_20250613-415824`）`patch -p1 --dry-run` 通过，
  实际 patch 后函数内容正确
- 注释中避免出现 `*/` 组合，不会提前终止 C 注释
- `sh -n wrt_core/patches/tempinfo`、`bash -n` 相关脚本（同上一提交，未改动）

## 未验证

- 未编译、未刷机。需要 CI 构建确认：
  - `phy0/hwmonN` 是否按预期出现（每种布局各一个 band）
  - `tempinfo` 是否输出 `CPU: xx.x°C, WiFi: xx.x°C xx.x°C`

## 风险与回滚

- 若 `&wiphy->dev` 不能作为父设备，代码会自动回退到 PCI 设备，行为等同上一版
- 回滚：`git revert` 本提交即可，恢复到 PCI 设备布局（仍有 tempinfo 回退可用）

## 涉及文件

- `wrt_core/patches/mtwifi-hwmon-temperature.patch`
- `changelogs/2026-10-31_0146_mtwifi-hwmon-parent.md`
