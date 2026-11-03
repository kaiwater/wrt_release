# 2026-11-04 01:10 — CI: dl 缓存改为 restore/save，失败也保存

## 背景

`2026-11-03_2214_ci-dl-cache.md` 加了一个 `dl` 缓存，但用的是稳定 key：

```yaml
key: ${os}-${model}-dl-${REPO_FLAG_HASH}
```

实际有两个问题：

1. **缓存永远不更新**。GitHub Actions 的 cache 是不可变的：key 已存在时，
   post-step 直接跳过保存。sing-box 这类活跃包出了 beta，新 tarball 每次构建
   都会重新下载，却永远写不进缓存。
2. **失败构建不保存**。`actions/cache` 只在 job 成功时保存。第一次冷构建跑
   3 小时但编译失败，`dl` 不会被保存，修复后的第二次仍然是冷下载，达不到
   “第二次 45 分钟”的预期。

## 变更

两个 workflow 都改成 restore / save 拆开：

- `.github/workflows/build_wrt.yml`
- `.github/workflows/release_wrt.yml`

### 1. 构建前 restore

```yaml
- name: Restore Downloads
  uses: actions/cache/restore@v6.1.0
  with:
    path: ./action_build/dl
    key: ${os}-${model}-dl-${REPO_FLAG_HASH}-${BUILD_DATE}
    restore-keys: |
      ${os}-${model}-dl-${REPO_FLAG_HASH}-
      ${os}-${model}-dl-
```

- key 带 `BUILD_DATE`：每次构建都是新 key，保存不会被“已存在”挡住。
- restore 先按含 `REPO_FLAG_HASH` 的前缀找最近一份，再退到所有 `dl` 快照。

### 2. 构建后 always 保存

```yaml
- name: Save Downloads
  if: always()
  continue-on-error: true
  uses: actions/cache/save@v6.1.0
  with:
    path: ./action_build/dl
    key: ${os}-${model}-dl-${REPO_FLAG_HASH}-${BUILD_DATE}
```

- `if: always()`：`Build Firmware` 失败也会执行。
- `continue-on-error: true`：即使 `dl` 目录不存在（clone 阶段就失败），也不会
  掩盖真正的编译错误。
- `make download` 使用 `.tmp` + rename，失败时不会把半截文件留在正式文件名下。

## 效果

| 场景 | 改前 | 改后 |
|---|---|---|
| 第一次冷构建失败 | `dl` 不保存，第二次冷下载 | 失败也保存 `dl`，第二次直接命中 |
| sing-box 出 beta | 每次重下，永远不缓存 | 本次重下，构建结束写入新快照；之后命中 |
| 两次构建间隔 2 周 | 旧 key 一直存在，新包不缓存 | 每次构建一份新快照，最近的包都在 |
| 缓存体积 | 1 份 | 每次一份，GitHub 10GB LRU 淘汰旧份 |

## 没有改的部分

- `staging_dir` / `.ccache` 仍然走原来的 `actions/cache`，**只在成功时保存**。
  失败构建的 `staging_dir` 可能是半成品，暂不 `always()` 保存，避免下一轮
  拿到不一致的 stamp。
- 如果实测第二次仍然明显超过 45 分钟，下一步优先把 `.ccache` 也改成
  restore/save + `if: always()`；`.ccache` 是安全的，`.ccache` 目录损坏最多
  退回重新编译。
- `Delete Old Cache` 的删除前缀是 `${os}-${model}-${REPO_FLAG_HASH}-`，
  `dl` 的 `${os}-${model}-dl-...` 不匹配，不会被误删；旧 `dl` 快照由
  GitHub 的 10GB LRU 淘汰。

## 验证

- 两个 workflow 用 PyYAML 解析通过。
- 未触发 GitHub Actions；实际命中率和第二次构建耗时需要下一次 CI 观察
  `Restore Downloads` / `Save Downloads` 的日志。

## 涉及文件

- `.github/workflows/build_wrt.yml`
- `.github/workflows/release_wrt.yml`
- `changelogs/2026-11-04_0110_dl-cache-always-save.md`
