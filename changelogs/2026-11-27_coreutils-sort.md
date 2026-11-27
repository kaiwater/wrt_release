# 2026-11-27 — 基础包加入 coreutils-sort

`compile_base.config` 增加：

```text
CONFIG_PACKAGE_coreutils-sort=y
```

覆盖所有使用 `compile_base` 的 profile，包括：

```text
AX6600 / CS-02
AP8220
AX3600
BE12 Pro
以及 x64 / N1 / MTK 等其它 profile
```

体积很小（单个 applet），下次构建生效。

`kaiwater/immortalwrt-mt798x-build` 那边同步在
`defconfig/rax3000m-openclash.config` 和 `defconfig/wr30u-minimal.config`
里启用，覆盖 RAX3000M / 256M / ME / WR30U。
