# 2026-10-27 03:35 — EasyTier 切换到 ZeroTier

## 变更

- 从 `compile_base.config` 移除：
  - `CONFIG_PACKAGE_easytier`
  - `CONFIG_PACKAGE_luci-app-easytier`
  - `CONFIG_EASYTIER_INCLUDE_WEBCONSOLE`
- 明确加入：
  - `CONFIG_PACKAGE_zerotier=y`
  - `luci-app-zerotier` / `luci-i18n-zerotier-zh-cn` 已在通用 LuCI 包中
- `custom_feed.sh` 移除 EasyTier 同步：
  - `base_custom_feed_packages` 去掉 `easytier luci-app-easytier`
  - `required_feed_dirs` 去掉 `luci-app-easytier`
- `verify.sh` 移除安装后必须存在的 `luci-app-easytier` 检查。
- `update.sh` 不再调用 `fix_easytier_mk` / `fix_easytier_lua`（函数保留，便于以后按设备重新启用）。
- `add_backup_info_to_sysupgrade` 的保留路径从 `/etc/easytier` 改为 `/etc/zerotier`。

## 原因

用户反馈 EasyTier 实际使用体验不佳，改用 ZeroTier。ZeroTier 依赖已在 base 中的 `kmod-tun`，LuCI 应用和中文翻译也已存在，因此只需移除 EasyTier 并明确选择 `zerotier` 包。

## 影响范围

- 所有设备默认不再包含 EasyTier。
- 所有设备默认包含 ZeroTier（`zerotier` + `luci-app-zerotier`）。
- `/etc/config/zerotier` 默认属于 conffile，会随 sysupgrade 保留；`/etc/zerotier` 也加入 sysupgrade 保留路径，便于使用持久化配置目录。

## 验证

- `bash -n` 检查 `update.sh` 和 `wrt_core/modules/*.sh`。
- `config_preview` 检查 CS-02 / AP8220 / AX3600，确认不再出现 easytier、包含 zerotier。
- 未触发编译。

## 风险与回滚

- ZeroTier 的 secret 在首次启动时写入 `/etc/config/zerotier`（conffile），sysupgrade 后 identity 可恢复。
- 如果后续需要 EasyTier，可在对应设备配置中单独加回，并恢复 custom_feed 同步与 `fix_easytier_*` 调用。
- 当前正在运行的 Release `40383583490` 使用的是切换前提交，仍包含 EasyTier；下一次 release 才会使用 ZeroTier。

## 涉及文件

- `wrt_core/deconfig/compile_base.config`
- `wrt_core/modules/custom_feed.sh`
- `wrt_core/modules/verify.sh`
- `wrt_core/modules/target_fixes.sh`
- `wrt_core/update.sh`
- `changelogs/2026-10-27_0335_easytier-to-zerotier.md`
