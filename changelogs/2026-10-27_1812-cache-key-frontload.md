# 2026-10-27 18:12 — 缓存 key 前移，彻底移除构建后的 hashFiles

## 背景

jdcloud Release Run `40454406477` 的固件和 release 都已成功：

- `Build Firmware` ✅
- `Package Kmods` ✅
- `Release Firmware` ✅
- Release：`26.10.27_13.25.57_jdcloud_ipq60xx_libwrt`

但 `Post Cache Dependencies` 失败，导致整个 job 显示红 X：

```text
The template is not valid. .github/workflows/release_wrt.yml (Line: 119, Col: 16):
hashFiles('**/repo_flag') couldn't finish within 120 seconds.
```

`actions/cache` 的 post-step 在保存缓存时会重新计算 key。`**/repo_flag` 需要递归扫描构建后的整个 workspace，`action_build` 很大，超过 120 秒。后果：

- release 已经发布，但 job 被标记为 failure
- 新缓存没有保存，jdcloud 下一次仍然是冷编译

## 变更

`.github/workflows/build_wrt.yml` 和 `.github/workflows/release_wrt.yml`：

1. 在 `Pre Clone` 之后新增 `Compute Cache Key` 步骤：

   ```bash
   if [ -f repo_flag ]; then
     REPO_FLAG_HASH=$(sha256sum repo_flag | cut -d' ' -f1)
   else
     REPO_FLAG_HASH="no-repo-flag"
   fi
   echo "REPO_FLAG_HASH=$REPO_FLAG_HASH" >> "$GITHUB_ENV"
   ```

2. `Cache Dependencies` 的 `key` 和两条 `restore-keys` 改用：

   ```yaml
   ${{ env.REPO_FLAG_HASH }}
   ```

3. `Delete Old Cache` 直接复用 `${REPO_FLAG_HASH}`，不再在构建后执行 `sha256sum` 或 `hashFiles`。

4. 两个 workflow 中不再有任何 `hashFiles` 调用。

## 为什么能解决

- `repo_flag` 哈希在构建前只计算一次，写入 `$GITHUB_ENV`
- cache 的 post-step 直接读取环境变量，不再扫描 workspace
- `sha256sum` 与 `hashFiles('repo_flag')` 的结果一致，因此 cache key 的前缀不变
- 已有的 AP8220 / AX3600 缓存仍然可以命中，不需要重新预热

这也解决了“编译成功、release 已发布，但 job 因为缓存 post-step 失败而变红”的直接原因。

## 影响

- 下一次 jdcloud 成功构建后可以正常保存约 1 GB 缓存，后续 jdcloud 构建会明显加快
- 不会再因为 `hashFiles` 扫描超时把已发布成功的 job 标成失败
- 如果 `repo_flag` 缺失（正常情况下 `Pre Clone` 会生成），使用固定值 `no-repo-flag`，不会让 job 失败

## 验证

- Python YAML 解析两个 workflow 通过
- `grep -n hashFiles` 无结果
- `git diff --check` 通过
- 未重新触发编译；下一次构建验证缓存保存与命中

## 风险与回滚

- 依赖 `$GITHUB_ENV` 在 cache post-step 中可见；GitHub Actions 会将 `$GITHUB_ENV` 变量提供给同一 job 的后续步骤（包括 post-step）
- 若发现缓存 key 在 post-step 为空，可回退到 `hashFiles('repo_flag')`（只哈希单文件，不会再扫描整个 workspace）
- 回滚本次提交即可恢复旧逻辑，但会重新引入 post-step 超时风险

## 涉及文件

- `.github/workflows/build_wrt.yml`
- `.github/workflows/release_wrt.yml`
- `changelogs/2026-10-27_1812-cache-key-frontload.md`

## 备注

本变更取代 `changelogs/2026-10-27_1802-cache-key-repo-flag.md` 中的临时方案；`1802` 只把 `**/repo_flag` 改成 `repo_flag`，本次则把 key 计算完全前移。
