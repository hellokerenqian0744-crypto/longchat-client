# JBChat

JBChat（仓库工程名为 LongChat）是一款面向 macOS 26 的原生多模型 AI API 客户端。界面使用 SwiftUI 构建，支持 OpenAI 兼容接口与 Anthropic Messages API，并提供流式回复、模型切换、附件、主题和本地会话管理。

## 功能

- OpenAI 兼容与 Anthropic 两类提供商
- SSE 流式回复与思考内容展示
- 按模型保存推理强度
- 文本、图片及二进制附件
- 提供商模型列表刷新与快速切换
- CC Switch 提供商导入（实验性）
- 本地保存会话、设置及个性化选项
- macOS 原生侧边栏、设置窗口和液态玻璃主题

## 系统要求

- Apple Silicon Mac
- macOS 26 或更高版本
- 从源码构建时需要 Xcode 26 和 Swift 6.2 或更高版本

## 下载和运行

从仓库的 [Releases](https://github.com/hellokerenqian0744-crypto/longchat-client/releases) 页面下载最新的 `JBChat-*-macOS-arm64.zip`，解压后将 `JBChat.app` 移到“应用程序”文件夹。

当前 Release 使用临时签名，未经过 Apple 公证。首次运行时请在 Finder 中右键点击应用并选择“打开”，然后确认运行。

## 从源码构建

```bash
git clone https://github.com/hellokerenqian0744-crypto/longchat-client.git
cd longchat-client
swift build --configuration release
```

生成的可执行文件位于 Swift Package Manager 返回的 release 输出目录中：

```bash
swift build --configuration release --show-bin-path
```

也可以生成可分发的 `.app` 压缩包：

```bash
tools/package_app.sh v1.0.0
```

产物将写入 `dist/`。

## 配置提供商

打开“设置 → 提供商”，新增或编辑 API 提供商：

- OpenAI 兼容：填写 Base URL、API Key 和模型名称。
- Anthropic：填写 Anthropic API 地址、API Key 和模型名称。
- CC Switch：在“实验性”页面从 `~/.cc-switch/cc-switch.db` 导入配置。

API Key 和聊天数据只保存在本机。应用数据路径为：

```text
~/Library/Application Support/GlassChat/data.json
```

## 授权配置

应用当前包含基于 GitHub Raw JSON、账号密码哈希和设备 HWID 的访问控制。部署前请阅读 [AUTHORIZATION.md](AUTHORIZATION.md)，并将 `AccessAuthorization.accessURL` 改为自己的私有授权服务地址。

不要提交实际的 `access.json`、Token 或 `.env` 文件；这些路径已在 `.gitignore` 中排除。

## 自动化

- `Swift CI`：在 push、Pull Request 或手动触发时完成 Debug 与 Release 编译。
- `Release`：推送 `v*` 标签时构建 ARM64 应用包并创建 GitHub Release。

## 当前限制

- 仅支持 macOS 26 和 Apple Silicon。
- Release 为临时签名，未进行 Apple 公证。
- 文件夹、目标、计划和技能功能仍在开发中。

## 许可证

当前仓库未声明开源许可证，保留所有权利。
