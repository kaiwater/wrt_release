# 2026-11-28 — ath11k regd 更新失败导致 2.4G ACS 起不来

## 现象

AX6600（192.168.2.150）升级到 6.12.118 后，2.4G（`radio1`，`channel=auto`）起不来：

```text
hostapd: ACS: Possibly channel configuration is invalid
hostapd: ACS: Failed to start
hostapd: phy1-ap0: AP-DISABLED
```

`phy1-ap0` 存在但没有 channel / ssid，5G 正常。

## 关键日志

```text
WARNING: CPU: 2 PID: 411 ... 6.12.118
pc : reg_get_max_bandwidth+0x360/0x380 [cfg80211]
Call trace:
  reg_get_max_bandwidth [cfg80211]
  regulatory_set_wiphy_regd [cfg80211]
  ath11k_regd_update [ath11k]
  ath11k_regd_update_work [ath11k]
ath11k_pci 0000:01:00.0: failed to perform regd update : -22
```

regd 更新返回 `-EINVAL`，之后 ACS 找不到合法信道组合，直接失败。

## 版本关系（回答“是否和 mainline 同步”）

不同步。LibWrt 用的 ath11k **不是** kernel 6.12 的 in-tree 驱动，而是 OpenWrt 的
mac80211 backports：

```text
package/kernel/mac80211
PKG_VERSION := 6.18.55        ← OpenWrt backports，相当于 6.18 的无线栈
PKG_RELEASE := 2
产物：cfg80211.ko / mac80211.ko / ath11k.ko（都是 OOT，dmesg 里带 (O)）
```

另外 LibWrt/OpenWrt 还叠了一批 ath11k 补丁，其中和本次相关的有：

```text
905-ath11k-remove-intersection-support-for-regulatory-ru.patch
903-ath11k-support-setting-FW-memory-mode-via-DT.patch
907/906 coldboot 相关
```

对比上一次构建（`000a4e74b17e`）：backports 仍是 `6.18.55`，没有变化；变化的是
内核 `6.12.116 → 6.12.118`。所以是**新内核与 backports 的 regd 路径不再兼容**，
不是 backports 升级导致。

## 临时规避

固定信道即可绕过 ACS：

```sh
uci set wireless.radio1.channel='1'   # 或 6 / 11
uci commit wireless
wifi reload
```

P2 用的是固定 `channel='10'`，所以同一个镜像上 2.4G 正常。

## TODO

1. 对比 6.12.117 / 6.12.118 中 `net/wireless`、`include/net/cfg80211.h`、
   `include/linux/ieee80211.h` 的 stable 改动，找出让 `reg_get_max_bandwidth`
   WARN 的那一条
2. 确认 WARN 是否由 BDF 里的 regd 规则触发（规则本身不合法），还是内核新增校验
3. 试 `backports 6.18.55` 去掉 `905-ath11k-remove-intersection-support-for-regulatory-ru.patch`
   后是否恢复
4. 试更新 backports（6.18.x 后续版本）是否已修复
5. 若确认是内核回归，向 LibWrt / OpenWrt 上游报告，附本次 dmesg 与 BDF 版本
6. 修复前：AX6600 的 2.4G 统一用固定信道，修好后再评估恢复 `auto`
