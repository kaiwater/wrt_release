# 2026-11-04 01:17 — CI: ccache 拆成 restore/save，失败构建也保存

## 背景

`dl` 缓存解决的是下载，但真正占大头的始终是 **compile**：

| 阶段 | 冷启动典型耗时 |
|---|---|
| `make download` | 5–20 分钟（慢镜像 30–60） |
| `make -j$(nproc+1)` | 1.5–3.5 小时 |
| 打包/镜像 | 5–15 分钟 |

第一次构建 3 小时失败时，原来的 `Cache Dependencies` 是合并的
`actions/cache`，**只在 job 成功时保存**，所以 `.ccache` 和 `staging_dir`
一起丢掉。修复后的第二次构建即使有 `dl` 缓存，仍然要重新编译大部分目标，
到不了 45 分钟。

`CONFIG_CCACHE=y` 已经在 `wrt_core/deconfig/compile_base.config` 里，缓存目录
是 `./action_build/.ccache`，所以只差"失败也保存"。

## 变更

两个 workflow 同步修改：

- `.github/workflows/build_wrt.yml`
- `.github/workflows/release_wrt.yml`

### 1. `Cache Dependencies` → `Cache Staging`

只保留 `staging_dir`，仍走原来的 `actions/cache`（成功时才保存）：

```yaml
- name: Cache Staging
  uses: actions/cache@v6.1.0
  with:
    path: ./action_build/staging_dir
    key: ${os}-${model}-${REPO_FLAG_HASH}-${ADD}-${REMOVE}-${BUILD_DATE}
```

`staging_dir` 不在失败时保存：半成品 stamp 有让下一轮构建状态不一致的风险。

### 2. 新增 `Restore Ccache`

放在 `Restore Downloads` 之后、`Cache Staging` 之前：

```yaml
- name: Restore Ccache
  uses: actions/cache/restore@v6.1.0
  with:
    path: ./action_build/.ccache
    key: ${os}-${model}-ccache-${REPO_FLAG_HASH}-${BUILD_DATE}
    restore-keys: |
      ${os}-${model}-ccache-${REPO_FLAG_HASH}-
      ${os}-${model}-ccache-
```

### 3. 新增 `Save Ccache`

放在 `Save Downloads` 之后：

```yaml
- name: Save Ccache
  if: always()
  continue-on-error: true
  uses: actions/cache/save@v6.1.0
  with:
    path: ./action_build/.ccache
    key: ${os}-${model}-ccache-${REPO_FLAG_HASH}-${BUILD_DATE}
```

- `if: always()`：编译失败也保存，第二次才能命中。
- `continue-on-error: true`：ccache 目录不存在或保存失败不会掩盖真正的编译错误。
- ccache 是纯编译缓存，条目损坏时 ccache 自己会丢弃重编，不会污染固件。

## 效果

| 场景 | 改前 | 改后 |
|---|---|---|
| 第一次冷构建失败 | `.ccache` 不保存 | `.ccache` 保存 |
| 第二次构建 | 重新编译大部分目标 | 命中 ccache，接近 45 分钟 |
| 成功构建 | 保存 | 保存（行为不变） |
| `staging_dir` | 成功保存 | 成功保存（行为不变） |

## 缓存体积与淘汰

- `dl` + `.ccache` + `staging_dir` 合计可能接近 GitHub 单仓库 10GB 上限。
- `Delete Old Cache` 的前缀是 `${os}-${model}-${REPO_FLAG_HASH}-`，不匹配
  `${os}-${model}-ccache-...`，所以旧 ccache 依赖 GitHub 的 LRU 淘汰。
- 如果实际占用过大，下一步可以在构建前加：

  ```sh
  ccache -M 2G || true
  ```

  限制 ccache 自身大小，而不是扩大缓存配额。

## 验证

- 两个 workflow 用 PyYAML 解析通过。
- 未触发 GitHub Actions；实际命中率需要观察下一次 CI 的
  `Restore Ccache` / `Save Ccache` 日志，以及第二次构建耗时。

## 涉及文件

- `.github/workflows/build_wrt.yml`
- `.github/workflows/release_wrt.yml`
- `changelogs/2026-11-04_0117_ccache-always-save.md`
