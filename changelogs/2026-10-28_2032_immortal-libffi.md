# 2026-10-28 20:32 — 修复 VIKINGYFY 缺失 libffi 导致 Python3 编译失败

## 现象

`immwrt_all` 运行 `40651314452`：

- `aliyun_ap8220_immwrt`：成功
- `xiaomi_ax3600_immwrt`：成功
- `jdcloud_ipq60xx_immwrt`：`Build Firmware` 失败

错误：

```text
./Modules/_ctypes/_ctypes.c:119:10: fatal error: ffi.h: No such file or directory
make[3]: *** [Makefile:364: .../Python-3.14.7/.built] Error 2
ERROR: package/feeds/packages/python3 failed to build.
```

日志中更早还有：

```text
Installing package 'python3' from packages
WARNING: No feed for source package 'libffi' found
WARNING: No feed for package 'libffi' found
```

## 根因

VIKINGYFY main 的源码树里没有 `package/libs/libffi`，而当前使用的
`immortalwrt/packages` feed 也没有提供 libffi 源包。

jdcloud 因为 app 包集合触发了 Python3 构建，Python3 的 `_ctypes`
需要使用系统 libffi；找不到 `libffi` 包后，编译时自然找不到 `ffi.h`。

AP8220 / AX3600 没有选中 Python3，所以没有触发。

## 修复

`wrt_core/modules/target_fixes.sh` 新增：

```bash
ensure_vikingyfy_libffi()
```

行为：

- 只对 VIKINGYFY `imm-nss` 构建生效
- 如果 `package/libs/libffi/Makefile` 已存在，直接跳过
- 否则从官方 `immortalwrt/immortalwrt` 的 `master` 分支稀疏检出：
  ```text
  package/libs/libffi
  ```
- 复制到 VIKINGYFY 源码树
- 校验 `Makefile` 存在，失败则终止构建

调用位置：`wrt_core/update.sh` 的 `stage_pre_install_source_fixes()`，在 feeds install 前完成。

不涉及 LibWrt，也不修改 VIKINGYFY 的 ath11k/NSS patch。

## 验证

- 本地模拟执行 `ensure_vikingyfy_libffi()`：
  - 成功从官方 immortalwrt 稀疏检出 libffi
  - 确认 `package/libs/libffi/Makefile` 存在
- `bash -n wrt_core/modules/target_fixes.sh` 通过
- 尚未重新跑完整 jdcloud 编译；下一步单独重跑 `jdcloud_ipq60xx_immwrt`

## 风险

- 依赖官方 `immortalwrt/immortalwrt` master 的 libffi 版本（当前 3.4.7）
- 首次构建需要额外一次稀疏 clone；后续源码树已有 libffi 会自动跳过
- 如果官方仓库结构调整，会明确报错并终止，不会静默产出损坏固件

## 涉及文件

- `wrt_core/modules/target_fixes.sh`
- `wrt_core/update.sh`
- `changelogs/2026-10-28_2032_immortal-libffi.md`
