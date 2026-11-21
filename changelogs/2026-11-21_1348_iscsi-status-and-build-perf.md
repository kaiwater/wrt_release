# 2026-11-21 — iSCSI 多路径现状与 LibWrt 重编耗时

## 结论

当前 iSCSI 是 **4 会话、2 条链路、主备模式**，不是负载均衡：

```text
multipath -ll
  policy='service-time 0'
  4 个 path group，只有 sda 为 active
  sdb / sdc / sdd 为 enabled（备用）

multipathd show config
  path_grouping_policy "failover"
```

`/etc/multipath.conf` 里只有 `user_friendly_names yes`，其余用默认值，默认就是
`failover`。所以同一时刻只有一条路径承载 I/O，另一条链路只做故障切换。

结论：**双链路对吞吐没有实际提升**；构建变快主要是 ccache 命中和包集变化。
按决定保留现有配置（不切 `multibus`），仅记录现状。

## 构建耗时

同一 profile 的上一次构建与 2026-11-21 构建对比：

| Profile | 上次构建 | 耗时 | 2026-11-21 | 耗时 |
|---|---|---|---|---|
| CS-02（ipq60xx） | 11-16 06:24 → 12:22 | 38 min | 13:01 → 13:16 | 14 min |
| AP8220（ipq807x） | 11-17 05:06 → 05:46 | 40 min | 13:16 → 13:31 | 14 min |
| AX3600（ipq807x） | 11-17 05:46 → 06:00 | 14 min | 13:31 → 13:40 | 9 min |

这些数字不能直接归因于 iSCSI：

- 11-16 / 11-17 是上游更新后的首次重编，重编包明显更多
- 11-21 构建时 ccache 命中 77,026 / 78,122（98.6%），缓存占用 7.4 / 20 GB
- 11-21 还移除了 `luci-app-quickfile`，包集更小
- 11-21 11:14 那次 66 分钟是人为终止（`Terminated`），不计入

## 多路径快照

```text
设备        QNAP iSCSI Storage，544G，dm-0
路径策略    service-time 0
路径数      4（两个目标门户 × 2 会话）
活动路径    1（sda）
备用路径    3（sdb / sdc / sdd）
I/O 调度    mq-deadline，nr_requests 256
```

两个 VM 侧接口分别绑定一组会话，源策略路由按接口拆分；但 multipath 的
`failover` 策略让 I/O 只落在其中一个 path group 上，所以拆分只影响故障切换，
不影响带宽。

## 之前测到的吞吐

2026-11-21 上午在单路径生效的情况下测得：

```text
单路顺序写   ~134 MB/s
单路顺序读   ~150 MB/s
四流并发     ~146 MB/s
```

当时这些数字只在会话里，没有落盘，本次补记。四流与单流接近，说明瓶颈在
QNAP 磁盘或单条链路，而不在 iSCSI 会话数量。

## 以后要验证时的做法（本次未执行）

1. `/etc/multipath.conf` 的 `defaults` 增加：

```text
path_grouping_policy multibus
path_selector "service-time 0"
```

2. `multipathd reconfigure`，不中断现有 I/O
3. `fio` 做 1M 顺序读/写、4 并发、`direct=1` 对比
4. 同一 profile 连续重编两次（各路径策略一次），比总耗时
5. 结果不满意就改回 `failover` 并 `multipathd reconfigure`

注意：`/mnt/qnap` 上的构建目录就在这个 LUN 上，测试要在构建空闲时做。
