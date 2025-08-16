#!/bin/bash
# 卸载模块

# 卸载服务
uninstall_xray() {
    info "开始卸载 Xray Reality..."
    
    printf "${RED}警告: 此操作将完全删除 Xray 和相关配置！${RESET}\n"
    printf "确认卸载吗？ (yes/no): "
    read -r confirm
    
    if [ "$confirm" != "yes" ]; then
        info "取消卸载"
        return 0
    fi
    
    # 再次确认
    printf "${RED}最后确认: 输入 'DELETE' 来确认删除: ${RESET}"
    read -r final_confirm
    
    if [ "$final_confirm" != "DELETE" ]; then
        info "取消卸载"
        return 0
    fi
    
    # 停止服务
    info "停止 Xray 和 Nginx 服务..."
    systemctl stop xray 2>/dev/null
    systemctl stop nginx 2>/dev/null
    systemctl disable xray 2>/dev/null
    systemctl disable nginx 2>/dev/null
    
    # 创建最终备份
    info "创建卸载前备份..."
    FINAL_BACKUP="/root/xray_final_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    tar -czf "$FINAL_BACKUP" \
        /usr/local/etc/xray/ \
        /root/client_config.txt \
        /root/qrcode.txt \
        /root/xray-deploy/ \
        /var/www/html/ \
        /var/log/xray/ \
        2>/dev/null
    
    if [ -f "$FINAL_BACKUP" ]; then
        success "最终备份已保存: $FINAL_BACKUP"
    fi
    
    # 卸载 Xray
    info "卸载 Xray..."
    if command -v xray &>/dev/null; then
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
    else
        warning "Xray 未安装或已被删除"
    fi
    
    # 删除配置文件
    info "删除配置文件..."
    rm -rf /usr/local/etc/xray/
    rm -rf /var/log/xray/
    rm -f /root/client_config.txt
    rm -f /root/qrcode.txt
    
    # 选择是否卸载 Nginx
    printf "是否也卸载 Nginx？ (y/n): "
    read -r remove_nginx
    
    if [ "$remove_nginx" = "y" ] || [ "$remove_nginx" = "Y" ]; then
        info "卸载 Nginx..."
        apt remove --purge -y nginx nginx-common 2>/dev/null
        apt autoremove -y 2>/dev/null
        rm -rf /etc/nginx/
        rm -rf /var/www/html/
    else
        info "保留 Nginx"
    fi
    
    # 选择是否删除部署脚本
    printf "是否删除部署脚本？ (y/n): "
    read -r remove_scripts
    
    if [ "$remove_scripts" = "y" ] || [ "$remove_scripts" = "Y" ]; then
        info "删除部署脚本..."
        rm -rf /root/xray-deploy/
    else
        info "保留部署脚本"
    fi
    
    # 清理防火墙规则（可选）
    printf "是否清理防火墙规则（端口443）？ (y/n): "
    read -r clean_firewall
    
    if [ "$clean_firewall" = "y" ] || [ "$clean_firewall" = "Y" ]; then
        info "清理防火墙规则..."
        
        # 清理 UFW 规则
        if command -v ufw &>/dev/null; then
            ufw delete allow 443 2>/dev/null
            info "已删除 UFW 443端口规则"
        fi
        
        # 注意：不自动清理 iptables 规则，因为可能影响其他服务
        warning "请手动检查并清理 iptables 规则（如需要）"
    fi
    
    # 清理定时任务
    info "清理定时任务..."
    rm -f /etc/cron.d/xray* 2>/dev/null
    
    # 重新加载 systemd
    systemctl daemon-reload
    
    success "Xray Reality 卸载完成！"
    
    printf "\n${GREEN}=== 卸载总结 ===${RESET}\n"
    printf "✓ Xray 服务已卸载\n"
    printf "✓ 配置文件已删除\n"
    printf "✓ 日志文件已清理\n"
    
    if [ "$remove_nginx" = "y" ] || [ "$remove_nginx" = "Y" ]; then
        printf "✓ Nginx 已卸载\n"
    else
        printf "- Nginx 已保留\n"
    fi
    
    if [ "$remove_scripts" = "y" ] || [ "$remove_scripts" = "Y" ]; then
        printf "✓ 部署脚本已删除\n"
    else
        printf "- 部署脚本已保留\n"
    fi
    
    printf "\n${BLUE}最终备份文件: $FINAL_BACKUP${RESET}\n"
    printf "${YELLOW}如需恢复，请保留此备份文件${RESET}\n"
}

# 主卸载函数
uninstall_main() {
    uninstall_xray
}