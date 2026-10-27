# 2026-10-27 08:49 — 修复 tailscale 与 luci-app-tailscale 文件冲突

## 变更

`wrt_core/modules/service_fixes.sh` 新增 `fix_tailscale_overlap()`，并在 `update.sh` 的 `stage_post_install_package_fixes()` 中调用。

它修改 `package/feeds/packages/tailscale/Makefile` 的两行安装命令：

```make
$(INSTALL_BIN) ./files//tailscale.init ...
$(INSTALL_DATA) ./files//tailscale.conf ...
```

改为：

```make
[ -n "$(CONFIG_PACKAGE_luci-app-tailscale)" ] || $(INSTALL_BIN) ...
[ -n "$(CONFIG_PACKAGE_luci-app-tailscale)" ] || $(INSTALL_DATA) ...
```

即：**启用 `luci-app-tailscale` 时，tailscale 后端不再安装自己的 `/etc/init.d/tailscale` 和 `/etc/config/tailscale`，改由 LuCI 应用提供。**

## 原因

Release Run 40383583490 的 jdcloud 在 `package/install` 阶段失败：

```text
ERROR: luci-app-tailscale-1.2.6-r1: trying to overwrite etc/config/tailscale owned by tailscale-1.104.1-r1.
ERROR: luci-app-tailscale-1.2.6-r1: trying to overwrite etc/init.d/tailscale owned by tailscale-1.104.1-r1.
```

small-package 的 `luci-app-tailscale` 自带更完整的 config/init（支持 accept_routes、exit_node、subnet_routes、access 等选项），而 `immortalwrt/packages` 的 `tailscale` 后端也安装同名 config/init。opkg 时代有 force-overwrite，apk 不允许覆盖。

## 影响范围

- 只有同时选择 `tailscale` 和 `luci-app-tailscale` 的构建受影响。
- 启用 LuCI 应用时使用应用的 config/init；未启用时 tailscale 后端仍安装自己的默认 config/init。
- 不影响 AP8220 / AX3600（它们没有选择 tailscale）。

## 验证

- `bash -n wrt_core/modules/service_fixes.sh` / `update.sh` 通过。
- 用临时 Makefile 验证 sed 保留原有 tab 缩进，并生成合法命令。
- 待 jdcloud 单独 Release 构建验证 `package/install` 阶段。

## 风险与回滚

- 如果 LuCI 应用的 config/init 与当前 tailscale 版本不兼容，可能出现服务启动问题；可回滚该函数，改为移除 `luci-app-tailscale` 或改用后端默认 config/init。
- 该修复只影响文件安装，不改变 tailscale 二进制。

## 涉及文件

- `wrt_core/modules/service_fixes.sh`
- `wrt_core/update.sh`
- `changelogs/2026-10-27_0849_tailscale-overlap.md`
