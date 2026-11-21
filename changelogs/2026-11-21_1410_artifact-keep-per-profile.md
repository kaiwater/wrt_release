# 2026-11-21 — 构建产物按 profile 留档

## 背景

AP8220 和 AX3600 同属 `qualcommax/ipq807x`，本地为了省一份源码树，两个 profile
共用同一个构建目录：

```text
wrt_core/compilecfg/aliyun_ap8220_libwrt.ini   BUILD_DIR=libwrt-807x
wrt_core/compilecfg/xiaomi_ax3600_libwrt.ini   BUILD_DIR=libwrt-807x
```

`build.sh` 在每次构建前会清空 `bin/targets` 下的镜像和 manifest，构建结束后
又会 `rm -rf firmware/`。结果先构建的机型产物会被后一个机型覆盖：

```text
13:31 AX3600 构建 → 13:40 输出 bin/targets/qualcommax/ipq807x/
13:41 AP8220 重编 → bin/targets 里 AX3600 的镜像、manifest、sha256sums 全被清掉
```

本次 AX3600 的 manifest 就是这样丢的，只能重新构建一次。

## 变更

`build.sh` 复制到 `firmware/` 之后，再按 profile 留一份：

```text
artifacts/<profile>/
  *.bin / *.ubi / *.itb / *.fip / *efi.img.gz / *rootfs.tar.gz
  *.manifest
  config.buildinfo
  feeds.buildinfo
  version.buildinfo
  sha256sums
  profiles.json
```

`firmware/` 仍然保持扁平，GitHub Actions 里收集 `firmware/*.bin` 的逻辑不变；
`artifacts/` 加入 `.gitignore`，不会进仓库。

## 效果

- 同一 `BUILD_DIR` 下的不同 profile 不会再互相覆盖
- 重编某个机型时，另一个机型上一次成功构建的产物仍然完整
- 失败构建不会删除上一次成功产物（留档在构建成功之后才执行）

## 验证

- 本次 AP8220 重编产物已留档
- AX3600 重编完成后会用同样的路径留档，之后再发 release
