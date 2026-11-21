# PassWall 规则列表（预置到 AX6600 rootfs）

这些文件来自运行中的 AX6600：

```text
/usr/share/passwall/rules/chnlist
/usr/share/passwall/rules/chnroute
/usr/share/passwall/rules/chnroute6
```

PassWall 的 `rule_update.lua` 默认从这个地址下载：

```text
chnlist     https://fastly.jsdelivr.net/gh/felixonmars/dnsmasq-china-list/accelerated-domains.china.conf
            + apple.china.conf + google.china.conf（合并后写入 chnlist）
chnroute    https://ispip.clang.cn/all_cn.txt
chnroute6   https://ispip.clang.cn/all_cn_ipv6.txt
```

`gfwlist` 由 `luci-app-passwall` 包自带，不需要在这里重复放。

构建时由 `wrt_core/modules/target_fixes.sh` 的 `install_passwall_lists()`
解压到 `package/base-files/files/usr/share/passwall/rules/`，且只对
`jdcloud_ipq60xx_libwrt` 生效。

需要更新时，在设备上执行 PassWall 的规则更新，然后重新打包这三个文件：

```sh
gzip -9c /usr/share/passwall/rules/chnlist   > chnlist.gz
gzip -9c /usr/share/passwall/rules/chnroute  > chnroute.gz
gzip -9c /usr/share/passwall/rules/chnroute6 > chnroute6.gz
```

文件日期：2026-11-21（取自设备，PassWall 于 2026-11-16 更新）。
