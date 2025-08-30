#!/bin/bash
# 状态检查模块

# 检查服务状态
check_status() {
    info "检查 Xray 双协议服务状态..."
    
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
        printf "\n${BLUE}=== 端口监听情况 ===${RESET}\n"
        if netstat -tlnp 2>/dev/null | grep -q ":443"; then
            printf "${GREEN}✓ 端口443(Reality): 正在监听${RESET}\n"
        else
            printf "${RED}✗ 端口443(Reality): 未监听${RESET}\n"
        fi
        
        if netstat -tlnp 2>/dev/null | grep -q ":8388"; then
            printf "${GREEN}✓ 端口8388(Shadowsocks): 正在监听${RESET}\n"
        else
            printf "${RED}✗ 端口8388(Shadowsocks): 未监听${RESET}\n"
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
        printf "\n${BLUE}=== 配置的协议 ===${RESET}\n"
        protocols=$(grep -o '"protocol": "[^"]*' /usr/local/etc/xray/config.json | cut -d'"' -f4)
        ports=$(grep -o '"port": [0-9]*' /usr/local/etc/xray/config.json | cut -d' ' -f2)
        
        protocol_array=($protocols)
        port_array=($ports)
        
        for i in "${!protocol_array[@]}"; do
            protocol=${protocol_array[$i]}
            port=${port_array[$i]}
            case $protocol in
                "vless")
                    printf "${GREEN}✓ VLESS Reality: 端口 $port${RESET}\n"
                    ;;
                "shadowsocks")
                    printf "${GREEN}✓ Shadowsocks: 端口 $port${RESET}\n"
                    ;;
                *)
                    printf "${BLUE}- $protocol: 端口 $port${RESET}\n"
                    ;;
            esac
        done
        
    else
        printf "${RED}✗ Xray 配置文件: 不存在${RESET}\n"
    fi
    
    printf "\n${GREEN}=== 客户端连接信息 ===${RESET}\n"
    
    # 检查 VLESS Reality 配置
    if [ -f "/root/vless_config.txt" ] || [ -f "/root/client_config.txt" ]; then
        printf "${GREEN}✓ VLESS Reality 配置: 可用${RESET}\n"
        
        if [ -f "/root/vless_config.txt" ]; then
            printf "配置文件: /root/vless_config.txt\n"
            if [ -f "/root/vless_qrcode.txt" ]; then
                printf "二维码: /root/vless_qrcode.txt\n"
            fi
            printf "\n${BLUE}VLESS Reality连接：${RESET}\n"
            cat /root/vless_config.txt
        elif [ -f "/root/client_config.txt" ]; then
            printf "配置文件: /root/client_config.txt (旧格式)\n"
            if [ -f "/root/qrcode.txt" ]; then
                printf "二维码: /root/qrcode.txt\n"
            fi
            printf "\n${BLUE}VLESS Reality连接：${RESET}\n"
            cat /root/client_config.txt
        fi
    else
        printf "${RED}✗ VLESS Reality 配置: 不存在${RESET}\n"
    fi
    
    # 检查 Shadowsocks 配置
    if [ -f "/root/ss_config.txt" ]; then
        printf "\n${GREEN}✓ Shadowsocks 配置: 可用${RESET}\n"
        printf "配置文件: /root/ss_config.txt\n"
        
        if [ -f "/root/ss_qrcode.txt" ]; then
            printf "二维码: /root/ss_qrcode.txt\n"
        fi
        
        printf "\n${BLUE}Shadowsocks连接：${RESET}\n"
        cat /root/ss_config.txt
        
        # 显示 Shadowsocks 密码
        if [ -f "/usr/local/etc/xray/ss_password.txt" ]; then
            printf "\n${BLUE}Shadowsocks 密码：${RESET}\n"
            cat /usr/local/etc/xray/ss_password.txt
        fi
    else
        printf "\n${RED}✗ Shadowsocks 配置: 不存在${RESET}\n"
    fi
    
    if [ ! -f "/root/vless_config.txt" ] && [ ! -f "/root/client_config.txt" ] && [ ! -f "/root/ss_config.txt" ]; then
        printf "\n${RED}请重新安装或重新生成配置${RESET}\n"
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
        
        if ufw status | grep -q "8388"; then
            printf "${GREEN}✓ 端口8388规则: 已配置${RESET}\n"
        else
            printf "${YELLOW}⚠ 端口8388规则: 未配置${RESET}\n"
        fi
    else
        printf "UFW: 未安装\n"
    fi
    
    # 检查 iptables
    if command -v iptables &>/dev/null; then
        iptables_443=$(iptables -L INPUT -n 2>/dev/null | grep -c ":443")
        iptables_8388=$(iptables -L INPUT -n 2>/dev/null | grep -c ":8388")
        
        if [ "$iptables_443" -gt 0 ]; then
            printf "${GREEN}✓ iptables 443规则: 已配置${RESET}\n"
        else
            printf "${YELLOW}⚠ iptables 443规则: 未明确配置${RESET}\n"
        fi
        
        if [ "$iptables_8388" -gt 0 ]; then
            printf "${GREEN}✓ iptables 8388规则: 已配置${RESET}\n"
        else
            printf "${YELLOW}⚠ iptables 8388规则: 未明确配置${RESET}\n"
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