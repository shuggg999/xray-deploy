#!/bin/bash
# Xray Reality 一键安装脚本
# 支持远程安装：curl -sSL https://raw.githubusercontent.com/shuggg999/xray-deploy/main/install.sh | bash

set -e

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

# GitHub仓库信息
REPO_URL="https://github.com/shuggg999/xray-deploy"
RAW_URL="https://raw.githubusercontent.com/shuggg999/xray-deploy/main"
INSTALL_DIR="/opt/xray-deploy"

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误: 此脚本需要 root 权限运行！${RESET}"
    echo "请使用: sudo bash 或者以 root 用户运行"
    exit 1
fi

echo -e "${GREEN}======================================================"
echo "        Xray Reality 一键安装脚本"
echo "======================================================${RESET}"
echo ""

# 检查系统要求
echo -e "${YELLOW}检查系统环境...${RESET}"

# 检查操作系统
if ! command -v curl >/dev/null 2>&1; then
    echo -e "${YELLOW}安装 curl...${RESET}"
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y curl
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl
    else
        echo -e "${RED}错误: 无法安装 curl，请手动安装后重试${RESET}"
        exit 1
    fi
fi

# 创建安装目录
echo -e "${YELLOW}创建安装目录...${RESET}"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 下载所有必要文件
echo -e "${YELLOW}下载项目文件...${RESET}"

# 下载主要脚本文件
echo -e "${BLUE}  下载 deploy.sh...${RESET}"
curl -sSL -f "$RAW_URL/deploy.sh" -o deploy.sh || {
    echo -e "${RED}错误: 下载 deploy.sh 失败${RESET}"
    exit 1
}

echo -e "${BLUE}  下载 VERSION 文件...${RESET}"
curl -sSL -f "$RAW_URL/VERSION" -o VERSION || {
    echo -e "${YELLOW}警告: 下载 VERSION 文件失败，继续安装...${RESET}"
}

# 创建 modules 目录并下载模块文件
echo -e "${BLUE}  下载模块文件...${RESET}"
mkdir -p modules

modules=("install.sh" "backup.sh" "restore.sh" "status.sh" "docker.sh" "uninstall.sh")
for module in "${modules[@]}"; do
    echo -e "${BLUE}    下载 modules/$module...${RESET}"
    curl -sSL -f "$RAW_URL/modules/$module" -o "modules/$module" || {
        echo -e "${RED}错误: 下载 modules/$module 失败${RESET}"
        exit 1
    }
done

# 创建 templates 目录并下载模板文件
echo -e "${BLUE}  下载配置模板...${RESET}"
mkdir -p templates
curl -sSL -f "$RAW_URL/templates/config.template.json" -o templates/config.template.json || {
    echo -e "${RED}错误: 下载配置模板失败${RESET}"
    exit 1
}

# 设置执行权限
echo -e "${YELLOW}设置脚本权限...${RESET}"
chmod +x deploy.sh
chmod +x modules/*.sh

echo -e "${GREEN}✓ 所有文件下载完成！${RESET}"
echo ""
echo -e "${GREEN}安装目录: ${INSTALL_DIR}${RESET}"
echo ""

# 启动主脚本
echo -e "${YELLOW}启动 Xray Reality 部署脚本...${RESET}"
echo ""

# 检查是否通过管道运行（一键安装模式）
if [ -p /dev/stdin ]; then
    echo -e "${GREEN}检测到一键安装模式，自动开始安装...${RESET}"
    echo ""
    # 自动执行安装
    "./deploy.sh" --auto-install
else
    # 交互模式
    exec "./deploy.sh"
fi