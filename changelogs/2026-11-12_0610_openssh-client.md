# 2026-11-12 — base 级别新增 openssh-client

## 变更

`wrt_core/deconfig/compile_base.config` 新增：

```text
CONFIG_PACKAGE_openssh-client=y
```

位置在 `openssh-sftp-server` 之后。

## 范围

- `compile_base.config` 对所有机型生效
- 包括使用 `light_apps` 的 AP8220 / AX6600 / BE12 Pro
- 与默认的 `dropbear` 服务端不冲突（只安装客户端工具）

## 说明

- 提供 `ssh`、`scp`、`sftp`、`ssh-keygen` 等客户端命令
- 体积约 1–2 MB（未压缩），对现有 overlay 余量影响很小
- 没有触发编译

## 涉及文件

- `wrt_core/deconfig/compile_base.config`
- `changelogs/2026-11-12_openssh-client.md`
