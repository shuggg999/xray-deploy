#!/bin/bash
# 备份模块

# 备份配置
backup_config() {
    info "开始备份当前配置..."
    
    # 创建备份目录
    BACKUP_DIR="/root/xray_backups"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    CURRENT_BACKUP="$BACKUP_DIR/backup_$TIMESTAMP"
    
    mkdir -p "$CURRENT_BACKUP"/{config,scripts,logs,web}
    
    # 备份 Xray 配置
    if [ -d "/usr/local/etc/xray" ]; then
        cp -r /usr/local/etc/xray/* "$CURRENT_BACKUP/config/" 2>/dev/null
        success "Xray 配置已备份"
    else
        warning "Xray 配置目录不存在"
    fi
    
    # 备份脚本
    cp -r /root/xray-deploy/* "$CURRENT_BACKUP/scripts/" 2>/dev/null
    
    # 备份客户端连接信息
    if [ -f "/root/client_config.txt" ]; then
        cp /root/client_config.txt "$CURRENT_BACKUP/"
        cp /root/qrcode.txt "$CURRENT_BACKUP/" 2>/dev/null
    fi
    
    # 备份网站文件
    if [ -d "/var/www/html" ]; then
        cp -r /var/www/html/* "$CURRENT_BACKUP/web/" 2>/dev/null
    fi
    
    # 备份日志
    if [ -f "/var/log/xray_deploy.log" ]; then
        cp /var/log/xray_deploy.log "$CURRENT_BACKUP/logs/"
    fi
    
    # 备份系统信息
    systemctl status xray > "$CURRENT_BACKUP/logs/xray_status.txt" 2>/dev/null
    systemctl status nginx > "$CURRENT_BACKUP/logs/nginx_status.txt" 2>/dev/null
    
    # 生成备份信息文件
    cat > "$CURRENT_BACKUP/backup_info.txt" <<EOF
备份时间: $(date)
服务器IP: $(curl -s https://api.ipify.org 2>/dev/null || echo "未知")
Xray版本: $(xray version 2>/dev/null | head -1)
系统信息: $(uname -a)
备份内容:
- Xray配置文件
- 部署脚本
- 客户端连接信息
- 网站文件
- 日志文件
- 服务状态
EOF
    
    # 创建压缩包
    cd "$BACKUP_DIR"
    tar -czf "backup_$TIMESTAMP.tar.gz" "backup_$TIMESTAMP/"
    
    if [ $? -eq 0 ]; then
        rm -rf "backup_$TIMESTAMP/"
        success "备份完成: $BACKUP_DIR/backup_$TIMESTAMP.tar.gz"
        
        # 显示备份信息
        printf "\n${GREEN}=== 备份信息 ===${RESET}\n"
        printf "备份文件: backup_$TIMESTAMP.tar.gz\n"
        printf "备份大小: $(du -h $BACKUP_DIR/backup_$TIMESTAMP.tar.gz | cut -f1)\n"
        printf "保存位置: $BACKUP_DIR/\n"
        
        # 清理旧备份（保留最近5个）
        cleanup_old_backups
    else
        error "备份失败"
        rm -rf "backup_$TIMESTAMP/" 2>/dev/null
        return 1
    fi
}

# 清理旧备份
cleanup_old_backups() {
    info "清理旧备份文件..."
    
    cd "$BACKUP_DIR" 2>/dev/null || return
    
    # 保留最近5个备份文件
    ls -t backup_*.tar.gz 2>/dev/null | tail -n +6 | while read old_backup; do
        rm -f "$old_backup"
        info "已删除旧备份: $old_backup"
    done
}

# 列出备份文件
list_backups() {
    info "列出可用的备份文件..."
    
    BACKUP_DIR="/root/xray_backups"
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR/backup_*.tar.gz 2>/dev/null)" ]; then
        warning "没有找到备份文件"
        return 1
    fi
    
    printf "\n${GREEN}=== 可用备份文件 ===${RESET}\n"
    
    local i=1
    ls -t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | while read backup_file; do
        backup_name=$(basename "$backup_file")
        backup_size=$(du -h "$backup_file" | cut -f1)
        backup_time=$(echo "$backup_name" | sed 's/backup_\([0-9]\{8\}_[0-9]\{6\}\).tar.gz/\1/' | sed 's/_/ /')
        
        printf "%d. %s (%s) - %s\n" "$i" "$backup_name" "$backup_size" "$backup_time"
        i=$((i+1))
    done
}

# 主备份函数
backup_main() {
    backup_config
}