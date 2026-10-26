# README Changelog

日期：2026-10-26

本次变更的目标：从已停止维护的 `VIKINGYFY/immortalwrt` NSS 分支迁移到 `LiBwrt/LibWrt` 的 `25.12-nss` 分支，并用一次 GitHub Actions 构建同时产出：

- 京东云雅典娜 `RE-CS-02`（ipq60xx）
- 阿里云 `AP8220`（ipq807x，1GB）
- 小米 `AX3600`（ipq807x，512MB）

---

## 1. 平台拆分结论

`ipq60xx` 和 `ipq807x` 都是 `qualcommax` 下的 subtarget，但一个 `.config` 只能选择一个 subtarget。两者的 kernel config、DTS、image recipe、NSS 固件包和 ath11k 固件都不同，因此**必须分开构建**。

`AP8220` 和 `AX3600` 同属 `ipq807x`，可以共用一套源码树，但 NSS 内存档位是全局 Kconfig choice，不能按设备分别设置：

- AP8220：1GB → `NSS_MEM_PROFILE_HIGH`
- AX3600：512MB → `NSS_MEM_PROFILE_MEDIUM`

因此采用 **3 个并行 job**，而不是把三个机型塞进一个 build：

| job | 配置名 | 平台 | NSS 档位 |
| --- | --- | --- | --- |
| 1 | `jdcloud_ipq60xx_libwrt` | ipq60xx | 1G |
| 2 | `aliyun_ap8220_libwrt` | ipq807x | 1G |
| 3 | `xiaomi_ax3600_libwrt` | ipq807x | 512M |

---

## 2. 关键行为变更

### 2.1 切换到 apk

`wrt_core/deconfig/compile_base.config`：

```diff
-CONFIG_USE_APK=n
+CONFIG_USE_APK=y
```

评估结果：

- `LiBwrt/LibWrt` 25.12-nss、`immortalwrt/immortalwrt` master、`VIKINGYFY/immortalwrt` main 本身都默认 `USE_APK=y`，之前是仓库强制改回 opkg。
- `padavanonly/immortalwrt-mt798x` 21.02 没有 `USE_APK` 符号；24.10 的 `USE_APK` 依赖 `BROKEN`。这两个旧目标会忽略该配置，继续使用 opkg，不会被破坏。
- `release_wrt.yml` 的 kmods 打包原本就同时匹配 `kmod*.ipk` 和 `kmod*.apk`。
- `wrt_core/patches/nss_diag.sh` 原本就同时兼容 apk/opkg。
- `install_opkg_distfeeds`、`fix_opkg_check`、x86 的 99-distfeeds 修改在 apk 构建中会变成无害的空操作；保留它们是为了兼容仍走 opkg 的旧目标。
- `luci-lib-ipkg` 仍留在 base 中，在 apk 构建里是未使用的旧库；实际包管理页面由 `luci-app-package-manager` 提供。
- 旧缓存可能来自 opkg 时代。首次 apk 构建会先复用旧 `staging_dir`，构建结束后工作流会清理旧缓存；如果希望第一次就完全干净，可手动删除对应 Actions cache。

### 2.2 NSS 固件切到 12.5

`wrt_core/deconfig/fragments/nss.config`：

```diff
-CONFIG_NSS_FIRMWARE_VERSION_11_4=y
+# CONFIG_NSS_FIRMWARE_VERSION_11_4 is not set
+CONFIG_NSS_FIRMWARE_VERSION_12_5=y
```

评估结果：

- VIKINGYFY 当前 `nss-firmware` 固定为 12.5（2025.05.01，12.5 Release 210）。
- LibWrt 使用的 qosmio `NSS-12.5-K6.x` feed 本身以 12.5 为主版本；选择 11.4 会把 `qca-nss-drv`、`qca-nss-clients`、`nss-firmware` 一起切到 2021 年的 QSDK 11.4.0.5，并换用 `patches-11.4`。切到 12.5 后是 2024 年的 QSDK 12.5 驱动/客户端，和 feed 的主线一致。
- **唯一明确的回归**：12.5 不支持 NSS mesh（802.11s）offload；LibWrt README 也标注 WDS/MESH 需要 11.4。IPQ807x 的 RMNET 同样需要 11.4。
- 因此新增 `wrt_core/deconfig/fragments/nss_fw_11_4.config`，需要 mesh/WDS/RMNET 时在 `nss` 之后追加该 fragment 即可切回 11.4。
- VIKINGYFY 的 12.5 搭配的是其自维护的 QSDK 13.1 驱动，和 qosmio 的 12.5 驱动不是同一份代码；“VIKINGYFY 用 12.5”只能作为版本对齐参考，最终仍以 qosmio feed 的 12.5 组合为准。
- ipq807x 的 12.5 是 feed 主版本，风险较低；ipq60xx 在 qosmio README 中标注为 untested，若 CS-02 出现 NSS/WiFi 异常，给该设备追加 `nss_fw_11_4` 即可回退。

### 2.3 共享包上移到 compile_base

按“公共包统一放 base”的选择，`compile_base.config` 新增了：

- USB/存储：`kmod-fs-exfat`、`kmod-fs-vfat`、`kmod-usb-*`、`kmod-usb-storage*`、`kmod-usb2`
- 工具：`htop`、`fuse-utils`、`ntfs3-mount`、`openssh-sftp-server`、`tcpdump`、`sgdisk`、`openssl-util`、`resize2fs`、`qrencode`、`smartmontools-drivedb`、`usbutils`、`usbmuxd`、`mii-tool`、`xl2tpd`、`xz-utils`
- LuCI：`luci-app-adguardhome`、`luci-app-autoreboot`、`luci-app-diskman`、`luci-app-vlmcsd`

对应地从 `jdcloud_ipq60xx_libwrt.config` 和 `aliyun_ap8220_libwrt.config` 中删除了重复项。

注意：base 会应用到所有设备（包括 x64、N1、MTK、21.02 旧目标）。目标不支持的包会在 `make defconfig` 阶段被丢弃，但会增加无关目标的构建时间。如果后续希望只让高通设备带这些包，应把它们移到独立 fragment。

### 2.4 设备配置调整

- `jdcloud_ipq60xx_libwrt.config`
  - 只保留 `RE-CS-02` 一个 profile。
  - 移除 SS-01、CS-07、AX5-JDC。
  - 保留 CS-02 专属：`zram-swap`、`ath11k-firmware-qcn9074-ddwrt`、`luci-app-athena-led`、`luci-app-cupsd`、`luci-app-dockerman`、`luci-app-emmc-health`、`luci-app-quickfile`、`luci-app-samba4`、`luci-app-sqm`。
- `aliyun_ap8220_libwrt.config`
  - 只保留 target/device 定义。
  - 设备包补回上游默认的 `kmod-hci-uart`，避免覆盖默认包列表时丢掉蓝牙 UART。
- 新增 `xiaomi_ax3600_libwrt.config`
  - ipq807x 单 profile。
  - 不覆盖 `CONFIG_TARGET_DEVICE_PACKAGES`，沿用 LibWrt 的 AX3600 默认包（含 `ipq-wifi-xiaomi_ax3600`、ath10k 固件和上游的 USB3 屏蔽项）。
- 新增 `fragments/nss_mem_512m.config`
  - 在 `nss` 之后把 NSS 内存档位覆盖为 `MEDIUM`，供 AX3600 使用。

### 2.5 custom_feed 补齐

- `luci-app-quickfile`：
  - 之前在 small-package 中存在，但没有被同步，immwrt 构建里实际上也是静默缺失。
  - 现已按嵌套目录 `luci-app-quickfile/luci-app-quickfile` 和 `luci-app-quickfile/quickfile` 同步到 custom_feed。
  - 注意 `quickfile` 是 Rust 包，源码来自 `https://r2.cooluc.com/source`，会明显增加构建时间，并多一个外部下载依赖。
- `luci-app-athena-led`：
  - LibWrt 源码树不包含该包，现从 `VIKINGYFY/immortalwrt` 的 `package/emortal/luci-app-athena-led` 稀疏同步到 custom_feed。
  - 同步前会检查 `$BUILD_DIR/package/emortal/luci-app-athena-led` 是否已存在；VIKINGYFY 源码树自带该包，若再放进 custom_feed 会造成重复包名，因此该场景会自动跳过。
- `required_feed_dirs` 增加 `luci-app-quickfile`，条件增加 `luci-app-athena-led`。

### 2.6 ath11k 固件 Makefile 固化

`wrt_core/modules/target_fixes.sh` 原本每次从 `VIKINGYFY/immortalwrt/main` 下载 `ath11k-firmware/Makefile`。

现在：

- 新增 `wrt_core/patches/ath11k_fw.mk` 作为仓库内置文件。
- 构建时优先使用内置文件，文件不存在才回退到远程下载。
- 从 `mv` 改为 `cp`，避免本地文件被移出仓库。
- 仍保留把 `target.mk` 依赖改成 `-ddwrt` 包名的逻辑。

这减少了一个对 VIKINGYFY raw 文件的运行时依赖；固件本身仍从 `VIKINGYFY/ath11k-firmware-ddwrt` 拉取。

### 2.7 GitHub Actions 一次构建三机型

`build_wrt.yml` 和 `release_wrt.yml`：

- 新增 `xiaomi_ax3600_libwrt` 选项。
- 新增 `libwrt_all` 选项。
- 新增 `prepare` job，输出模型列表。
- `build` job 改为 matrix：
  - 单模型：`models=["<model>"]`
  - `libwrt_all`：`["jdcloud_ipq60xx_libwrt","aliyun_ap8220_libwrt","xiaomi_ax3600_libwrt"]`
- 所有 `inputs.model` 在 build job 内替换为 `matrix.model`，缓存 key、预克隆、构建、kmods 归档、release tag 均按模型隔离。
- `fail-fast: false`，某个模型失败不会取消另外两个。

`Release WRT` 选择 `libwrt_all` 会生成 3 个独立 release（每个模型一个 tag），不是合并成单个 release。

---

## 3. 使用方式

### GitHub Actions

手动运行 `Build WRT` 或 `Release WRT`，`model` 选择：

- `libwrt_all`：一次跑三个机型
- `jdcloud_ipq60xx_libwrt`：只跑 CS-02
- `aliyun_ap8220_libwrt`：只跑 AP8220
- `xiaomi_ax3600_libwrt`：只跑 AX3600

可选 `add_fragments` / `remove_fragments` 仍然有效，例如需要 NSS mesh 时：

```text
add_fragments: nss_fw_11_4
```

### 本地

```bash
./build.sh jdcloud_ipq60xx_libwrt
./build.sh aliyun_ap8220_libwrt
./build.sh xiaomi_ax3600_libwrt

# 只看配置组合
./build.sh xiaomi_ax3600_libwrt config_preview

# 临时切回 NSS 11.4
ADD_CONFIG_FRAGMENTS=nss_fw_11_4 ./build.sh jdcloud_ipq60xx_libwrt
```

---

## 4. 本次已验证

- `bash -n` 检查 `build.sh`、`update.sh`、`pre_clone_action.sh` 和全部 `wrt_core/modules/*.sh` 通过。
- 两个 workflow YAML 通过 Python YAML 解析。
- `config_preview` 通过：
  - `jdcloud_ipq60xx_libwrt`
  - `aliyun_ap8220_libwrt`
  - `xiaomi_ax3600_libwrt`
  - `redmi_ax6_libwrt`
  - `zn_m2_libwrt`
- 配置拼接检查：
  - CS-02 → `USE_APK=y`、`NSS_FIRMWARE_VERSION_12_5=y`、`NSS_MEM_PROFILE_HIGH`
  - AP8220 → `USE_APK=y`、`NSS_FIRMWARE_VERSION_12_5=y`、`NSS_MEM_PROFILE_HIGH`
  - AX3600 → `USE_APK=y`、`NSS_FIRMWARE_VERSION_12_5=y`、`NSS_MEM_PROFILE_MEDIUM`
- 未执行完整编译（当前环境没有拉取 LibWrt 源码和执行数小时构建）。

---

## 5. 风险与回滚

| 风险 | 说明 | 回滚/处理 |
| --- | --- | --- |
| NSS mesh/WDS/RMNET 不可用 | 12.5 固件不支持 NSS mesh，WDS/RMNET 需要 11.4 | 在 `nss` 后追加 `nss_fw_11_4` |
| ipq60xx 12.5 兼容性 | qosmio feed 标注 ipq60xx untested | CS-02 单独追加 `nss_fw_11_4` |
| quickfile 构建失败 | Rust + 外部 CDN `r2.cooluc.com` | 从 `jdcloud_ipq60xx_libwrt.config` 移除 `luci-app-quickfile=y`，并删除 custom_feed 中两个 quickfile 路径 |
| athena-led 依赖 VIKINGYFY | LibWrt 构建会稀疏克隆 VIKINGYFY 单包 | 可后续把该包 vendoring 到仓库内 |
| base 影响所有设备 | x64/N1/MTK/21.02 也会尝试这些包 | 不支持时会被 defconfig 丢弃；如需隔离，后续拆成高通专用 fragment |
| apk 首次缓存 | 可能复用 opkg 时代的 staging_dir | 删除对应 Actions cache 后重建 |
| CS-02 不再产出其他 ipq60xx 机型 | 已按“只保留 CS-02”调整 | 需要时把 SS-01/CS-07/AX5-JDC 的 profile 加回配置 |

---

## 6. 文件清单

### 新增

- `wrt_core/compilecfg/xiaomi_ax3600_libwrt.ini`
- `wrt_core/deconfig/xiaomi_ax3600_libwrt.config`
- `wrt_core/deconfig/fragments/nss_mem_512m.config`
- `wrt_core/deconfig/fragments/nss_fw_11_4.config`
- `wrt_core/patches/ath11k_fw.mk`
- `README_changelog.md`

### 修改

- `.github/workflows/build_wrt.yml`
- `.github/workflows/release_wrt.yml`
- `README.md`
- `wrt_core/compilecfg/aliyun_ap8220_libwrt.ini`
- `wrt_core/compilecfg/jdcloud_ipq60xx_libwrt.ini`
- `wrt_core/compilecfg/redmi_ax6_libwrt.ini`
- `wrt_core/compilecfg/zn_m2_libwrt.ini`
- `wrt_core/deconfig/aliyun_ap8220_libwrt.config`
- `wrt_core/deconfig/compile_base.config`
- `wrt_core/deconfig/fragments/nss.config`
- `wrt_core/deconfig/jdcloud_ipq60xx_libwrt.config`
- `wrt_core/deconfig/n1_immwrt.config`
- `wrt_core/modules/custom_feed.sh`
- `wrt_core/modules/target_fixes.sh`
- `wrt_core/update.sh`

---

## 7. 首次线上测试与修复

首次线上 `libwrt_all`（Run 40248454333）三个 job 都在 `xray-core` 处失败，错误一致：

```text
go: ../../go.mod requires go >= 1.27 (running go 1.26.10; GOTOOLCHAIN=local)
ERROR: package/feeds/custom_feed/xray-core failed to build.
```

原因：small-package 中的 `xray-core` 已更新到 `26.10.21`，其 `go.mod` 要求 Go >= 1.27，而仓库固定的 `packages_lang_golang` 分支是 `26.x`（Go 1.26.10）。

修复：`wrt_core/update.sh` 中：

```diff
-GOLANG_BRANCH="26.x"
+GOLANG_BRANCH="27.x"
```

`27.x` 分支当前是 Go 1.27.3，可满足 xray-core 的要求；sing-box 等已用 Go 1.26 成功编译的包也应保持兼容。

第二次线上测试（Run 40268255697）中，AP8220 已经通过编译阶段，在最后的 `package/install` 失败：

```text
ERROR: luci-app-oaf-7.0-r1: trying to overwrite usr/share/rpcd/acl.d/luci-app-oaf.json owned by appfilter-7.0.1-r1.
```

原因：small-package 的 `appfilter` 和 `luci-app-oaf` 都会安装同一个 ACL 文件。opkg 时代通常由 `--force-overwrite` 掩盖，apk 不允许包之间覆盖文件，因此直接报错。

修复：`wrt_core/modules/custom_feed.sh` 在同步 custom_feed 后，把 `open-app-filter/Makefile`（包名 `appfilter`）里重复安装的 ACL 目标文件名改为 `appfilter-oaf.json`。这样两份 ACL 定义都会保留：

- `luci-app-oaf.json`：`uci appfilter` 权限
- `appfilter-oaf.json`：`uci fwx` + `ubus fwx common` 权限

不是简单删除 appfilter 的 ACL，避免 OAF 的 ubus 页面权限缺失。

---

## 8. 后续建议

1. 先跑一次单独的 `xiaomi_ax3600_libwrt` 或 `aliyun_ap8220_libwrt`，确认 LibWrt + 12.5 + apk 的 ipq807x 链路正常。
2. 再跑 `jdcloud_ipq60xx_libwrt`，重点验证 CS-02 的 QCN9074、athena-led、emmc-health 和 quickfile。
3. 三个单模型都通过后，再跑 `libwrt_all`。
4. 如果 quickfile 的 Rust/外部下载拖慢或阻塞构建，优先把它降级为可选，而不是让它影响三个机型。
5. 如果确定长期不用 mesh/WDS，可以把 `nss.config` 里的 `CONFIG_NSS_DRV_WIFI_MESH_ENABLE` / `CONFIG_ATH11K_NSS_MESH_SUPPORT` 也一并关掉，避免配置与 12.5 固件能力不一致。
