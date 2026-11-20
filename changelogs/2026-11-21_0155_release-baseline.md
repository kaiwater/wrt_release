# 2026-11-21 — release 基线跟踪与固件版本标记

## 背景

MT798x 的构建方式已经改成：配置、workflow 和文档放在
`kaiwater/immortalwrt-mt798x-build`，构建时直接 clone
`chasey-dev/immortalwrt-mt798x-rebase` 25.12，不再使用旧仓库内部的
6.12.87 源码树。

这带来两个问题：

- release 正文和资产里只写“chasey-dev 25.12”，没有记录实际 commit
- `.last_sync_commit` 仍停在 11-12 的 `daa7695`，不能代表最近一次发布

## 基线

最近一次 release：

```text
repo:    kaiwater/immortalwrt-mt798x-build
tag:     wr30u-minimal-20261118
date:    2026-11-18
image:   DISTRIB_REVISION='r0-458d2f7'
chasey:  458d2f7e9295ee3709dc4f0d5ca5fabbd4cc1863
```

同日期的 Redmi AX6000 20261118 与 RAX `build-20261116-24-local`
也来自同一个 chasey 节点 `458d2f7`。

## 工具改动

新增 `tools/release-baseline.tsv`，按 release 记录对应的 chasey commit。

`tools/upstream-check.sh` 第 4 条改为：

- 同时扫描新 build 仓库和 legacy 仓库的 release
- 取最新 release 的 tag
- 优先从 `release-baseline.tsv` 读取该 release 的 chasey commit
- 取不到时回退到 staging 缓存 key 或 release 日期前的最后一个上游提交

输出示例：

```text
=== 4) chasey 25.12 (MT798x build)
  基线: 458d2f7e9295  (release wr30u-minimal-20261118 @ kaiwater/immortalwrt-mt798x-build)
  新增: 0（identical）
```

## 固件版本标记

build 仓库新增 `scripts/stamp-version.sh`（commit `72b6737`）：

```text
CONFIG_VERSION_CODE="r0-<chasey-short>-<YYYYMMDD>"
DISTRIB_DESCRIPTION='ImmortalWrt 25.12-SNAPSHOT r0-458d2f7-20261118'
```

覆盖：

```text
auto_rax3000m.yml
auto_360T7.yml
wr30u.yml
redmi_ax6000.yml
scripts/build-ax6000.sh
```

release notes 同时输出完整的 chasey commit，后续核对不再需要下载镜像
解 `/etc/openwrt_release`。

## 注意

- `.last_sync_commit` 不再作为发布基线
- `rax3000m.yml`（旧 6.12.87 树）未纳入版本标记
- `mt_wifi` temperature procfs 补丁目前仍在 legacy 仓库；要进入新 build
  流程，需要放到新仓库 `patches/` 并由 workflow 注入
