# 2026-10-28 15:36 — 恢复 VIKINGYFY main 三机型编译

## 背景

项目里以 `*_immwrt` 命名的 Qualcomm 设备配置，实际使用：

```text
REPO_URL=https://github.com/VIKINGYFY/immortalwrt.git
REPO_BRANCH=main
BUILD_DIR=imm-nss
```

之前只有 `aliyun_ap8220_immwrt` 和 `jdcloud_ipq60xx_immwrt`，没有 `xiaomi_ax3600_immwrt`，而且两个旧配置的 app/package 策略和 LibWrt 轨道不一致。

本次把 VIKINGYFY main 作为一个独立构建轨道恢复，并确保不和 LibWrt 的 patch 混用。

## 变更

### 1. 新增三机型聚合入口

`Build WRT` / `Release WRT` 新增：

- `immwrt_all`
- `xiaomi_ax3600_immwrt`

`immwrt_all` 展开为：

```json
["jdcloud_ipq60xx_immwrt", "aliyun_ap8220_immwrt", "xiaomi_ax3600_immwrt"]
```

仍然复用现有 workflow，不复制一套 action；矩阵、缓存、release 步骤保持一致。

### 2. 新增 AX3600 VIKINGYFY main 配置

- `wrt_core/compilecfg/xiaomi_ax3600_immwrt.ini`
- `wrt_core/deconfig/xiaomi_ax3600_immwrt.config`

使用 VIKINGYFY main / `imm-nss`，片段：

```text
nss,nss_mem_512m,samba_ksmbd,proxy
```

AX3600 没有 USB，因此不加入 `usb_storage`。

### 3. 对齐 AP8220 / jdcloud 的 app 与片段

- `aliyun_ap8220_immwrt`：
  - 片段改为 `nss,samba_ksmbd,usb_storage,proxy`
  - target device packages 与 LibWrt 对齐，并保留 AP8220 的 `kmod-hci-uart`
- `jdcloud_ipq60xx_immwrt`：
  - 从多 profile 收窄为只构建 RE-CS-02
  - 片段改为 `nss,samba_ksmbd,usb_storage,docker_deps,proxy`
  - 去掉旧的 `luci-app-samba4`，改用 ksmbd
  - 保留 athena-led、cupsd、dockerman、emmc-health、quickfile、sqm、tailscale 等 device app
- app 包统一来自：
  - `compile_base.config`
  - `samba_ksmbd.config`
  - `usb_storage.config`
  - `docker_deps.config`
  - `proxy.config`

### 4. patch 按上游分离

`wrt_core/modules/target_fixes.sh` 增加基础判断：

- `is_libwrt_build()`
- `is_vikingyfy_nss_build()`

行为：

- `fix_ath11k_nss_stats_layout()` 只在 LibWrt 执行，VIKINGYFY 跳过
- `fix_ath11k_nss_rxrate_filter()`：
  - 如果发现 VIKINGYFY 自带的 `999-922`，跳过
  - 非 LibWrt 构建也跳过
  - 不会修改 VIKINGYFY 的 `199-003`
- `update_nss_pbuf_performance()` 分两条路径：
  - LibWrt：继续修改 `pbuf.uci` 和 init 的 `stats_disable` 默认值
  - VIKINGYFY：只修改它自己的 `qca-nss-pbuf.init` 中硬编码的 `echo 1` 为 `echo 0`，不碰 LibWrt 的 pbuf 配置

这样 VIKINGYFY 和 LibWrt 的 patch/源码修正不会互相污染。

## 验证

- 三个 `config_preview` 均通过：
  - `aliyun_ap8220_immwrt`
  - `jdcloud_ipq60xx_immwrt`
  - `xiaomi_ax3600_immwrt`
- `bash -n wrt_core/modules/target_fixes.sh` 通过
- `bash -n wrt_core/update.sh` 通过
- 两个 workflow YAML 解析通过
- 用临时源码树模拟：
  - LibWrt：仍会添加 `-DNSS_FIRMWARE_VERSION_12_5`、修改 199-003、设置 pbuf stats_disable=0
  - VIKINGYFY：跳过 define/199-003，并把 `qca-nss-pbuf.init` 的 `echo 1` 改为 `echo 0`
- 尚未触发完整三机型编译；下一步需要跑一次 `immwrt_all` 验证包依赖和实际编译

## 风险

- VIKINGYFY main 是 6.18 + QSDK 13.1，首次构建没有热缓存，耗时会较长。
- VIKINGYFY main 固定 12.5 NSS，没有 `nss_fw_11_4` 回退；mesh/WDS/RMNET 场景需要单独确认。
- 新的 AP8220/jdcloud 配置改用 ksmbd，需要首次构建确认 `ksmbd-server` / `luci-app-ksmbd` 在 VIKINGYFY feed 中可用。
- 如果 VIKINGYFY 上游修改 `qca-nss-pbuf.init` 的写法，stats_disable 修改会打印警告并跳过，不会阻塞编译。

## 涉及文件

- `.github/workflows/build_wrt.yml`
- `.github/workflows/release_wrt.yml`
- `wrt_core/modules/target_fixes.sh`
- `wrt_core/compilecfg/aliyun_ap8220_immwrt.ini`
- `wrt_core/deconfig/aliyun_ap8220_immwrt.config`
- `wrt_core/compilecfg/jdcloud_ipq60xx_immwrt.ini`
- `wrt_core/deconfig/jdcloud_ipq60xx_immwrt.config`
- `wrt_core/compilecfg/xiaomi_ax3600_immwrt.ini`
- `wrt_core/deconfig/xiaomi_ax3600_immwrt.config`
- `README.md`
- `changelogs/2026-10-28_1536_immortal-three-models.md`
