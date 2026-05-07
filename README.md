# claude-code-mirror

每日同步 [Claude Code](https://claude.com/claude-code) 官方分发到本仓库的 GitHub Release，便于国内用户加速下载。

## 镜像了什么

每个版本的 GH Release 包含：

| 文件 | 说明 |
|--|--|
| `manifest.json` | 官方原版（含 8 平台 SHA256） |
| `SHA256SUMS` | 平铺的 SHA256 列表 |
| `darwin-arm64-claude` | macOS Apple Silicon |
| `darwin-x64-claude` | macOS Intel |
| `linux-arm64-claude` | Linux ARM64 (glibc) |
| `linux-arm64-musl-claude` | Linux ARM64 (musl) |
| `linux-x64-claude` | Linux x64 (glibc) |
| `linux-x64-musl-claude` | Linux x64 (musl) |
| `win32-arm64-claude.exe` | Windows ARM64 |
| `win32-x64-claude.exe` | Windows x64 |

资产名格式是 `{platform}-{binary}`，因为 GH Release 不支持子目录。

## 通道指针

- `channels/latest.txt` — 最新版本号（每次同步成功后更新）
- `channels/stable.txt` — stable 通道版本号

应用通过 `https://raw.githubusercontent.com/zuoliangyu/claude-code-mirror/main/channels/<channel>.txt` 读取（也可以走 GH 加速代理）。

## 同步机制

`.github/workflows/sync.yml`：

- 每天 UTC 18:00（北京 02:00）跑一次
- 也可以手动触发，可选只同步 latest / stable / both
- 流程：
  1. `curl /latest` 拿版本号
  2. 已有同 tag release 则只更新通道指针
  3. 否则跑 `sync/sync.sh` 下载 manifest + 8 个二进制并校验
  4. `gh release create` 上传所有产物
  5. 提交 `channels/{channel}.txt` 到 main
  6. 失败时自动开 issue
- 自动清理：保留最近 5 个 release，老的删（连 tag 一起）

## 镜像列表

`mirrors.json` 由桌面应用 `ai-cli-installer` 启动时读取。修改后推 main，所有用户下次启动就生效。

格式：

```json
{
  "version": 1,
  "mirrors": [
    { "kind": "upstream", "name": "official", "base": "https://downloads.claude.ai/claude-code-releases" },
    { "kind": "gh_release", "name": "ghfast", "owner": "...", "repo": "...", "proxy": "https://ghfast.top" }
  ]
}
```

`upstream` 类型：直连任意暴露 `claude-code-releases` URL 结构的源。
`gh_release` 类型：本仓库的 GH Release（可选 `proxy` 字段套加速器）。

## 用户怎么用

不是终端用户的入口——终端用户应当下载 `ai-cli-installer-dist` 的桌面应用。

如果你想纯命令行装，可以：

```sh
# 走 ghfast 加速拉本仓库的 latest binary（以 linux-x64 为例）
VERSION=$(curl -fsSL https://raw.githubusercontent.com/zuoliangyu/claude-code-mirror/main/channels/latest.txt)
curl -fsSL "https://ghfast.top/https://github.com/zuoliangyu/claude-code-mirror/releases/download/v$VERSION/linux-x64-claude" -o claude
chmod +x claude
./claude install latest
```

完整 install.sh 风格的脚本可以参考 [`install/`](install/) 目录（待补）。

## 法律说明

本仓库仅做透明镜像，所有二进制均原封不动地从 `https://downloads.claude.ai/claude-code-releases/` 同步，校验 SHA256 与官方 manifest 完全一致。

不修改、不重新打包、不绑定其他内容。Claude Code 的版权与许可归 Anthropic。
