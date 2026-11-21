# 2026-11-21 — 移除 luci-app-quickfile，保留 filemanager

## 背景

CS-02（LibWrt）本次构建在 rust host 失败：

```text
ERROR: package/feeds/packages/rust [host] failed to build.
```

触发源是 `luci-app-quickfile`：

```text
package/emortal/quickfile/quickfile/Makefile
  PKG_BUILD_DEPENDS:=rust/host
```

`quickfile` 是 Rust（Axum）+ Vue 3 的独立 Web 文件管理器，需要 host 编译
Rust 工具链。当前 `fix_rust_compile_error` 把 `download-ci-llvm` 强制设为
`false`，host rust 编译失败。

## 和 filemanager 的关系

- `luci-app-filemanager`：LuCI 内置文件管理，浏览 / 上传 / 下载 / 编辑 /
  权限，轻量，已经在 `compile_base.config` 全局启用
- `luci-app-quickfile`：独立 Web 文件管理器，带终端和多媒体预览

两者不是 100% 功能相同（quickfile 多了终端和媒体预览），但**核心文件管理
功能重叠**；quickfile 还额外引入 rust/host 构建负担。

## 变更

1. `compile_base.config` 显式关闭：

```text
# CONFIG_PACKAGE_luci-app-quickfile is not set
# CONFIG_PACKAGE_quickfile is not set
```

2. 从以下配置移除 `CONFIG_PACKAGE_luci-app-quickfile=y`：

```text
jdcloud_ipq60xx_libwrt
jdcloud_ipq60xx_immwrt
n1_immwrt
x64_immwrt
link_nn6000v2_immwrt
```

3. `wrt_core/update.sh` 移除 `add_quickfile` 调用，不再克隆
   `sbwml/luci-app-quickfile`，也不再把 quickfile 塞进源码树。

4. `luci-app-filemanager` 保留，作为默认文件管理入口。

## 影响

- CS-02（LibWrt）以及其他使用 `compile_base` 的 profile 不再安装
  quickfile，也不再为它编译 rust/host
- 需要 quickfile 时，可以单独 apk 安装（如果仓库提供），或临时恢复
  `add_quickfile`
- `package_source_updates.sh` 里的 `add_quickfile` 函数保留但未调用，
  方便以后恢复

## 验证

CS-02 已重新启动构建，确认 rust 不再进入包列表。
