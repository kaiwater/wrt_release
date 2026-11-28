# 固件升级与发布流程

适用于 LibWrt / VIKINGYFY / chasey 各条线，以及两个仓库：

- `kaiwater/wrt_release`（LibWrt、VIKINGYFY、chasey wifi7）
- `kaiwater/immortalwrt-mt798x-build`（chasey 25.12，RAX3000M / WR30U 等）

核心原则：

1. **先备份，再刷机**
2. **先验收，再发布**
3. **release tag 等于镜像里的 build id**
4. **同型号同哈希的固件只留一份**
5. release notes / changelog 不写私网地址、主机名、SSID、MAC、密钥

---

## 1. 上游检查

```bash
cd ~/Other/wrt_release
./tools/upstream-check.sh
MAX_COMMITS=40 ./tools/upstream-check.sh   # 提交多时看全
```

基线来自两处：

- `tools/release-baseline.tsv`：repo + release tag → 源码 commit
- release 正文里的 `@ <commit>`（表里没有时兜底）

输出 `review` 表示有内核/无线/安全相关提交，建议重编；`optional` 只含其它改动。

---

## 2. 本地构建（Lima）

```bash
limactl start qnap-test
limactl shell qnap-test
```

VM 内：

```sh
sudo iscsiadm -m node -l
sudo multipathd reconfigure
sudo mount /mnt/qnap
cd /mnt/qnap/projects/wrt/wrt_release
git pull --rebase origin main
```

> `git stash pop` 后必须检查冲突标记：
> `grep -rn "^<<<<<<<\|^>>>>>>>" wrt_core build.sh`

构建：

```sh
ADD_CONFIG_FRAGMENTS=qnap_local ./build.sh <profile>
```

产物自动留在：

```text
artifacts/<profile>/     镜像、manifest、buildinfo、sha256sums
firmware/                扁平输出，供 Actions 使用
```

配置文件冲突、包路径冲突等修复见 `changelogs/`。

---

## 3. iCloud 备份（刷机前必须）

设备 → iCloud 目录：

```text
AX6600 / CS-02     iCloud/ax6600
AP8220             iCloud/ap8220
AX3600             iCloud/ax3600
BE12 Pro           iCloud/be12pro
RAX3000M / WR30U   iCloud/rax3000m
```

配置备份：

```bash
ssh root@<设备> 'f=/tmp/backup-<名称>-$(date +%F).tar.gz; sysupgrade -b $f'
scp root@<设备>:/tmp/backup-...gz "<iCloud 目录>/"
shasum -a 256 "<iCloud 目录>/backup-...gz"    # 与设备上输出比对
```

### AX6600 额外门禁

AX6600 的 `sysupgrade` 内部是 `reboot -f`，升级前必须先落盘：

```bash
for h in ax6600-p1 ax6600-p2; do
  ssh "$h" '/root/pre-upgrade/pre-upgrade.sh' || { echo "ABORT: $h"; exit 1; }
done
```

任一台失败就中止升级。

---

## 4. 刷机与验收

```bash
scp <镜像> root@<设备>:/tmp/up.bin
ssh root@<设备> 'sha256sum /tmp/up.bin'      # 必须与 artifact 一致
ssh root@<设备> 'nohup sysupgrade -v /tmp/up.bin >/tmp/sysupgrade.log 2>&1 &'
```

默认保留配置，逐台进行；指定跳过的设备（如 AP8220-P2）不要动。

启动后验收：

```sh
. /etc/openwrt_release; echo "$DISTRIB_DESCRIPTION"
echo "$DISTRIB_BUILD_ID"; uname -r
ls /etc/config | wc -l
/etc/init.d/ksmbd status
iw dev | grep -c Interface
```

检查点：

- build id 与本次构建一致，版本尾部带 `<YYYYMMDD HHMMSS> - <分支> <commit>`
- 内核版本符合预期（如 6.12.118）
- 配置数量与升级前接近，LAN 地址不变
- 对应服务正常（ksmbd / haproxy / PassWall 名单）
- 无线接口数量正常

---

## 5. 归档

```text
firmware-<MODEL>-<YYYYMMDD>.bin                 通用固件
libwrt-...-<日期>.bin / ...-20261128.itb        原始资产名 + 日期
backup-<名称>-<YYYY-MM-DD>.tar.gz               配置备份
```

规则：

- **同型号、同 sha256 的镜像只保留一份**（例如 AX6600 P1/P2 用同一镜像）
- 归档后核对 sha256 与构建产物一致

---

## 6. GitHub Release

tag 直接使用镜像里的 `DISTRIB_BUILD_ID`，例如：

```text
26.11.28_08.07.28_jdcloud_ipq60xx_libwrt
rax3000m-20261124
```

资产按机型：

```text
CS-02      factory + sysupgrade + manifest + config/feeds/version buildinfo + SHA256SUMS
AP8220     sysupgrade + manifest + SHA256SUMS
AX3600     sysupgrade + manifest + SHA256SUMS
BE12 Pro   sysupgrade + initramfs + manifest + SHA256SUMS
RAX 系列   sysupgrade/recovery + preloader/FIP/GPT + manifest + buildinfo + RELEASE.txt + SHA256SUMS
```

release notes 必须包含：

```text
上游仓库与 commit、内核版本、主要软件包版本、刷机验证范围
```

禁止出现私网 IP、SSH 目标、主机名、MAC、SSID、真实密钥。

发布后更新基线：

```text
tools/release-baseline.tsv
<repo>\t<tag>\t<源码 commit>\t<备注>
```

删除被取代的 release 时，同步删掉对应基线行。

---

## 7. 变更记录

每次构建/排障在 `changelogs/` 留一篇：

```text
YYYY-MM-DD_<主题>.md
```

写清背景、改动、验证结果和后续 TODO。

---

## 8. Lima 收尾

```sh
sudo umount /mnt/qnap
sudo systemctl stop iscsi-split.service
sudo iscsiadm -m node -u
sudo multipath -F
limactl stop qnap-test
```

不要直接 `limactl stop`：iSCSI 上的 ext4 需要先干净卸载。

---

## 9. 快速检查清单

```text
[ ] upstream-check 结果已确认
[ ] 构建成功，artifacts 完整
[ ] iCloud 配置备份完成并校验
[ ] AX6600 pre-upgrade gate 通过
[ ] 镜像 sha256 与产物一致
[ ] 逐台刷机并验收
[ ] iCloud 固件归档（同哈希只留一份）
[ ] release 发布，notes 无敏感信息
[ ] tools/release-baseline.tsv 已更新并提交
[ ] changelog 已提交
[ ] Lima 干净关闭
```
