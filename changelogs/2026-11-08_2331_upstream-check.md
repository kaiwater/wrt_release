# 2026-11-08 23:31 — 上游对比脚本

## 背景

每次人工对比四条固件线的上游提交都要重复查 release、取源码 revision、调 compare API，步骤固定但容易漏。

## 变更

新增：

```text
tools/upstream-check.sh
```

用法：

```sh
./tools/upstream-check.sh
MAX_COMMITS=60 ./tools/upstream-check.sh
```

覆盖四条线：

| # | 名称 | 上游 | 基线来源 |
|---|---|---|---|
| 1 | LibWrt（AX6600 / CS-02） | `LiBwrt/LibWrt` `25.12-nss` | 最近一次 `jdcloud_ipq60xx_libwrt` release 的 Source rev |
| 2 | VIKINGYFY main（AP8220） | `VIKINGYFY/immortalwrt` `main` | 最近一次 `aliyun_ap8220_immwrt` release 的 Source rev |
| 3 | chasey wifi7（BE12 Pro） | `chasey-dev/immortalwrt-mt798x-rebase` `25.12-dev-wifi7` | 最近一次 `tenda_be12_pro_immwrt` release 的 Source rev |
| 4 | chasey 25.12（RAX3000M） | `chasey-dev/immortalwrt-mt798x-rebase` `25.12` | 最新 `build-YYYYMMDD-N` release 对应 staging 缓存 key 中的 upstream commit |

行为：

- 自动从 release 正文解析 `Source: ... @ <rev>`
- 解析不到时回退为 release 日期之前的上游最后一个提交
- 第 4 条线从 `kaiwater/immortalwrt-mt798x-25.12` 的 Actions 缓存 key 提取 upstream commit
- 输出每条线的新增提交（日期、短 SHA、分类、标题）
- 分类：`SECURITY` / `WIFI` / `KERNEL` / `DRIVER` / `OTHER`
- 末尾输出摘要和是否需要评估重编的提示

## 验证

本地执行结果（2026-11-08）：

```text
LibWrt 25.12-nss      0
VIKINGYFY main        0
chasey wifi7          0
chasey 25.12 (RAX)    +13
```

第 4 条线新增 13 个 `mtk: hnat-detect` 相关提交，其中 2 个涉及防火墙转发语义与 reload 后的重新检测。

## 说明

- 只读脚本，不修改任何仓库或设备
- 需要已登录的 `gh`
- 脚本不含设备地址、主机名等现场信息
- 没有触发编译

## 涉及文件

- `tools/upstream-check.sh`
- `README.md`
- `changelogs/2026-11-08_2331_upstream-check.md`
