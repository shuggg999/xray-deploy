#!/bin/bash
# Docker配置模块

# 配置Docker使用Shadowsocks代理
configure_docker_proxy() {
    info "配置Docker使用Shadowsocks代理..."
    
    # 获取服务器IP
    SERVER_IP=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me || echo "127.0.0.1")
    
    # 读取Shadowsocks密码
    if [ -f "/usr/local/etc/xray/ss_password.txt" ]; then
        SS_PASSWORD=$(cat /usr/local/etc/xray/ss_password.txt)
    else
        error "未找到Shadowsocks密码文件"
        return 1
    fi
    
    printf "\n${GREEN}=== Docker代理配置指南 ===${RESET}\n"
    
    printf "\n${BLUE}1. Docker Daemon代理配置${RESET}\n"
    printf "创建或编辑 /etc/systemd/system/docker.service.d/proxy.conf：\n\n"
    
    cat << EOF
[Service]
Environment="HTTP_PROXY=socks5://${SERVER_IP}:8388"
Environment="HTTPS_PROXY=socks5://${SERVER_IP}:8388"
Environment="NO_PROXY=localhost,127.0.0.1,docker-registry.somecorporation.com"
EOF
    
    printf "\n然后重启Docker服务：\n"
    printf "sudo systemctl daemon-reload\n"
    printf "sudo systemctl restart docker\n"
    
    printf "\n${BLUE}2. Docker容器运行时代理配置${RESET}\n"
    printf "运行容器时添加代理环境变量：\n\n"
    
    printf "docker run -e HTTP_PROXY=socks5://${SERVER_IP}:8388 \\\\\n"
    printf "           -e HTTPS_PROXY=socks5://${SERVER_IP}:8388 \\\\\n"
    printf "           -e NO_PROXY=localhost,127.0.0.1 \\\\\n"
    printf "           your_image\n"
    
    printf "\n${BLUE}3. Docker Compose代理配置${RESET}\n"
    printf "在docker-compose.yml中添加：\n\n"
    
    cat << EOF
services:
  your_service:
    environment:
      - HTTP_PROXY=socks5://${SERVER_IP}:8388
      - HTTPS_PROXY=socks5://${SERVER_IP}:8388
      - NO_PROXY=localhost,127.0.0.1
EOF
    
    printf "\n${BLUE}4. Docker Build代理配置${RESET}\n"
    printf "构建镜像时使用代理：\n\n"
    
    printf "docker build --build-arg HTTP_PROXY=socks5://${SERVER_IP}:8388 \\\\\n"
    printf "             --build-arg HTTPS_PROXY=socks5://${SERVER_IP}:8388 \\\\\n"
    printf "             -t your_image .\n"
    
    printf "\n${BLUE}5. Shadowsocks连接信息${RESET}\n"
    printf "服务器地址: ${SERVER_IP}\n"
    printf "端口: 8388\n"
    printf "密码: ${SS_PASSWORD}\n"
    printf "加密方法: 2022-blake3-aes-128-gcm\n"
    
    if [ -f "/root/ss_config.txt" ]; then
        printf "\nShadowsocks链接:\n"
        cat /root/ss_config.txt
    fi
    
    printf "\n${GREEN}提示：${RESET}\n"
    printf "- 如果Docker运行在同一台服务器上，可以使用 127.0.0.1:8388\n"
    printf "- 如果Docker运行在其他机器，确保8388端口可访问\n"
    printf "- 某些应用可能需要SOCKS5代理而非HTTP代理\n"
}

# 生成Docker代理脚本
generate_docker_script() {
    info "生成Docker代理配置脚本..."
    
    # 获取服务器IP
    SERVER_IP=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me || echo "127.0.0.1")
    
    # 创建Docker代理配置脚本
    cat > /root/setup_docker_proxy.sh << 'EOF'
#!/bin/bash
# Docker Shadowsocks代理配置脚本

SERVER_IP="{{SERVER_IP}}"
SS_PORT="8388"

echo "配置Docker使用Shadowsocks代理..."

# 创建Docker代理配置目录
sudo mkdir -p /etc/systemd/system/docker.service.d

# 创建代理配置文件
sudo tee /etc/systemd/system/docker.service.d/proxy.conf > /dev/null <<EOL
[Service]
Environment="HTTP_PROXY=socks5://${SERVER_IP}:${SS_PORT}"
Environment="HTTPS_PROXY=socks5://${SERVER_IP}:${SS_PORT}"
Environment="NO_PROXY=localhost,127.0.0.1,::1"
EOL

# 重启Docker服务
sudo systemctl daemon-reload
sudo systemctl restart docker

echo "Docker代理配置完成！"
echo "服务器地址: ${SERVER_IP}:${SS_PORT}"

# 测试代理
echo "测试代理连接..."
if docker run --rm alpine sh -c 'apk add --no-cache curl && curl -I https://www.google.com' > /dev/null 2>&1; then
    echo "代理配置成功！"
else
    echo "代理连接测试失败，请检查配置"
fi
EOF
    
    # 替换服务器IP
    sed -i "s/{{SERVER_IP}}/$SERVER_IP/g" /root/setup_docker_proxy.sh
    chmod +x /root/setup_docker_proxy.sh
    
    success "Docker代理脚本已生成: /root/setup_docker_proxy.sh"
    printf "运行脚本配置Docker代理: bash /root/setup_docker_proxy.sh\n"
}

# 主Docker配置函数
docker_main() {
    printf "选择操作:\n"
    printf "1. 显示Docker代理配置指南\n"
    printf "2. 生成Docker代理配置脚本\n"
    printf "请选择 [1-2]: "
    read -r docker_choice
    
    case $docker_choice in
        1)
            configure_docker_proxy
            ;;
        2)
            generate_docker_script
            ;;
        *)
            warning "无效选择"
            ;;
    esac
}