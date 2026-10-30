# 2026-10-31 06:50 — 修正 procfs 温度接口的 6.12 API（PDE_DATA → pde_data）

## 背景

CI run `41136188042`（commit `ffbae67`）在 `kmod-mt_wifi7` 编译时报：

```text
cfg80211drv.c:4655:40: error: implicit declaration of function 'PDE_DATA';
did you mean 'NODE_DATA'? [-Wimplicit-function-declaration]
cfg80211drv.c:4655:40: error: initialization of 'struct _RTMP_ADAPTER *' from 'int'
makes pointer from integer without a cast [-Wint-conversion]
```

`PDE_DATA()` 在 Linux 6.10 被重命名为 `pde_data()`，6.12.112 已经没有
`PDE_DATA`。GPL 符号问题已经解决（本次失败发生在编译阶段，不是 modpost）。

## 变更

`wrt_core/patches/mtwifi-temperature-proc.patch`：

- 读取文件私有数据改为 `pde_data(file_inode(file))`
- 加 3 行兼容：`#ifdef PDE_DATA` 时把 `pde_data` 映射回 `PDE_DATA()`，
  以兼容 6.10 之前的内核
- `#if IS_REACHABLE(CONFIG_PROC_FS)` 改为 `#ifdef CONFIG_PROC_FS`：驱动里
  从未使用过 `IS_REACHABLE`/`IS_ENABLED`，避免依赖该宏是否在包含链里

## 影响范围

仅 `mt_wifi7`（BE12 Pro）构建。

## 已验证

- 6.12 的 `include/linux/proc_fs.h` 中是
  `static inline void *pde_data(const struct inode *inode) { return inode->i_private; }`，
  是内联函数，不引入导出符号，非 GPL 限制
- `<linux/proc_fs.h>` 已由 `include/os/rt_linux.h` 引入，无需额外 include
- 补丁对上游原始源码包 `patch -p1 --dry-run` 通过
- 函数内所有变量均在块首声明，符合驱动的 C89 风格

## 未验证

- 仍需 CI 重新编译确认；这是同一处代码的第二次编译修正
- 刷机后确认 `/proc/net/mt_wifi/temp0`、`temp1` 与 `tempinfo` 输出

## 风险与回滚

- 回滚：`git revert` 提交即可，回到无法编译的版本没有意义，实际回滚方式是
  删除补丁并移除 `fix_mtwifi_temperature` 调用

## 涉及文件

- `wrt_core/patches/mtwifi-temperature-proc.patch`
- `changelogs/2026-10-31_0650_mtwifi-proc-pde-data.md`
