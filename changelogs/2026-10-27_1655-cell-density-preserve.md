# 2026-10-27 16:55 — 保留升级前的无线覆盖密度等射频设置

## 变更

`wrt_core/patches/992_set-wifi-uci.sh` 的 `configure_wifi()` / `configure_wifi7()`：

- 仍然始终写入：
  - `country`（保证迁移/升级后地区不丢）
  - `disabled='0'`
- 改为“仅在未配置时写默认值”：
  - `channel`：为空或 `auto` 时才写默认信道；用户固定信道保留
  - `htmode`
  - `txpower`
  - `cell_density`（无线信号覆盖密度）
  - `mu_beamformer`
- `configure_wifi7` 同样保留 `channel` / `htmode` / `txpower` / `cell_density`。

## 原因

AP8220 更新后发现 2.4G / 5G 的“无线信号覆盖密度”都变成禁用状态，没有随其他配置一起保存升级。

原因是 `992_set-wifi-uci.sh` 在升级后首次启动时把射频级参数全部重写：

```sh
set wireless.radio${radio}.cell_density='0'
set wireless.radio${radio}.txpower=...
set wireless.radio${radio}.channel=...
```

这会覆盖 `/etc/config/wireless` 中已经保留的用户设置。现在只强制写 `country` 和 `disabled`，其余参数在已有值时不再覆盖。

## 影响范围

- 升级后用户设置的 `cell_density`、`txpower`、固定信道、`htmode`、`mu_beamformer` 会保留。
- 新装或参数为空时仍写入默认值。
- `channel='auto'` 仍会被设置为 149 / 1，继续避免 5G 自动落到 100 信道。
- `country` 仍强制为 `CN`（6G 为 `00`），不会回到 US。

## 验证

- `sh -n wrt_core/patches/992_set-wifi-uci.sh` 通过。
- 尚未重新编译；下一次 AP8220 / CS-02 / AX3600 构建生效。
- 现有 AP8220 release `26.10.27_05.29.55_aliyun_ap8220_libwrt` 仍是旧脚本。

## 风险与回滚

- 如果新装时 `mac80211.uc` 已经生成了 `htmode`，脚本会保留它而不是写设备默认的 `HE80`/`HE20`；两者通常一致，若某设备不一致需要按设备调整。
- 回滚：恢复始终写入射频参数的逻辑，但会重新出现覆盖用户设置的问题。

## 涉及文件

- `wrt_core/patches/992_set-wifi-uci.sh`
- `changelogs/2026-10-27_1655-cell-density-preserve.md`
