# PassWall geo 数据（B 方案：完整数据集）

这里放的是 PassWall 规则更新时实际下载的完整数据集：

```text
geoip.dat     15.7 MB → geoip.dat.gz     3.4 MB
geosite.dat   10.9 MB → geosite.dat.gz   3.6 MB
```

来源（PassWall `rule_update.lua` 默认地址）：

```text
https://github.com/Loyalsoldier/geoip/releases/latest/download/geoip.dat
https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
```

文件取自 AX6600 于 2026-11-16 更新后的数据。

构建时由 `wrt_core/modules/target_fixes.sh` 的 `install_passwall_geo()` 解压到
`package/base-files/files/usr/share/v2ray/`，只对 `jdcloud_ipq60xx_libwrt`
（AX6600 / CS-02）生效。这样 PassWall 首次启动就有和在线更新一致的名单，
不需要先联网下载。

更新方式：在设备上执行 PassWall 的规则更新，然后重新打包：

```sh
gzip -9c /usr/share/v2ray/geoip.dat   > geoip.dat.gz
gzip -9c /usr/share/v2ray/geosite.dat > geosite.dat.gz
```
