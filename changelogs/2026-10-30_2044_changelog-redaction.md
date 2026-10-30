# 2026-10-30 20:44 — Changelog 脱敏

## 变更

- 移除 `changelogs/2026-10-30_1950_be12-trim.md` 中的内网 IP，改为“一个 Tenda BE12 Pro 设备”
- 不记录设备 SSH 地址、主机名、MAC、SSID、实际密钥等现场信息

## 后续约定

changelog 只保留：

- 设备型号或设备角色
- 复现/验证结论
- 构建参数、Release ID、源码 revision
- 必要的命令模板（使用占位符，不写真实私网地址）

不写入：

- 私网/公网 IP
- SSH 用户名 + 地址
- 客户端 MAC、SSID、主机名
- 用户实际 WiFi 密码、密钥、token
- 其他可定位到具体现场的信息

## 备注

当前工作树中的该 changelog 已脱敏。旧提交历史里仍可能保留修改前的文本；本次没有重写历史，避免影响已有提交和 Release 引用。如果以后需要彻底清理历史，需要单独做 history rewrite。

## 涉及文件

- `changelogs/2026-10-30_1950_be12-trim.md`
- `changelogs/2026-10-30_2044_changelog-redaction.md`
