# ksmbd 快速设置（内核态 SMB）

适用机型：启用 `samba_ksmbd` 片段的设备，目前是 **CS-02 / AX6600** 和
**AP8220**。AX3600 没有 USB，未启用 ksmbd。

## 和 samba4 的区别

`ksmbd` 是内核态 SMB 服务，只需要：

```text
kmod-fs-ksmbd
ksmbd-server（ksmbd.mountd）
luci-app-ksmbd
```

不再运行 samba4 的 `smbd` / `nmbd` 用户态进程，内存和 CPU 占用更低，
适合 RAM/Flash 紧张的路由器。代价是没有 samba4 的一些额外模块
（AD/打印机/复杂权限），家庭文件共享足够。

## 1. 先挂载磁盘

共享路径必须真实存在，例如：

```sh
mkdir -p /mnt/sda1/share
```

磁盘可以在 LuCI「系统 → 挂载点」里挂载并启用，或使用 `block mount`。
建议把共享目录放在 ext4 分区上；NTFS/exFAT 也可以，但权限和性能不如 ext4。

## 2. LuCI 设置（推荐）

进入：

```text
服务 → 网络共享（Network Shares）
```

- **全局**：workgroup、描述、接口（默认 `lan`）
- **用户**：添加 SMB 用户（用户名 + 密码），这就是客户端登录用的账号
- **共享**：名称、路径（如 `/mnt/sda1/share`）、允许用户、是否可写
- 勾选启用，保存并应用

LuCI 会自动生成 `/var/etc/ksmbd/ksmbd.conf` 并启动服务。

## 3. 命令行设置

创建 SMB 用户（会提示输入密码）：

```sh
ksmbd.adduser -a kaiwater
```

也可以非交互：

```sh
ksmbd.adduser -a kaiwater -p 'your-password'
```

添加共享：

```sh
uci add ksmbd share
uci set ksmbd.@share[-1].name='share'
uci set ksmbd.@share[-1].path='/mnt/sda1/share'
uci set ksmbd.@share[-1].users='kaiwater'
uci set ksmbd.@share[-1].read_only='0'
uci set ksmbd.@share[-1].guest_ok='0'
uci set ksmbd.@share[-1].create_mask='0664'
uci set ksmbd.@share[-1].dir_mask='0775'
uci commit ksmbd
```

全局参数：

```sh
uci set ksmbd.@globals[0].workgroup='WORKGROUP'
uci set ksmbd.@globals[0].description='OpenWrt SMB'
uci set ksmbd.@globals[0].interface='lan'
uci commit ksmbd
```

启用并重启：

```sh
/etc/init.d/ksmbd enable
/etc/init.d/ksmbd restart
```

## 4. 客户端访问

```text
Windows:  \\192.168.50.1\share
macOS:    smb://192.168.50.1/share
```

把 `192.168.50.1` 换成设备实际的 LAN 地址。

## 5. 发现（可选）

- **Windows**：需要 `wsdd2`（CS-02/AX6600 已带；其他机型看 profile）
- **macOS**：ksmbd 的 init 会通过 `procd_add_mdns` 发布 `_smb._tcp`；
  如果 profile 带了 `smb_avahi`，avahi 也会发布同一条服务
- 不建议开启 SMB1 / NetBIOS；现代 Windows/macOS 都用 SMB2/3

## 6. 排错

```sh
lsmod | grep ksmbd
/etc/init.d/ksmbd status
logread -e ksmbd
cat /var/etc/ksmbd/ksmbd.conf
uci show ksmbd
```

常见问题：

| 现象 | 检查 |
|---|---|
| 连接被拒绝 | `ksmbd` 是否 running，445 端口是否被防火墙拦截 |
| 登录失败 | `ksmbd.adduser` 的用户名是否和 share 的 `users` 一致 |
| 只能读不能写 | share 的 `read_only`、目录权限、磁盘是否只读 |
| 看不到共享 | 共享目录是否存在，`browseable` 是否被关闭 |
| Windows 发现不到 | `wsdd2` 是否安装并运行在 LAN 上 |

## 7. 性能提示

- ksmbd 走内核路径，SMB 大文件读写通常比 samba4 更省 CPU
- 共享目录尽量放在 ext4；NTFS3/exFAT 的内核开销更高
- 不建议在 USB 2.0 磁盘上同时跑多个大文件写入
