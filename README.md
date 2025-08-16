# Xray Reality 一键部署脚本

基于原始servermaster精简的 Xray Reality 专用部署工具，专注于科学上网部署和管理。

## ✨ 功能特性

- 🚀 **一键安装** Xray Reality (VLESS + Reality协议)
- 💾 **配置备份和恢复** - 支持多版本备份管理
- 🔄 **自动更新支持** - 保持最新版本
- 📊 **服务状态监控** - 实时查看运行状态
- 🗑️ **完整卸载功能** - 清理所有相关文件
- 📱 **Base64链接生成** - 完美兼容v2rayN等客户端
- 🔒 **Reality协议** - 最新的抗封锁技术

## 🚀 快速开始

### 新服务器一键安装
```bash
curl -sSL https://raw.githubusercontent.com/shuggg999/xray-deploy/main/install.sh | bash
```

### 手动安装
```bash
git clone https://github.com/shuggg999/xray-deploy.git
cd xray-deploy
./install.sh
```

## 📋 功能菜单

1. **全新安装 Xray Reality** - 自动安装所有依赖和配置
2. **从备份恢复配置** - 从之前的备份恢复配置
3. **备份当前配置** - 创建当前配置的完整备份
4. **查看服务状态** - 检查服务运行状态和配置
5. **生成客户端连接** - 生成VLESS链接和Base64格式
6. **卸载服务** - 完全移除Xray和相关配置

## 📱 客户端支持

### v2rayN (Windows/macOS)
**推荐使用Base64格式链接**，脚本会自动生成：
- 明文链接（用于手动配置）
- **Base64链接（推荐，一键导入）**

### 其他客户端
- **Nekoray** (跨平台) - 支持明文链接直接导入
- **Clash Verge** - 支持订阅格式
- **v2rayA** - Web界面，兼容性好

## 🔧 配置说明

### Reality 协议参数
- **端口**: 443
- **协议**: VLESS + Reality
- **流控**: xtls-rprx-vision
- **伪装域名**: www.amazon.com
- **指纹**: chrome

### 文件位置
```
/usr/local/etc/xray/config.json    # Xray配置文件
/root/client_config.txt             # 明文客户端链接
/root/client_config_base64.txt      # Base64客户端链接
/root/xray_backups/                 # 备份文件目录
```

## 🗂️ 项目结构

```
xray-deploy/
├── deploy.sh                 # 主部署脚本
├── modules/                  # 功能模块
│   ├── install.sh           # 安装模块
│   ├── backup.sh            # 备份模块
│   ├── restore.sh           # 恢复模块
│   ├── status.sh            # 状态检查模块
│   └── uninstall.sh         # 卸载模块
├── templates/               # 配置模板
│   └── config.template.json # Xray配置模板
└── README.md               # 使用说明
```

## 💡 使用技巧

### 1. 快速生成新配置
如果需要更换UUID和密钥：
```bash
./deploy.sh
# 选择 "1. 全新安装" 会自动生成新的配置
```

### 2. v2rayN导入问题
如果明文链接导入失败，使用Base64格式：
```bash
./deploy.sh
# 选择 "5. 生成客户端连接"
# 复制Base64链接到v2rayN
```

### 3. 备份管理
定期备份配置，支持多版本管理：
```bash
./deploy.sh
# 选择 "3. 备份当前配置"
# 备份文件自动保存到 /root/xray_backups/
```

## 🔍 故障排除

### 服务无法启动
```bash
./deploy.sh
# 选择 "4. 查看服务状态" 查看详细信息
```

### 端口443被占用
检查其他服务是否占用443端口：
```bash
netstat -tlnp | grep 443
```

### 连接失败
1. 检查防火墙设置
2. 确认端口443开放
3. 验证客户端配置是否完整

## 🌐 支持的系统

- Ubuntu 18.04+
- Debian 9+
- CentOS 7+

## ⚠️ 注意事项

1. **需要root权限运行**
2. **确保端口443未被占用**
3. **建议使用VPS服务器**
4. **定期备份配置文件**
5. **Base64链接对v2rayN兼容性更好**

## 🤝 贡献

欢迎提交Issue和Pull Request！

## 📄 许可证

MIT License

## 🙏 致谢

- 基于 [Xray-core](https://github.com/XTLS/Xray-core) 项目
- 参考 [servermaster](https://github.com/shuggg999/servermaster) 部分逻辑
- 感谢所有贡献者

---

**⭐ 如果这个项目对你有帮助，请给个Star！**