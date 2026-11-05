# 2026-11-05 09:32 — ca-certificates 根证书黑名单

## 背景

上游 `chasey-dev/immortalwrt-mt798x-rebase` 提交 `4a68657` 给 `ca-certificates` 增加了一条黑名单补丁：

- `emSign ECC Root CA - G3`
- `Comodo AAA Services root`

这两个根证书在 Debian 侧被明确 distrust（参考 Debian #1151413，前者曾签发使用异常私钥的中间 CA）。如果继续把它们打进固件，`/etc/ssl/certs` 与 `ca-certificates.crt` 会默认信任这些证书链，等于给上游 CA 体系投毒留了口子。

本仓库的上游不止一个（LibWrt、VIKINGYFY、immortalwrt、padavanonly、chasey-dev 等），不能只在单个上游里改，因此做成通用的构建期注入。

## 变更

新增补丁文件：

```text
wrt_core/patches/ca-certificates-blacklist-certs.patch
```

内容与 Debian / OpenWrt 上游一致，向 `ca-certificates` 源码包里的 `mozilla/blacklist.txt` 追加两行黑名单。

新增构建函数 `fix_ca_certificates_blacklist()`（`wrt_core/modules/target_fixes.sh`），由 `update.sh` 的 `stage_pre_install_source_fixes` 调用：

1. 在 `package/system/ca-certificates`（以及 `package/feeds/packages/ca-certificates` 兜底）中定位包目录
2. 检查 Makefile 是否为 Debian 源码布局（`DEBIAN` / `debian.org`），不是则跳过
3. 检查现有 `patches/` 是否已包含 `emSign` 黑名单，已包含则跳过
4. 否则安装为 `patches/1000-blacklist-certs.patch`

编号用 `1000-` 而不是 `0002-`，避免和上游后续新增的补丁编号冲突。

## 为什么要做兼容判断

- `LiBwrt/LibWrt` 25.12-nss 和 `immortalwrt/immortalwrt` master 已经自带同名补丁，重复安装会导致补丁冲突，所以先检测再跳过。
- `VIKINGYFY/immortalwrt` main 和 `padavanonly` 的两个分支还没有这条补丁，会走注入路径。
- 如果以后某个上游把 `ca-certificates` 换成非 Debian 源码包，函数会自动跳过，不会让构建失败。

## 验证

补丁对当前在用的三个 `ca-certificates` 版本都做过 dry-run，全部干净应用：

| 上游 | `ca-certificates` 版本 | 结果 |
|---|---|---|
| `padavanonly/immortalwrt-mt798x` openwrt-21.02 | 20230311 | 通过 |
| `padavanonly/immortalwrt-mt798x-6.6` openwrt-24.10-6.6 | 20260223 | 通过 |
| `VIKINGYFY` / `LibWrt` / `immortalwrt` / `chasey-dev` | 20260816 | 通过 |

另外用临时源码树模拟了四种分支：

- 正常注入：写入 `patches/1000-blacklist-certs.patch`
- 重复执行：第二次检测到 `emSign` 后跳过
- 上游已有同类补丁：跳过
- 非 Debian 源码布局 / 没有 `ca-certificates` 包：跳过

## 影响范围

- 所有设备的下一次编译
- 不影响已发布固件；需要重新编译并刷入才会生效
- 本次未触发重新编译

## 风险

- 黑名单里的标签如果在某个 `certdata.txt` 中不存在，只是不匹配，不会报错（`certdata2pem.py` 对未命中项静默忽略）。
- 如果上游彻底更换 `ca-certificates` 打包方式，补丁会自动跳过，需要人工复核。

## 涉及文件

- `wrt_core/patches/ca-certificates-blacklist-certs.patch`
- `wrt_core/modules/target_fixes.sh`
- `wrt_core/update.sh`
- `README.md`
- `changelogs/2026-11-05_0932_ca-certificates-blacklist.md`
