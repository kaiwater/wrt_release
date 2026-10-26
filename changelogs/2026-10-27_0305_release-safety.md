# 2026-10-27 03:05 — Release 前安全回调

## 变更

1. **撤销上游 `a4f65e8` 的 lucky 下载路径改动**
   - 恢复为原来的 `$(PKG_BUILD_DIR)/...` 目标路径。
2. **暂时保留 `fix_rust_compile_error`**
   - `update.sh` 不再注释该调用。
3. 更新 `changelogs/2026-10-27_0259_upstream.md`，把上述两项标记为暂不合并。

## 原因

### lucky

上游 `a4f65e8` 把本地归档安装到 `$(DL_DIR)/$(PKG_SOURCE)`，但它和 `21087a2`（把 lucky Wanji 二进制替换为 3.4.1）是配套提交。

本仓库仍保留 2.27.2 本地归档，没有合并 3.4.1 二进制。如果单独套用 `a4f65e8`，会把 2.27.2 的内容装进 3.4.1 的下载文件名，导致内容/哈希不匹配。因此先撤销该路径改动，等以后完整合并 3.4.1 时再一起应用。

### Rust workaround

上一轮 jdcloud 构建（带 `fix_rust_compile_error`）已经成功编译 `quickfile`，最终只失败在 ath11k 包名。为优先保证这次三个机型的 release 构建成功，暂时保留该 workaround；上游的“跳过 workaround”优化等 release 验证通过后再单独尝试。

## 影响范围

- `lucky` 构建恢复原有本地归档路径。
- Rust/quickfile 构建继续使用已知可用的 workaround。
- 不影响已合并的 Airoha NPU、geo2txt、OAF、netfilter、video feed 等上游修复。

## 验证

- `bash -n` 检查 `update.sh` 和 `wrt_core/modules/*.sh`。
- `config_preview` 检查 CS-02 / AP8220 / AX3600。
- 随后触发 `Release WRT` 的 `libwrt_all` 进行实际构建验证。

## 风险与回滚

- lucky 仍使用 2.27.2；如果上游源码更新到 3.4.1 后本地归档不再匹配，需要合并 `21087a2` 的 3.4.1 二进制并重新应用 `a4f65e8`。
- Rust workaround 会增加 Rust/LLVM 构建时间；release 成功后可以再做一次不带 workaround 的验证。

## 涉及文件

- `wrt_core/modules/feed_source_fixes.sh`
- `wrt_core/update.sh`
- `changelogs/2026-10-27_0259_upstream.md`
- `changelogs/2026-10-27_0305_release-safety.md`
