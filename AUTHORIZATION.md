# GitHub 授权文件

在 GitHub 仓库创建 `access.json`，然后把 `AccessAuthorization.accessURL` 改为该文件的 Raw URL。

文件格式：

```json
{
  "users": [
    {
      "account": "alice",
      "passwordHash": "SHA256(GlassChat|alice|password)",
      "hwids": ["HWID"]
    }
  ]
}
```

密码哈希规则为：`SHA256("GlassChat|" + account.lowercased() + "|" + password)`。账号、密码哈希和 HWID 三项必须同时匹配。

应用不包含本地直通账户，所有登录都必须通过远程授权文件校验。
