#!/bin/bash
# Xray 双协议一键部署脚本
# 支持Reality+VLESS和Shadowsocks双协议

set -e

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

# 路径定义
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XRAY_CONF="/usr/local/etc/xray/config.json"
LOG_FILE="/var/log/xray_deploy.log"

# 日志函数
log() {
    printf "$(date '+%Y-%m-%d %H:%M:%S') - %s\n" "$1" | tee -a "$LOG_FILE"
}

info() {
    printf "${BLUE}[信息]${RESET} %s\n" "$1" | tee -a "$LOG_FILE"
}

success() {
    printf "${GREEN}[成功]${RESET} %s\n" "$1" | tee -a "$LOG_FILE"
}

warning() {
    printf "${YELLOW}[警告]${RESET} %s\n" "$1" | tee -a "$LOG_FILE"
}

error() {
    printf "${RED}[错误]${RESET} %s\n" "$1" | tee -a "$LOG_FILE"
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "此脚本需要 root 权限运行！"
        exit 1
    fi
}

# 显示菜单
show_menu() {
    clear
    echo "======================================================"
    echo "        Xray 双协议部署管理脚本"
    echo "======================================================"
    echo ""
    echo "1. 全新安装 Xray 双协议"
    echo "2. 从备份恢复配置"
    echo "3. 备份当前配置"
    echo "4. 查看服务状态"
    echo "5. 生成客户端连接"
    echo "6. Docker代理配置"
    echo "7. 卸载服务"
    echo "0. 退出"
    echo ""
    echo -n "请选择操作 [0-7]: "
}

# 主函数
main() {
    check_root
    
    # 检查命令行参数
    if [[ "$1" == "--auto-install" ]]; then
        info "自动安装模式..."
        . "$SCRIPT_DIR/modules/install.sh"
        install_main
        success "安装完成！"
        exit 0
    fi
    
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                info "开始全新安装..."
                . "$SCRIPT_DIR/modules/install.sh"
                install_main
                read -p "按任意键继续..."
                ;;
            2)
                info "开始恢复配置..."
                . "$SCRIPT_DIR/modules/restore.sh"
                restore_main
                read -p "按任意键继续..."
                ;;
            3)
                info "开始备份配置..."
                . "$SCRIPT_DIR/modules/backup.sh"
                backup_main
                read -p "按任意键继续..."
                ;;
            4)
                info "查看服务状态..."
                . "$SCRIPT_DIR/modules/status.sh"
                status_main
                read -p "按任意键继续..."
                ;;
            5)
                info "生成客户端连接..."
                . "$SCRIPT_DIR/modules/install.sh"
                generate_client_config
                read -p "按任意键继续..."
                ;;
            6)
                info "Docker代理配置..."
                . "$SCRIPT_DIR/modules/docker.sh"
                docker_main
                read -p "按任意键继续..."
                ;;
            7)
                info "开始卸载..."
                . "$SCRIPT_DIR/modules/uninstall.sh"
                uninstall_main
                read -p "按任意键继续..."
                ;;
            0)
                info "退出脚本"
                exit 0
                ;;
            *)
                warning "无效选择，请重新选择"
                sleep 2
                ;;
        esac
    done
}

# 运行主函数
main "$@"