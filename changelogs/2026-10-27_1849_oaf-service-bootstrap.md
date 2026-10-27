# 2026-10-27 18:49 — 修复 OAF 服务不启动、`oaf` 模块不加载

## 现象

用户反馈：

- AP8220：`lsmod | grep oaf` 有输出（`oaf`、`nf_reject_ipv4` 等）
- jdcloud：`lsmod | grep oaf` 为空

用户怀疑 jdcloud 没有 OAF 的完整支持。

## 检查结果

**jdcloud 的构建和镜像里其实有完整的 OAF 组件**：

- jdcloud manifest 包含：
  - `appfilter - 7.0.1-r1`
  - `kmod-oaf - 6.12.108-r1`
  - `luci-app-oaf - 7.0-r1`
- 从 jdcloud sysupgrade 镜像解包确认：
  - `/lib/modules/6.12.108/oaf.ko` 存在，约 845 KB，ARM64 ELF 有效
  - `vermagic=6.12.108 SMP preempt mod_unload aarch64`，与系统内核一致
  - `depends=nf_reject_ipv4`，而 `nf_reject_ipv4.ko`、`nf_conntrack.ko` 也都在镜像中
  - `appfilter.init` 中也确实有 `modprobe oaf`

所以不是缺包、缺模块或内核版本不匹配。

## 根因

上游 `6b57de5 fix(oaf): disable appfilter by default` 在 `appfilter.init` 的 `start_service()` 里插入了：

```sh
if [ "$(uci -q get fwx.appfilter.enable)" != "1" ] &&
   [ "$(uci -q get fwx.macfilter.enable)" != "1" ] &&
   [ "$(uci -q get fwx.record.enable)" != "1" ]; then
    return 0
fi
```

而同一个提交把默认配置改成了三个开关全为 `0`。结果：

1. 新刷入的设备第一次启动时，`ensure_default_configs` 创建 `fwx` 配置，三个开关都是 0
2. `start_service` 在 `modprobe oaf` 之前直接 `return 0`
3. `oaf` 模块不会加载，`oafd` / `rule_manager` 也不会启动
4. `oafd` 正是 OAF LuCI 的 ubus 后端；服务不启动，用户无法在 LuCI「高级设置」里打开 appfilter，形成鸡生蛋问题

AP8220 之所以能看到 `oaf`，通常是因为它保留了升级前的 `/etc/config/fwx`，其中某个开关仍是 `1`，所以服务正常启动并加载了模块。jdcloud 如果是新刷入或配置被重置，三个开关都是 0，就会表现为 `lsmod` 为空。

## 修复

`wrt_core/modules/feed_source_fixes.sh` 的 `update_oaf_deconfig()`：

- 保留默认 `fwx.appfilter.enable=0`、`fwx.macfilter.enable=0`、`fwx.record.enable=0`，不主动开启过滤
- **移除**“三个开关都为 0 就提前 return”的注入逻辑
- 让 `appfilter` 服务正常启动：
  - 执行 `modprobe oaf`
  - 启动 `oafd` 和 `rule_manager`
  - 提供 ubus API 给 LuCI
- 用户可在 LuCI → 服务 → OAF → 高级设置中按需打开应用过滤 / MAC 过滤 / 记录

同时更新 `README.md` 的 OAF 使用说明，补充：

- 正常应能看到 `lsmod | grep oaf`
- LuCI 高级设置中的开关位置
- SSH 启用命令
- `appfilter` 状态、`dmesg`、`modprobe oaf` 的排查命令

## 验证

- `bash -n wrt_core/modules/feed_source_fixes.sh` 通过
- 解包 jdcloud 镜像确认 `oaf.ko` 存在且 vermagic 匹配
- 解包 AP8220 镜像对比，两者的 `appfilter.init` 结构一致
- 未重新触发编译

## 影响

- 新构建的 jdcloud / AP8220 / AX3600 镜像会在启动时加载 `oaf` 模块，并运行 OAF 服务
- 默认仍然不启用任何过滤规则，不会主动改变现有防火墙行为
- 如果 OAF 与 NSS 硬件加速冲突，可在 LuCI 高级设置中勾选「禁用 HNAT」

## 已有固件的临时处理

在 jdcloud 上可直接执行：

```sh
uci set fwx.appfilter.enable='1'
uci commit fwx
/etc/init.d/appfilter restart
lsmod | grep oaf
```

如果只想验证模块本身：

```sh
modprobe oaf; echo "exit=$?"
dmesg | tail -30
```

## 涉及文件

- `wrt_core/modules/feed_source_fixes.sh`
- `README.md`
- `changelogs/2026-10-27_1849_oaf-service-bootstrap.md`
