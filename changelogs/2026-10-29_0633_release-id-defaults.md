# 2026-10-29 06:33 — Release 唯一标识、默认 LAN/WiFi 与 Release Note changelog

## 背景

之前只能通过 GitHub Release tag 区分构建，但设备运行时只能看到上游源码 revision（例如 `r0-20dae79`），无法确认具体是哪一次编译产物。

同时：

- 默认 LAN `192.168.1.1` 容易和 ISP 光猫冲突
- 默认 WiFi 密码还是 `12345678`
- Release Note 只有固定的 LAN/KMOD 信息，没有本次变更

## 变更

### 1. 运行时构建标识

每次构建写入：

```text
/etc/wrt_release
```

内容包含：

```sh
RELEASE_ID='26.10.29_06.33.00_jdcloud_ipq60xx_libwrt'
BUILD_DATE='26.10.29_06.33.00'
BUILD_MODEL='jdcloud_ipq60xx_libwrt'
SOURCE_REPO='https://github.com/LiBwrt/LibWrt.git'
SOURCE_BRANCH='25.12-nss'
SOURCE_REV='20dae79...'
BUILD_RUN='123456789'
LAN_ADDR='192.168.50.1'
LAN_CIDR='192.168.50.1/24'
WIFI_PASSWORD='kaiwater/wrt_release'
```

同时写入一个 `uci-defaults` 脚本，在首次启动时把这些字段追加到 `/etc/openwrt_release`：

- `DISTRIB_BUILD_ID`
- `DISTRIB_BUILD_DATE`
- `DISTRIB_BUILD_MODEL`
- `DISTRIB_SOURCE_REV`
- `DISTRIB_BUILD_RUN`

运行时可以直接：

```sh
cat /etc/wrt_release
ubus call system board
```

LuCI 状态页的 build 签名也从固定的 `build by ZqinKing` 改为：

```text
build by kaiwater/wrt_release <RELEASE_ID>
```

`BUILD_ID`、`BUILD_DATE`、`SOURCE_REV` 在工作流中生成，并传入 `build.sh` / `update.sh`；本地构建会使用时间戳和 `BUILD_MODEL` 作为回退。

### 2. Release Note 增加构建标识和 changelog

`release_wrt.yml` 的 Release Note 现在包含：

- Release ID
- Build date
- Model
- 源码 URL / branch / commit
- 对应 GitHub Actions run 链接
- 默认 LAN 地址
- 默认 WiFi 密码
- Kernel / KMOD 归档
- 插件列表
- **自上一次 Release 以来的 changelog**

新增 `wrt_core/release_changelog.sh`：

- 通过 GitHub Release 列表找到当前 `BUILD_DATE` 之前最近一次 Release
- 用 `git log --since=<上次发布时间> -- changelogs` 找出新增/修改的 changelog
- 没有历史或 API 不可用时回退到最近 3 个 changelog 文件
- Release workflow 的 Checkout 改为 `fetch-depth: 0`，保证 git 历史可用

### 3. 默认 LAN 改为 `192.168.50.1/24`

- `update.sh` 默认 `LAN_ADDR=192.168.50.1`
- `config_generate` 中的 `192.168.x.x` 替换为 `192.168.50.1`
- 默认掩码仍为 `255.255.255.0`
- Release Note 和 README 使用完整写法 `192.168.50.1/24`
- `50.1/24` 只是 `192.168.50.1/24` 的简写，配置中统一写完整地址，避免歧义

### 4. 默认 WiFi 密码改为 `kaiwater/wrt_release`

`992_set-wifi-uci.sh` 增加占位符：

```sh
WIFI_PASSWORD="__WIFI_PASSWORD__"
```

所有设备的默认无线 key 改为 `"$WIFI_PASSWORD"`。构建时由 `fix_default_set()` 将占位符替换为：

```text
kaiwater/wrt_release
```

只在接口尚未加密时写入，升级设备保留用户已有 WiFi 密码。

## 验证

- `bash -n build.sh`
- `bash -n wrt_core/update.sh`
- `bash -n wrt_core/modules/target_fixes.sh`
- `bash -n wrt_core/modules/luci_fixes.sh`
- `bash -n wrt_core/release_changelog.sh`
- `sh -n wrt_core/patches/992_set-wifi-uci.sh`
- 两个 workflow YAML 解析通过
- 临时源码树模拟 `write_release_identity()`：
  - 生成 `/etc/wrt_release`
  - 生成 `/etc/uci-defaults/98-wrt-release`
- 临时 `config_generate` 模拟：
  - `192.168.1.1` → `192.168.50.1`
- 临时 WiFi 脚本模拟：
  - 占位符被替换为 `kaiwater/wrt_release`
- `release_changelog.sh` 本地运行，能正确找到上一 Release 并输出新增 changelog
- 尚未重新编译；下一次 Release 验证运行时可读标识和 Release Note

## 风险

- `/etc/wrt_release` 包含默认 WiFi 密码；这是公开默认值，不是用户实际配置密码
- changelog 依赖 GitHub Release API 和 git 历史；API 不可用时自动回退到最近文件，不会阻塞发布
- 如果上一次 Release 与当前 `BUILD_DATE` 相同，会排除同批 tag，避免把同一次矩阵构建当成“上一次”
- 默认 LAN 变更只影响新刷机/未保留配置的设备；保留 `/etc/config/network` 的升级设备不会强制修改

## 涉及文件

- `.github/workflows/release_wrt.yml`
- `.github/workflows/build_wrt.yml`
- `build.sh`
- `wrt_core/update.sh`
- `wrt_core/modules/target_fixes.sh`
- `wrt_core/modules/luci_fixes.sh`
- `wrt_core/patches/992_set-wifi-uci.sh`
- `wrt_core/release_changelog.sh`
- `README.md`
- `changelogs/2026-10-29_0633_release-id-defaults.md`
