# Access 管理工具

设置环境变量后运行：

```bash
export GITHUB_TOKEN='github_pat_...'
export GITHUB_REPO='hellokerenqian0744-crypto/longchat-access'
python3 tools/manage_access.py
```

可选变量：`GITHUB_FILE`（默认 `access.json`）、`GITHUB_BRANCH`（默认 `main`）。

Token 需要 fine-grained repository token，并只授予目标仓库的 **Contents: Read and write** 权限。密码只在终端隐藏输入，并以客户端约定的 SHA-256 哈希写入 JSON。
