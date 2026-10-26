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
  - 保留 CS-02 专属：`ath11k-firmware-qcn9074-ddwrt`、`luci-app-athena-led`、`luci-app-cupsd`、`luci-app-dockerman`、`luci-app-emmc-health`、`luci-app-quickfile`、`luci-app-sqm`、`luci-app-tailscale`。
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
- `wrt_core/deconfig/fragments/samba_ksmbd.config`
- `wrt_core/deconfig/fragments/samba4.config`
- `wrt_core/deconfig/fragments/usb_storage.config`
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
- `wrt_core/patches/992_set-wifi-uci.sh`
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

第三次测试（Run 40293290928）：

- `xiaomi_ax3600_libwrt` ✅ 成功，1h34m
- `aliyun_ap8220_libwrt` ✅ 成功，1h42m
- `jdcloud_ipq60xx_libwrt` ❌ 4h41m 后失败

jdcloud 的失败点：

```text
ERROR: info field 'version' has invalid value: package version is invalid
ERROR: failed to create package: package version is invalid
make[3]: *** [.../luci-lib-docker-v0.3.4-r1.apk] Error 99
```

原因：仓库从 `lisaac/luci-lib-docker` 和 `lisaac/luci-app-dockerman` 同步的包使用：

```make
PKG_VERSION:=v0.3.4
PKG_VERSION:=v0.5.26
```

apk 要求包版本以数字开头，`v0.3.4-r1` 会被判定为非法版本；opkg 之前接受这种写法。

修复：在 `wrt_core/modules/package_source_updates.sh` 增加 `fix_apk_leading_v_version()`，同步后把 `PKG_VERSION:=v...` 改为 `PKG_VERSION:=...`，对 `luci-lib-docker` 和 `luci-app-dockerman` 都生效。

### WiFi 国家码与 AP8220 频段修复

从 VIKINGYFY 迁移到 LibWrt 后发现：

- AP8220 的 2.4G 国家码变成 `US`
- 5G 可能因为接口已有加密而跳过配置，停留在 `auto`，自动落到 100 信道
- 手动设置可以恢复，但默认配置不应该这样

原因：`wrt_core/patches/992_set-wifi-uci.sh` 里：

1. `country='US'` 是硬编码的；
2. `configure_wifi()` 在 `default_radioX.encryption` 已有非 `none` 值时直接 `return 0`，会连射频级的 channel / country / txpower 一起跳过；
3. AP8220 使用固定 `radio0=5G`、`radio1=2.4G`，LibWrt 的 phy 枚举顺序可能不同。

修复：

- `update.sh` 增加 `WIFI_COUNTRY="CN"`，`target_fixes.sh` 安装脚本时替换 `__WIFI_COUNTRY__`；需要其他区域时只改这一处。
- `configure_wifi()` / `configure_wifi7()` 的射频级参数（channel、htmode、country、txpower、cell_density 等）始终写入；接口级 SSID / 加密 / key 只在未配置时写入，保留用户已有 AP 设置。
- AP8220 通过 `wireless.radioN.band` 查找 5G / 2.4G 对应的 radio，找不到时再回退到 0/1。
- 6G 射频继续使用 `00`，避免 `CN` 直接禁用 6G。

### 通用软件包安全合并（来自 IPQ807X 手工配置）

根据 `~/Downloads/IPQ807X (2).config` 与 immwrt CS-02 配置做对比，只把**通用软件**合并到 `compile_base.config`，设备专属、代理栈和硬件相关项不进入 base。

已合并到 base：

- 命令行工具：`at`、`bash`、`bc`、`bind-dig`、`btop`、`coreutils`、`coreutils-base64`、`coreutils-cksum`、`coreutils-nohup`、`coreutils-shuf`、`hostapd-utils`、`iperf3`、`kmod-zram`、`zram-swap`、`nano`、`screen`、`socat`、`umdns`、`unzip`、`wget-ssl`
- LuCI 通用应用：`luci-app-commands`、`luci-app-ddns`、`luci-app-socat`、`luci-app-zerotier`、`luci-i18n-zerotier-zh-cn`、`luci-theme-bootstrap`、`luci-theme-argon`

### SMB 后端：默认改用 ksmbd

`samba4-server` 是完整的用户态 Samba4，体积和依赖都明显偏重；家庭路由器的 SMB 共享更适合使用内核态的 `ksmbd`：

- 新增 `fragments/samba_ksmbd.config`：
  - `CONFIG_PACKAGE_ksmbd-server=y`
  - `CONFIG_PACKAGE_luci-app-ksmbd=y`
  - 依赖 `kmod-fs-ksmbd` + `libnl`，比 Samba4 轻很多。
- 新增 `fragments/samba4.config`：
  - `CONFIG_PACKAGE_luci-app-samba4=y`
  - 保留给确实需要完整 Samba4 功能的设备/场景。
- CS-02、AP8220、AX3600 的默认 fragment 已加入 `samba_ksmbd`，即默认使用 ksmbd。
- 两个 fragment 互斥，不要同时启用；需要完整 Samba4 时把 `samba_ksmbd` 换成 `samba4`。

`luci-app-samba4` 不再放在 `compile_base.config` 中，避免所有机型被动背上完整 Samba4。

### USB 支持按设备拆分

硬件差异：

- **AX3600 没有 USB 口**
- **CS-02 / AP8220 有 USB 3.0**

因此从 `compile_base.config` 移除了所有 USB host/net/storage kmod 和 `usbutils` / `usbmuxd`，新增 `fragments/usb_storage.config`，只在有 USB 的设备启用：

- CS-02：`nss,samba_ksmbd,usb_storage,docker_deps,proxy`
- AP8220：`nss,samba_ksmbd,usb_storage,proxy`
- AX3600：`nss,nss_mem_512m,samba_ksmbd,proxy`（不含 USB）

AX3600 的 LibWrt 设备定义本身也会移除 `kmod-usb3` / `kmod-usb-dwc3` / `kmod-usb-dwc3-qcom`，现在 base 也不再额外加入 USB 包，镜像不会再带无用的 USB 驱动。

### jdcloud apk 固件包名修复

Run 40330163237 的 jdcloud 在 target install 阶段失败：

```text
ERROR: unable to select packages:
  ath11k-firmware-qcn9074 (no such package):
    required by: world[ath11k-firmware-qcn9074]
```

原因：`update_ath11k_fw()` 把 `ath11k-firmware/Makefile` 换成了只提供 `-ddwrt` 包名的版本，并重写了 `target.mk`，但 `target/linux/qualcommax/image/*.mk` 的设备 `DEVICE_PACKAGES` 里仍然写死 `ath11k-firmware-qcn9074` 等旧包名。AP8220 / AX3600 的设备定义没有这个旧包名，所以没有触发；CS-02 的 `ipq60xx.mk` 有，最终在 apk 安装时找不到包。

修复：`update_ath11k_fw()` 现在同时重写：

- `target/linux/qualcommax/ipq50xx/target.mk`
- `target/linux/qualcommax/ipq60xx/target.mk`
- `target/linux/qualcommax/ipq807x/target.mk`
- `target/linux/qualcommax/image/ipq50xx.mk`
- `target/linux/qualcommax/image/ipq60xx.mk`
- `target/linux/qualcommax/image/ipq807x.mk`

把 `ath11k-firmware-ipq5018`、`ipq6018`、`ipq8074`、`qcn9074` 统一改成 `-ddwrt` 包名。

保留在 CS-02 专属配置：

- `luci-app-athena-led`、`luci-app-cupsd`、`luci-app-dockerman`、`luci-app-emmc-health`、`luci-app-quickfile`、`luci-app-tailscale`
- `ath11k-firmware-qcn9074-ddwrt`、`luci-app-sqm`

明确跳过、没有合并的项：

- 代理栈：`luci-app-passwall`、`luci-app-homeproxy`、`xray-core`、`sing-box`、`sing-box-tiny`、`shadowsocks-rust-*`、`shadowsocksr-libev-*`、`v2ray-plugin`、`tuic-client`、`hysteria`、`microsocks`、`chinadns-ng`、`dns2socks`、`geoview`、`ipt2socks`、`tcping` 等
- `ip-full`：与默认 `ip-tiny` 存在替代/冲突关系，避免为了一个工具引入全局包替换
- `luci-app-partexp`：分区工具且当前不在 custom_feed 同步列表中，暂不引入
- `dnsmasq-full` 及其子选项：仓库已有 `change_dnsmasq2full` 统一处理
- `luci-app-passwall_INCLUDE_*`：属于 passwall 子选项，不是独立通用软件

`luci-app-socat`、`luci-app-tailscale` 已加入 custom_feed 同步列表和 required 目录检查。

---

## 8. 后续建议

1. 先跑一次单独的 `xiaomi_ax3600_libwrt` 或 `aliyun_ap8220_libwrt`，确认 LibWrt + 12.5 + apk 的 ipq807x 链路正常。
2. 再跑 `jdcloud_ipq60xx_libwrt`，重点验证 CS-02 的 QCN9074、athena-led、emmc-health 和 quickfile。
3. 三个单模型都通过后，再跑 `libwrt_all`。
4. 如果 quickfile 的 Rust/外部下载拖慢或阻塞构建，优先把它降级为可选，而不是让它影响三个机型。
5. 如果确定长期不用 mesh/WDS，可以把 `nss.config` 里的 `CONFIG_NSS_DRV_WIFI_MESH_ENABLE` / `CONFIG_ATH11K_NSS_MESH_SUPPORT` 也一并关掉，避免配置与 12.5 固件能力不一致。
