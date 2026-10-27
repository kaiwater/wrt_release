# 2026-10-27 18:02 — 修复 cache 保存阶段 hashFiles 超时

## 变更

`.github/workflows/build_wrt.yml` 与 `.github/workflows/release_wrt.yml` 中所有：

```yaml
hashFiles('**/repo_flag')
```

改为：

```yaml
hashFiles('repo_flag')
```

涉及 cache key 和两条 restore-keys。

## 原因

jdcloud Release Run 40454406477 实际上已经成功：

- `Build Firmware` ✅
- `Package Kmods` ✅
- `Release Firmware` ✅
- 已创建 release：`26.10.27_13.25.57_jdcloud_ipq60xx_libwrt`

但最后的 `Post Cache Dependencies` 失败：

```text
hashFiles('**/repo_flag') couldn't finish within 120 seconds.
```

`actions/cache` 的 post-step 会再次计算 key 来保存缓存。`**/repo_flag` 会递归扫描整个 workspace，而构建结束后 `action_build` 很大，超过 120 秒。结果：

- job 被标记为 failure（实际上 release 已发布）
- 新缓存没有保存，jdcloud 下一次仍然是冷编译

`hashFiles('repo_flag')` 只哈希根目录这一个文件，结果与 `**/repo_flag` 相同（SHA-256），但在 post-step 很快，不再超时。

## 影响范围

- 缓存 key 的前缀不变，已有 AP8220 / AX3600 缓存仍可命中。
- 后续构建可以正常保存缓存，jdcloud 成功一次后也能开始复用缓存。
- 不再因为缓存 post-step 超时把已发布成功的 job 标成失败。

## 验证

- Python YAML 解析两个 workflow。
- 未重新触发构建；下一次构建验证缓存保存。

## 风险与回滚

- 如果 `repo_flag` 不在仓库根目录，`hashFiles('repo_flag')` 会返回空，缓存 key 变化；当前 `pre_clone_action.sh` 明确写入仓库根目录，路径正确。
- 回滚：恢复 `**/repo_flag`，但会重新出现 post-step 超时和缓存无法保存的问题。

## 涉及文件

- `.github/workflows/build_wrt.yml`
- `.github/workflows/release_wrt.yml`
- `changelogs/2026-10-27_1802-cache-key-repo-flag.md`
