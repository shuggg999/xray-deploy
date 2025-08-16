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
    
    success "密钥生成完成"
    echo "UUID: $UUID"
    echo "Private Key: $PRIVATE_KEY"
    echo "Public Key: $PUBLIC_KEY"
}

# 配置 Xray
configure_xray() {
    info "配置 Xray Reality..."
    
    # 读取生成的密钥
    UUID=$(cat /usr/local/etc/xray/uuid.txt)
    PRIVATE_KEY=$(cat /usr/local/etc/xray/key.txt)
    
    # 随机生成 shortId
    SHORT_ID=$(openssl rand -hex 4)
    
    # 创建配置文件
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
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF
    
    success "Xray 配置完成"
}

# 启动服务
start_services() {
    info "启动 Xray 服务..."
    
    systemctl enable xray
    systemctl start xray
    systemctl enable nginx
    systemctl start nginx
    
    if systemctl is-active --quiet xray; then
        success "Xray 服务启动成功"
    else
        error "Xray 服务启动失败"
        exit 1
    fi
}

# 生成客户端连接
generate_client_config() {
    info "生成客户端连接信息..."
    
    # 获取服务器IP
    SERVER_IP=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me || echo "YOUR_SERVER_IP")
    
    # 读取配置信息
    UUID=$(cat /usr/local/etc/xray/uuid.txt)
    PRIVATE_KEY=$(cat /usr/local/etc/xray/key.txt)
    
    # 从配置文件中获取 public key 和 short id
    PUBLIC_KEY=$(xray x25519 -i "$PRIVATE_KEY" | grep "Public key:" | awk '{print $3}')
    SHORT_ID=$(grep -A 3 "shortIds" /usr/local/etc/xray/config.json | grep -E '"[a-zA-Z0-9]+"' | grep -v "shortIds" | tr -d ' "' | head -1)
    
    # 生成 VLESS 连接 (按v2rayN标准格式)
    VLESS_LINK="vless://${UUID}@${SERVER_IP}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.amazon.com&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#Xray-Reality"
    
    # 生成Base64版本
    VLESS_BASE64=$(echo "$VLESS_LINK" | base64 -w 0)
    
    # 保存连接信息
    mkdir -p /var/www/html
    echo "$VLESS_LINK" > /var/www/html/client_config.txt
    echo "$VLESS_LINK" > /root/client_config.txt
    echo "$VLESS_BASE64" > /var/www/html/client_config_base64.txt
    echo "$VLESS_BASE64" > /root/client_config_base64.txt
    
    # 生成二维码
    if command -v qrencode &> /dev/null; then
        qrencode -t PNG -o /var/www/html/qrcode.png "$VLESS_LINK"
        qrencode -t UTF8 "$VLESS_LINK" > /root/qrcode.txt
        qrencode -t PNG -o /var/www/html/qrcode_base64.png "$VLESS_BASE64"
        qrencode -t UTF8 "$VLESS_BASE64" > /root/qrcode_base64.txt
    fi
    
    success "客户端连接信息已生成"
    printf "\n${GREEN}=== 客户端连接信息 ===${RESET}\n"
    printf "服务器IP: ${BLUE}%s${RESET}\n" "$SERVER_IP"
    printf "UUID: ${BLUE}%s${RESET}\n" "$UUID"
    printf "Public Key: ${BLUE}%s${RESET}\n" "$PUBLIC_KEY"
    printf "Short ID: ${BLUE}%s${RESET}\n" "$SHORT_ID"
    
    printf "\n${GREEN}VLESS连接（明文）：${RESET}\n"
    printf "%s\n" "$VLESS_LINK"
    
    printf "\n${GREEN}VLESS连接（Base64，推荐v2rayN使用）：${RESET}\n"
    printf "%s\n" "$VLESS_BASE64"
    
    printf "\n${GREEN}文件保存位置：${RESET}\n"
    printf "%s /root/client_config.txt\n" "- 明文链接:"
    printf "%s /root/client_config_base64.txt\n" "- Base64链接:"
    printf "%s /root/qrcode.txt\n" "- 明文二维码:"
    printf "%s /root/qrcode_base64.txt\n" "- Base64二维码:"
}

# 主安装函数
install_main() {
    install_dependencies
    install_xray
    generate_keys
    configure_xray
    start_services
    generate_client_config
    
    success "Xray Reality 安装完成！"
}