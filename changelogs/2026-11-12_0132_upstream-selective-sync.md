# 2026-11-12 01:32 — 选择性同步 ZqinKing/wrt_release 上游

## 背景

本仓库的直接上游是 `ZqinKing/wrt_release`。双方没有共同提交历史，只能按内容选择性移植。

本次按确认的清单同步：

- `7251121` refresh smartdns patch
- `f49ca18` refactor(passwall): extract source fixes module
- `fec9186` feat(passwall): integrate SmartDNS rules through custom.conf
- `6f56628` fix(build): sync miniupnpd from openwrt-25.12
- `4dea514` remove support redmi ax6000

未同步：

- `a4f65e8` lucky 本地包改 DL_DIR —— 按要求暂时不动 lucky
- `21087a2` lucky 3.4.1 二进制 —— 版本不匹配
- 其余主题、netwiz、新机型提交

## 变更

### 1. PassWall SmartDNS 集成

新增模块：

```text
wrt_core/modules/passwall_fixes.sh
```

包含：

- `apply_passwall_smartdns_patches`：按顺序应用 4 个补丁，`fuzz=0`，失败即中止
- `apply_passwall_rules_tweaks`：清空源码里的 chnlist（运行期由 PassWall 下载）
- `apply_passwall_xray_tweaks`：调整 xray RTT 采样参数

新增补丁：

```text
wrt_core/patches/passwall-smartdns-custom-conf.patch
wrt_core/patches/passwall-smartdns-ui-cleanup.patch
wrt_core/patches/passwall-smartdns-runtime.patch
wrt_core/patches/passwall-smartdns-loop-guard.patch
```

`update.sh` 改为 source 新模块，调用 `apply_passwall_fixes` 取代原来的 `apply_passwall_tweaks`；旧函数从 `feed_source_fixes.sh` 移除。

补丁已用当前 passwall `main`（2026-11-11）验证，四个补丁按顺序可干净应用。

### 2. miniupnpd 同步

`fix_miniupnpd()` 现在先从 `immortalwrt/packages` 的 `openwrt-25.12` 分支稀疏同步 `net/miniupnpd`，再安装 `999-chanage-default-leaseduration.patch`。

同时：

- `sync_sparse_packages_to_feed_dir()` 增加目标目录 `mkdir -p` 和失败处理
- `999-chanage-default-leaseduration.patch` 更新 hunk 行号（518→541、621→644）

### 3. SmartDNS 补丁刷新

`100-smartdns-optimize.patch` 更新 hunk 行号（632→664），与当前 smartdns init 对齐。

### 4. 移除 Redmi AX6000（21.02）

删除：

```text
wrt_core/compilecfg/redmi_ax6000_immwrt21.ini
wrt_core/deconfig/redmi_ax6000_immwrt21.config
```

同步移除两个 workflow 的 model 选项和 README 设备表对应行。
`jdcloud_ax6000_immwrt` 是不同机型，保持不变。

## 验证

- `bash -n` 通过：`passwall_fixes.sh`、`custom_feed.sh`、`target_fixes.sh`、`feed_source_fixes.sh`、`update.sh`
- 两个 workflow YAML 解析通过
- `./build.sh aliyun_ap8220_immwrt config_preview` 通过
- PassWall 四个补丁在当前上游源码上按顺序 dry-run/apply 均成功
- 全仓库已无 `redmi_ax6000_immwrt21`、`apply_passwall_tweaks` 引用

## 风险与注意

- PassWall 补丁使用 `fuzz=0`，上游源码变化时会**直接构建失败**，属于预期的快速失败
- miniupnpd 同步依赖网络，失败会中止构建
- lucky 未改动：本地仍是 `lucky_2.27.2` 压缩包，与 feed 版本 `3.5.0` 不一致的问题仍存在，后续单独处理

## 未做的事

- 没有触发编译
- 没有改动设备
- 没有移除 lucky 本地注入

## 涉及文件

- `wrt_core/modules/passwall_fixes.sh`（新增）
- `wrt_core/modules/feed_source_fixes.sh`
- `wrt_core/modules/custom_feed.sh`
- `wrt_core/modules/target_fixes.sh`
- `wrt_core/update.sh`
- `wrt_core/patches/passwall-smartdns-*.patch`（4 个新增）
- `wrt_core/patches/100-smartdns-optimize.patch`
- `wrt_core/patches/999-chanage-default-leaseduration.patch`
- `wrt_core/compilecfg/redmi_ax6000_immwrt21.ini`（删除）
- `wrt_core/deconfig/redmi_ax6000_immwrt21.config`（删除）
- `.github/workflows/build_wrt.yml`
- `.github/workflows/release_wrt.yml`
- `README.md`
- `docs/package-inventory.md`
- `changelogs/2026-11-12_0132_upstream-selective-sync.md`
