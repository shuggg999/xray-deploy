#!/bin/bash
# 恢复模块

# 恢复配置
restore_config() {
    info "开始恢复配置..."
    
    BACKUP_DIR="/root/xray_backups"
    
    # 列出可用备份
    if ! list_backups; then
        return 1
    fi
    
    # 选择备份文件
    printf "\n请选择要恢复的备份文件编号: "
    read -r choice
    
    if [ -z "$choice" ] || ! echo "$choice" | grep -q '^[0-9]\+$'; then
        error "无效的选择"
        return 1
    fi
    
    # 获取选中的备份文件
    selected_backup=$(ls -t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | sed -n "${choice}p")
    
    if [ -z "$selected_backup" ]; then
        error "备份文件不存在"
        return 1
    fi
    
    printf "选择的备份文件: $(basename $selected_backup)\n"
    printf "确认恢复吗？这将覆盖当前配置 (y/n): "
    read -r confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        info "取消恢复"
        return 0
    fi
    
    # 停止服务
    info "停止当前服务..."
    systemctl stop xray 2>/dev/null
    systemctl stop nginx 2>/dev/null
    
    # 解压备份文件
    TEMP_DIR="/tmp/xray_restore_$$"
    mkdir -p "$TEMP_DIR"
    
    cd "$TEMP_DIR"
    if tar -xzf "$selected_backup"; then
        success "备份文件解压成功"
    else
        error "备份文件解压失败"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # 恢复配置文件
    RESTORE_DIR=$(ls -d backup_*/ 2>/dev/null | head -1)
    if [ -z "$RESTORE_DIR" ]; then
        error "备份文件格式错误"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # 恢复 Xray 配置
    if [ -d "$RESTORE_DIR/config" ]; then
        mkdir -p /usr/local/etc/xray
        cp -r "$RESTORE_DIR/config"/* /usr/local/etc/xray/ 2>/dev/null
        success "Xray 配置已恢复"
    fi
    
    # 恢复客户端配置
    if [ -f "$RESTORE_DIR/client_config.txt" ]; then
        cp "$RESTORE_DIR/client_config.txt" /root/
        cp "$RESTORE_DIR/qrcode.txt" /root/ 2>/dev/null
        success "客户端配置已恢复"
    fi
    
    # 恢复网站文件
    if [ -d "$RESTORE_DIR/web" ]; then
        mkdir -p /var/www/html
        cp -r "$RESTORE_DIR/web"/* /var/www/html/ 2>/dev/null
        success "网站文件已恢复"
    fi
    
    # 恢复脚本（可选）
    printf "是否恢复部署脚本？(y/n): "
    read -r restore_scripts
    if [ "$restore_scripts" = "y" ] || [ "$restore_scripts" = "Y" ]; then
        if [ -d "$RESTORE_DIR/scripts" ]; then
            cp -r "$RESTORE_DIR/scripts"/* /root/xray-deploy/ 2>/dev/null
            chmod +x /root/xray-deploy/deploy.sh
            chmod +x /root/xray-deploy/modules/*.sh 2>/dev/null
            success "部署脚本已恢复"
        fi
    fi
    
    # 清理临时文件
    rm -rf "$TEMP_DIR"
    
    # 启动服务
    info "启动服务..."
    systemctl start xray
    systemctl start nginx
    
    # 检查服务状态
    sleep 2
    if systemctl is-active --quiet xray; then
        success "Xray 服务启动成功"
    else
        error "Xray 服务启动失败"
    fi
    
    if systemctl is-active --quiet nginx; then
        success "Nginx 服务启动成功"
    else
        warning "Nginx 服务启动失败"
    fi
    
    success "配置恢复完成！"
    
    # 显示恢复后的信息
    if [ -f "/root/client_config.txt" ]; then
        printf "\n${GREEN}=== 恢复的客户端连接 ===${RESET}\n"
        cat /root/client_config.txt
    fi
}

# 主恢复函数
restore_main() {
    restore_config
}