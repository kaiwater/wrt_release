# 2026-10-27 13:16 — 修复构建后 hashFiles 超时阻塞 release

## 变更

`.github/workflows/build_wrt.yml` 与 `.github/workflows/release_wrt.yml` 的 `Delete Old Cache` 步骤：

- 不再在构建结束后调用 `hashFiles('**/repo_flag')`
- 改为直接对 `repo_flag` 计算 SHA-256：
  ```bash
  REPO_FLAG_HASH=$(sha256sum repo_flag | cut -d' ' -f1)
  ```
- 增加 `continue-on-error: true`，缓存清理失败不再阻塞后续的固件上传/Release。

## 原因

jdcloud-only Release Run 40428823890 已经成功完成：

- `Build Firmware` ✅
- `Get Kernel Verion` ✅

但随后在 `Delete Old Cache` 失败：

```text
The template is not valid.
.github/workflows/release_wrt.yml (Line: 171, Col: 14):
hashFiles('**/repo_flag') couldn't finish within 120 seconds.
```

构建结束后 `action_build` 包含完整源码、build_dir、staging_dir 等大量文件，GitHub Actions 在计算 `hashFiles('**/repo_flag')` 时需要扫描整个 workspace，超过 120 秒限制。这个步骤原本只是清理旧缓存，不应该让已经成功的固件发布失败。

`hashFiles()` 对文件内容使用 SHA-256，`sha256sum repo_flag` 结果与它一致，因此缓存 key 前缀仍能正确匹配。

## 影响范围

- `Build WRT`：删除旧缓存失败不再阻塞 artifact 上传。
- `Release WRT`：删除旧缓存失败不再阻塞 kmods 打包和 GitHub Release。
- 缓存 key 的生成方式不变，只是 post-build 删除时不再用 `hashFiles`。

## 验证

- Python YAML 解析两个 workflow。
- 未重新跑完整构建；下一次 Release 验证。

## 风险与回滚

- 如果 `repo_flag` 不存在或内容变化，缓存前缀可能匹配不到旧缓存，只会导致旧缓存未被清理，不影响构建/Release。
- 回滚：恢复 `hashFiles` 写法，但需要接受大 workspace 下超时和 release 被阻塞的风险。

## 涉及文件

- `.github/workflows/build_wrt.yml`
- `.github/workflows/release_wrt.yml`
- `changelogs/2026-10-27_1316_cache-hash-timeout.md`
