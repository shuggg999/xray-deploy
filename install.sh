#!/bin/bash
# 快速安装脚本

set -e

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误: 此脚本需要 root 权限运行！${RESET}"
    echo "请使用: sudo $0"
    exit 1
fi

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}======================================================"
echo "        Xray Reality 快速安装"
echo "======================================================${RESET}"
echo ""
echo -e "${BLUE}检测到脚本位置: ${SCRIPT_DIR}${RESET}"
echo ""

# 设置执行权限
echo -e "${YELLOW}设置脚本权限...${RESET}"
chmod +x "$SCRIPT_DIR/deploy.sh"
chmod +x "$SCRIPT_DIR/modules/"*.sh 2>/dev/null || true

echo -e "${YELLOW}启动部署脚本...${RESET}"
echo ""

# 执行主脚本
cd "$SCRIPT_DIR"
exec "./deploy.sh"