#!/bin/bash
# 安装模块 - 基于 servermaster 的安装逻辑

# 安装依赖
install_dependencies() {
    info "开始安装所需依赖..."
    
    # 检测操作系统
    if [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu
        apt update -q
        apt install -y curl wget unzip jq cron nginx qrencode xxd openssl
    elif [[ -f /etc/redhat_release ]]; then
        # CentOS/RHEL
        yum install -y epel-release
        yum install -y curl wget unzip jq cronie nginx qrencode openssl vim-common
    else
        error "不支持的操作系统！"
        exit 1
    fi
    
    success "依赖安装完成"
}

# 安装 Xray
install_xray() {
    info "开始安装 Xray..."
    
    # 下载官方安装脚本并执行
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    
    # 检查是否安装成功
    if ! command -v xray &> /dev/null; then
        error "Xray 安装失败！"
        exit 1
    fi
    
    success "Xray 安装完成"
}

# 生成 UUID 和密钥
generate_keys() {
    info "生成 UUID 和密钥..."
    
    # 生成 UUID
    UUID=$(xray uuid)
    echo "$UUID" > /usr/local/etc/xray/uuid.txt
    
    # 生成 Reality 密钥对
    KEY_PAIR=$(xray x25519)
    PRIVATE_KEY=$(echo "$KEY_PAIR" | grep "Private key:" | awk '{print $3}')
    PUBLIC_KEY=$(echo "$KEY_PAIR" | grep "Public key:" | awk '{print $3}')
    
    echo "$PRIVATE_KEY" > /usr/local/etc/xray/key.txt
    
    # 生成 Shadowsocks 密码
    SS_PASSWORD=$(openssl rand -base64 16)
    echo "$SS_PASSWORD" > /usr/local/etc/xray/ss_password.txt
    
    success "密钥生成完成"
    echo "UUID: $UUID"
    echo "Private Key: $PRIVATE_KEY"
    echo "Public Key: $PUBLIC_KEY"
    echo "Shadowsocks Password: $SS_PASSWORD"
}

# 配置 Xray
configure_xray() {
    info "配置 Xray 双协议..."
    
    # 读取生成的密钥
    UUID=$(cat /usr/local/etc/xray/uuid.txt)
    PRIVATE_KEY=$(cat /usr/local/etc/xray/key.txt)
    SS_PASSWORD=$(cat /usr/local/etc/xray/ss_password.txt)
    
    # 随机生成 shortId
    SHORT_ID=$(openssl rand -hex 4)
    
    # 使用模板创建配置文件
    TEMPLATE_FILE="$SCRIPT_DIR/templates/config.template.json"
    
    if [[ -f "$TEMPLATE_FILE" ]]; then
        # 使用模板文件并替换变量
        sed -e "s/{{UUID}}/$UUID/g" \
            -e "s/{{PRIVATE_KEY}}/$PRIVATE_KEY/g" \
            -e "s/{{SHORT_ID}}/$SHORT_ID/g" \
            -e "s/{{SS_PASSWORD}}/$SS_PASSWORD/g" \
            "$TEMPLATE_FILE" > "$XRAY_CONF"
    else
        # 备用：直接创建配置文件
        cat > "$XRAY_CONF" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": 80,
            "xver": 1
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "www.amazon.com:443",
          "serverNames": [
            "www.amazon.com"
          ],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [
            "$SHORT_ID"
          ]
        }
      }
    },
    {
      "listen": "0.0.0.0",
      "port": 8388,
      "protocol": "shadowsocks",
      "settings": {
        "method": "2022-blake3-aes-128-gcm",
        "password": "$SS_PASSWORD"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF
    fi
    
    success "Xray 双协议配置完成"
}

# 配置防火墙
configure_firewall() {
    info "配置防火墙规则..."
    
    # 配置 UFW
    if command -v ufw &>/dev/null; then
        # 开放端口
        ufw allow 22/tcp comment 'SSH' &>/dev/null
        ufw allow 80/tcp comment 'HTTP' &>/dev/null
        ufw allow 443/tcp comment 'HTTPS/Reality' &>/dev/null
        ufw allow 8388/tcp comment 'Shadowsocks' &>/dev/null
        
        # 启用 UFW
        echo "y" | ufw enable &>/dev/null
        
        success "UFW 防火墙配置完成"
    fi
    
    # 配置 iptables（如果 UFW 不可用）
    if ! command -v ufw &>/dev/null && command -v iptables &>/dev/null; then
        # 允许已建立的连接
        iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT &>/dev/null
        
        # 允许本地回环
        iptables -A INPUT -i lo -j ACCEPT &>/dev/null
        
        # 允许 SSH
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT &>/dev/null
        
        # 允许 HTTP
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT &>/dev/null
        
        # 允许 HTTPS/Reality
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT &>/dev/null
        
        # 允许 Shadowsocks
        iptables -A INPUT -p tcp --dport 8388 -j ACCEPT &>/dev/null
        
        # 保存规则（Debian/Ubuntu）
        if command -v iptables-save &>/dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        fi
        
        success "iptables 防火墙配置完成"
    fi
}

# 启动服务
start_services() {
    info "启动 Xray 服务..."
    
    # 检查服务是否已经存在
    if systemctl is-active --quiet xray; then
        info "检测到Xray服务正在运行，重启以加载新配置..."
        systemctl restart xray
    else
        info "启动新的Xray服务..."
        systemctl enable xray
        systemctl start xray
    fi
    
    # 确保nginx服务运行
    systemctl enable nginx
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
    else
        systemctl start nginx
    fi
    
    # 验证服务状态
    sleep 2
    if systemctl is-active --quiet xray; then
        success "Xray 服务启动成功"
        info "监听端口: 443 (Reality+VLESS), 8388 (Shadowsocks)"
    else
        error "Xray 服务启动失败"
        systemctl status xray --no-pager -l
        exit 1
    fi
}

# 生成客户端连接
generate_client_config() {
    info "生成双协议客户端连接信息..."
    
    # 获取服务器IP
    SERVER_IP=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me || echo "YOUR_SERVER_IP")
    
    # 读取配置信息
    UUID=$(cat /usr/local/etc/xray/uuid.txt)
    PRIVATE_KEY=$(cat /usr/local/etc/xray/key.txt)
    SS_PASSWORD=$(cat /usr/local/etc/xray/ss_password.txt)
    
    # 从配置文件中获取 public key 和 short id
    PUBLIC_KEY=$(xray x25519 -i "$PRIVATE_KEY" | grep "Public key:" | awk '{print $3}')
    SHORT_ID=$(grep -A 3 "shortIds" /usr/local/etc/xray/config.json | grep -E '"[a-zA-Z0-9]+"' | grep -v "shortIds" | tr -d ' "' | head -1)
    
    # 生成 VLESS Reality 连接 (按v2rayN标准格式)
    VLESS_LINK="vless://${UUID}@${SERVER_IP}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.amazon.com&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#Xray-Reality"
    
    # 生成 Shadowsocks 连接
    SS_LINK="ss://$(echo -n "2022-blake3-aes-128-gcm:${SS_PASSWORD}" | base64 -w 0)@${SERVER_IP}:8388#Xray-Shadowsocks"
    
    # 生成Base64版本
    VLESS_BASE64=$(echo "$VLESS_LINK" | base64 -w 0)
    SS_BASE64=$(echo "$SS_LINK" | base64 -w 0)
    
    # 保存连接信息
    mkdir -p /var/www/html
    
    # VLESS 连接
    echo "$VLESS_LINK" > /var/www/html/vless_config.txt
    echo "$VLESS_LINK" > /root/vless_config.txt
    echo "$VLESS_BASE64" > /var/www/html/vless_config_base64.txt
    echo "$VLESS_BASE64" > /root/vless_config_base64.txt
    
    # Shadowsocks 连接
    echo "$SS_LINK" > /var/www/html/ss_config.txt
    echo "$SS_LINK" > /root/ss_config.txt
    echo "$SS_BASE64" > /var/www/html/ss_config_base64.txt
    echo "$SS_BASE64" > /root/ss_config_base64.txt
    
    # 兼容旧文件名
    echo "$VLESS_LINK" > /var/www/html/client_config.txt
    echo "$VLESS_LINK" > /root/client_config.txt
    echo "$VLESS_BASE64" > /var/www/html/client_config_base64.txt
    echo "$VLESS_BASE64" > /root/client_config_base64.txt
    
    # 生成二维码
    if command -v qrencode &> /dev/null; then
        # VLESS 二维码
        qrencode -t PNG -o /var/www/html/vless_qrcode.png "$VLESS_LINK"
        qrencode -t UTF8 "$VLESS_LINK" > /root/vless_qrcode.txt
        qrencode -t PNG -o /var/www/html/vless_qrcode_base64.png "$VLESS_BASE64"
        qrencode -t UTF8 "$VLESS_BASE64" > /root/vless_qrcode_base64.txt
        
        # Shadowsocks 二维码
        qrencode -t PNG -o /var/www/html/ss_qrcode.png "$SS_LINK"
        qrencode -t UTF8 "$SS_LINK" > /root/ss_qrcode.txt
        qrencode -t PNG -o /var/www/html/ss_qrcode_base64.png "$SS_BASE64"
        qrencode -t UTF8 "$SS_BASE64" > /root/ss_qrcode_base64.txt
        
        # 兼容旧文件名
        qrencode -t PNG -o /var/www/html/qrcode.png "$VLESS_LINK"
        qrencode -t UTF8 "$VLESS_LINK" > /root/qrcode.txt
        qrencode -t PNG -o /var/www/html/qrcode_base64.png "$VLESS_BASE64"
        qrencode -t UTF8 "$VLESS_BASE64" > /root/qrcode_base64.txt
    fi
    
    success "双协议客户端连接信息已生成"
    printf "\n${GREEN}=== 双协议客户端连接信息 ===${RESET}\n"
    printf "服务器IP: ${BLUE}%s${RESET}\n" "$SERVER_IP"
    printf "UUID: ${BLUE}%s${RESET}\n" "$UUID"
    printf "Public Key: ${BLUE}%s${RESET}\n" "$PUBLIC_KEY"
    printf "Short ID: ${BLUE}%s${RESET}\n" "$SHORT_ID"
    printf "Shadowsocks Password: ${BLUE}%s${RESET}\n" "$SS_PASSWORD"
    
    printf "\n${GREEN}=== VLESS Reality（适用于Mac主机） ===${RESET}\n"
    printf "明文链接：%s\n" "$VLESS_LINK"
    printf "\nBase64链接（推荐v2rayN使用）：%s\n" "$VLESS_BASE64"
    
    printf "\n${GREEN}=== Shadowsocks（适用于Docker容器） ===${RESET}\n"
    printf "明文链接：%s\n" "$SS_LINK"
    printf "\nBase64链接：%s\n" "$SS_BASE64"
    
    printf "\n${GREEN}文件保存位置：${RESET}\n"
    printf "- VLESS明文: /root/vless_config.txt\n"
    printf "- VLESS Base64: /root/vless_config_base64.txt\n"
    printf "- SS明文: /root/ss_config.txt\n"
    printf "- SS Base64: /root/ss_config_base64.txt\n"
    printf "- VLESS二维码: /root/vless_qrcode.txt\n"
    printf "- SS二维码: /root/ss_qrcode.txt\n"
}

# 主安装函数
install_main() {
    install_dependencies
    install_xray
    generate_keys
    configure_xray
    configure_firewall
    start_services
    generate_client_config
    
    success "Xray 双协议安装完成！"
    printf "\n${GREEN}提示：${RESET}\n"
    printf "- Reality+VLESS：适用于Mac主机直连，端口443\n"
    printf "- Shadowsocks：适用于Docker容器，端口8388\n"
    printf "- 防火墙已自动配置开放所需端口\n"
    printf "\n${BLUE}Docker代理配置示例：${RESET}\n"
    printf "HTTP_PROXY=socks5://host.docker.internal:8388\n"
    printf "HTTPS_PROXY=socks5://host.docker.internal:8388\n"
}