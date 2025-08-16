#!/bin/bash
# 状态检查模块

# 检查服务状态
check_status() {
    info "检查 Xray Reality 服务状态..."
    
    printf "\n${GREEN}=== 系统信息 ===${RESET}\n"
    printf "服务器IP: $(curl -s https://api.ipify.org 2>/dev/null || echo '获取失败')\n"
    printf "系统时间: $(date)\n"
    printf "运行时间: $(uptime -p 2>/dev/null || uptime)\n"
    
    printf "\n${GREEN}=== Xray 服务状态 ===${RESET}\n"
    if systemctl is-active --quiet xray; then
        printf "${GREEN}✓ Xray 服务: 运行中${RESET}\n"
        
        # 显示详细状态
        printf "服务状态: $(systemctl is-active xray)\n"
        printf "启用状态: $(systemctl is-enabled xray)\n"
        
        # 显示进程信息
        xray_pid=$(pgrep -f "xray run")
        if [ -n "$xray_pid" ]; then
            printf "进程ID: $xray_pid\n"
            printf "内存使用: $(ps -p $xray_pid -o rss= | awk '{printf "%.1f MB", $1/1024}')\n"
        fi
        
        # 显示版本信息
        if command -v xray &> /dev/null; then
            printf "Xray版本: $(xray version 2>/dev/null | head -1)\n"
        fi
        
        # 检查端口监听
        if netstat -tlnp 2>/dev/null | grep -q ":443"; then
            printf "${GREEN}✓ 端口443: 正在监听${RESET}\n"
        else
            printf "${RED}✗ 端口443: 未监听${RESET}\n"
        fi
        
    else
        printf "${RED}✗ Xray 服务: 未运行${RESET}\n"
        
        # 尝试获取错误信息
        printf "错误信息:\n"
        systemctl status xray --no-pager -l | tail -5
    fi
    
    printf "\n${GREEN}=== Nginx 服务状态 ===${RESET}\n"
    if systemctl is-active --quiet nginx; then
        printf "${GREEN}✓ Nginx 服务: 运行中${RESET}\n"
        printf "服务状态: $(systemctl is-active nginx)\n"
        printf "启用状态: $(systemctl is-enabled nginx)\n"
        
        # 检查端口监听
        if netstat -tlnp 2>/dev/null | grep -q ":80"; then
            printf "${GREEN}✓ 端口80: 正在监听${RESET}\n"
        else
            printf "${RED}✗ 端口80: 未监听${RESET}\n"
        fi
    else
        printf "${RED}✗ Nginx 服务: 未运行${RESET}\n"
    fi
    
    printf "\n${GREEN}=== 配置文件状态 ===${RESET}\n"
    
    # 检查 Xray 配置
    if [ -f "/usr/local/etc/xray/config.json" ]; then
        printf "${GREEN}✓ Xray 配置文件: 存在${RESET}\n"
        
        # 验证配置文件
        if xray test -config /usr/local/etc/xray/config.json &>/dev/null; then
            printf "${GREEN}✓ 配置文件语法: 正确${RESET}\n"
        else
            printf "${RED}✗ 配置文件语法: 错误${RESET}\n"
        fi
        
        # 显示配置信息
        if [ -f "/usr/local/etc/xray/uuid.txt" ]; then
            printf "UUID: $(cat /usr/local/etc/xray/uuid.txt)\n"
        fi
        
        # 显示协议信息
        protocol=$(grep -o '"protocol": "[^"]*' /usr/local/etc/xray/config.json | head -1 | cut -d'"' -f4)
        printf "协议: $protocol\n"
        
        port=$(grep -o '"port": [0-9]*' /usr/local/etc/xray/config.json | head -1 | cut -d' ' -f2)
        printf "端口: $port\n"
        
    else
        printf "${RED}✗ Xray 配置文件: 不存在${RESET}\n"
    fi
    
    printf "\n${GREEN}=== 客户端连接信息 ===${RESET}\n"
    if [ -f "/root/client_config.txt" ]; then
        printf "${GREEN}✓ 客户端配置: 可用${RESET}\n"
        printf "配置文件: /root/client_config.txt\n"
        
        if [ -f "/root/qrcode.txt" ]; then
            printf "二维码: /root/qrcode.txt\n"
        fi
        
        printf "\n${BLUE}VLESS连接：${RESET}\n"
        cat /root/client_config.txt
        
    else
        printf "${RED}✗ 客户端配置: 不存在${RESET}\n"
        printf "请重新安装或重新生成配置\n"
    fi
    
    printf "\n${GREEN}=== 日志文件 ===${RESET}\n"
    if [ -f "/var/log/xray/access.log" ]; then
        access_lines=$(wc -l < /var/log/xray/access.log 2>/dev/null || echo 0)
        printf "访问日志: $access_lines 条记录\n"
    fi
    
    if [ -f "/var/log/xray/error.log" ]; then
        error_lines=$(wc -l < /var/log/xray/error.log 2>/dev/null || echo 0)
        printf "错误日志: $error_lines 条记录\n"
        
        # 显示最近的错误（如果有）
        if [ "$error_lines" -gt 0 ]; then
            printf "\n${YELLOW}最近的错误日志:${RESET}\n"
            tail -3 /var/log/xray/error.log 2>/dev/null
        fi
    fi
    
    printf "\n${GREEN}=== 防火墙状态 ===${RESET}\n"
    if command -v ufw &>/dev/null; then
        ufw_status=$(ufw status 2>/dev/null | head -1)
        printf "UFW状态: $ufw_status\n"
        
        # 检查端口规则
        if ufw status | grep -q "443"; then
            printf "${GREEN}✓ 端口443规则: 已配置${RESET}\n"
        else
            printf "${YELLOW}⚠ 端口443规则: 未配置${RESET}\n"
        fi
    else
        printf "UFW: 未安装\n"
    fi
    
    # 检查 iptables
    if command -v iptables &>/dev/null; then
        iptables_443=$(iptables -L INPUT -n 2>/dev/null | grep -c ":443")
        if [ "$iptables_443" -gt 0 ]; then
            printf "${GREEN}✓ iptables 443规则: 已配置${RESET}\n"
        else
            printf "${YELLOW}⚠ iptables 443规则: 未明确配置${RESET}\n"
        fi
    fi
}

# 实时查看日志
view_logs() {
    printf "选择要查看的日志:\n"
    printf "1. Xray 访问日志\n"
    printf "2. Xray 错误日志\n"
    printf "3. 部署日志\n"
    printf "4. 实时监控 Xray 日志\n"
    printf "请选择 [1-4]: "
    read -r log_choice
    
    case $log_choice in
        1)
            if [ -f "/var/log/xray/access.log" ]; then
                info "显示 Xray 访问日志（最近50行）"
                tail -50 /var/log/xray/access.log
            else
                warning "访问日志文件不存在"
            fi
            ;;
        2)
            if [ -f "/var/log/xray/error.log" ]; then
                info "显示 Xray 错误日志（最近50行）"
                tail -50 /var/log/xray/error.log
            else
                warning "错误日志文件不存在"
            fi
            ;;
        3)
            if [ -f "/var/log/xray_deploy.log" ]; then
                info "显示部署日志（最近50行）"
                tail -50 /var/log/xray_deploy.log
            else
                warning "部署日志文件不存在"
            fi
            ;;
        4)
            info "实时监控 Xray 日志（Ctrl+C 退出）"
            if [ -f "/var/log/xray/access.log" ]; then
                tail -f /var/log/xray/access.log
            else
                warning "访问日志文件不存在"
            fi
            ;;
        *)
            warning "无效选择"
            ;;
    esac
}

# 主状态检查函数
status_main() {
    printf "选择操作:\n"
    printf "1. 查看服务状态\n"
    printf "2. 查看日志\n"
    printf "请选择 [1-2]: "
    read -r status_choice
    
    case $status_choice in
        1)
            check_status
            ;;
        2)
            view_logs
            ;;
        *)
            warning "无效选择"
            ;;
    esac
}