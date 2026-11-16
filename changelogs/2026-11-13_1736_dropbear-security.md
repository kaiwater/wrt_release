# 2026-11-13 — Dropbear 2025.89 安全回移

## 变更

25.12 分支的 Dropbear 仍是 `2025.89`，未包含 2026.90/2026.92 的安全修复。
新增回移补丁：

```text
0009-curve25519-add-s-l-check.patch
0010-curve25519-check-y-lt-p.patch
0011-disallow-two-factor-with-blank-passwords.patch
0012-avoid-splitting-long-authorized-keys-lines.patch
```

覆盖：

- CVE-2026-3706：curve25519 缺少 `S < L` / `y < p` 检查
- `-t` 与 `-B` 组合的认证逻辑
- 超长 `authorized_keys` 行被拆分的问题

`forced_command` + `-t` 的修复已包含在原有的 0006 补丁中，无需重复添加。

## 应用方式

新增 `fix_dropbear_security_backports()`：

- 仅当 `PKG_VERSION=2025.89` 时复制补丁
- 上游升级到 2026.94 或更高版本后自动跳过
- 同时维护在独立 RAX 构建仓库的 `patches/dropbear/` 中

## 验证

- 在干净的 Dropbear 2025.89 源码上按顺序应用 0001–0012，全部干净通过
- 本机编译通过
- CS-02、BE12、RAX 构建出的 manifest 均为 `dropbear 2025.89-r3`

## 涉及文件

- `wrt_core/patches/dropbear/0009-0012`
- `wrt_core/modules/target_fixes.sh`
- `wrt_core/update.sh`
- RAX 仓库 `patches/dropbear/` 与构建工作流
