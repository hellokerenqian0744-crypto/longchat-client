#!/usr/bin/env python3
"""Add or update a GlassChat account in a GitHub access.json file.

Required environment variables:
  GITHUB_TOKEN      Fine-grained token with Contents read/write access
  GITHUB_REPO       owner/repository, for example owner/glasschat-access
Optional:
  GITHUB_FILE       File path, defaults to access.json
  GITHUB_BRANCH     Branch, defaults to main
"""

import base64
import getpass
import hashlib
import json
import os
import sys
import urllib.error
import urllib.request


def api_request(url, token, method="GET", payload=None):
    body = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(url, data=body, method=method)
    request.add_header("Authorization", f"Bearer {token}")
    request.add_header("Accept", "application/vnd.github+json")
    request.add_header("X-GitHub-Api-Version", "2022-11-28")
    if body:
        request.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.loads(response.read().decode())


def main():
    token = os.environ.get("GITHUB_TOKEN")
    repo = os.environ.get("GITHUB_REPO")
    path = os.environ.get("GITHUB_FILE", "access.json")
    branch = os.environ.get("GITHUB_BRANCH", "main")
    if not token or not repo:
        print("请先设置 GITHUB_TOKEN 和 GITHUB_REPO", file=sys.stderr)
        return 2

    try:
        account = input("账号: ").strip()
        password = getpass.getpass("密码: ")
        hwid = input("HWID: ").strip().upper()
    except EOFError:
        print("需要在交互式终端中输入账号、密码和 HWID", file=sys.stderr)
        return 2
    if not account or not password or not hwid:
        print("账号、密码和 HWID 都不能为空", file=sys.stderr)
        return 2

    endpoint = f"https://api.github.com/repos/{repo}/contents/{path}"
    try:
        current = api_request(f"{endpoint}?ref={branch}", token)
        document = json.loads(base64.b64decode(current["content"]).decode())
        sha = current["sha"]
    except urllib.error.HTTPError as error:
        if error.code != 404:
            print(f"读取 GitHub 文件失败: HTTP {error.code}", file=sys.stderr)
            return 1
        document, sha = {"users": []}, None
    except (KeyError, ValueError, json.JSONDecodeError) as error:
        print(f"access.json 格式错误: {error}", file=sys.stderr)
        return 1

    users = document.setdefault("users", [])
    password_hash = hashlib.sha256(f"GlassChat|{account.lower()}|{password}".encode()).hexdigest()
    matching = next((user for user in users if user.get("account", "").lower() == account.lower()), None)
    if matching:
        matching["passwordHash"] = password_hash
        hwids = {str(value).upper() for value in matching.get("hwids", [])}
        hwids.add(hwid)
        matching["hwids"] = sorted(hwids)
        message = f"Update {account}"
    else:
        users.append({"account": account, "passwordHash": password_hash, "hwids": [hwid]})
        message = f"Add {account}"

    content = base64.b64encode((json.dumps(document, indent=2, ensure_ascii=True) + "\n").encode()).decode()
    payload = {"message": message, "content": content, "branch": branch}
    if sha:
        payload["sha"] = sha
    try:
        api_request(endpoint, token, method="PUT", payload=payload)
    except urllib.error.HTTPError as error:
        print(f"写入 GitHub 失败: HTTP {error.code}", file=sys.stderr)
        return 1
    print(f"已提交 {account} 的账号与 HWID 到 {repo}/{path}@{branch}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
