#!/bin/zsh

cd "$(dirname "$0")/.." || exit 1
python3 tools/manage_access.py
printf '\n按回车键关闭此窗口...'
read -r
