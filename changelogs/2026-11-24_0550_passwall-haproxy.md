# 2026-11-24 — PassWall 负载均衡补上 HAProxy

## 背景

PassWall 的“负载均衡”节点类型（HAPROXY）需要 `haproxy`，启动时会检查版本：

```text
haproxy($haproxy_ver) 程序版本低，HAPROXY 负载均衡启动失败，请更新到 3.0 以上版本。
```

`proxy.config` 里一直是：

```text
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Haproxy=n
```

所以负载均衡功能在这些机型上不可用。

## 变更

新增 fragment `wrt_core/deconfig/fragments/haproxy.config`：

```text
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Haproxy=y
CONFIG_PACKAGE_haproxy=y
```

追加到两个 profile 的 fragment 列表末尾（必须在 `proxy` 之后覆盖）：

```text
aliyun_ap8220_libwrt    ...,proxy,light_apps,haproxy
jdcloud_ipq60xx_libwrt  ...,proxy,light_apps,haproxy
```

AX3600 本次不启用。

custom_feed 里的 haproxy 是 3.4.6，满足 PassWall 的 >= 3.0 要求。

## 体积

haproxy 3.x 的二进制和配置大约 1.2–1.5 MB，压缩进 squashfs 后更小。

AP8220 的分区是满分配（总计 124 MiB）：

```text
kernel       5.4 MiB
rootfs      41.8 MiB   ← 当前 squashfs 42.0 MB，正好占满
rootfs_data 73.5 MiB
```

UBI 的 rootfs 卷在 sysupgrade 时会按新镜像重建，rootfs 变大、`rootfs_data`
相应缩小，1 MB 级别的增长不会影响刷机。

## 生效方式

下次重编 AP8220 / AX6600 时生效，本次不单独重编。
