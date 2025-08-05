# Hysteria2 Cloud Deployment

为 Fanjuanjuan7 的阿里云服务器设计的 Hysteria2 一键部署脚本。

## 功能

*   ✅ 一键安装 Hysteria2 Core
*   ✅ 自动申请 Let's Encrypt 免费 SSL 证书
*   ✅ 配置 `salamander` 混淆
*   ✅ 配置 systemd 服务，支持开机自启
*   ✅ 自动配置 UFW 防火墙
*   ✅ 设置证书自动续期 (每周一凌晨3点)

## 使用方法

在你的每台服务器上运行以下命令：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Fanjuanjuan7/hysteria2-cloud/main/install.sh)
```

> ⚠️ **重要**: 运行前请确保域名DNS解析已正确指向服务器IP。

## 配置说明

脚本中的关键配置位于文件顶部：

*   `MAIN_DOMAIN`: 你的主域名 (例如 `fanjuanjuan.uno`)
*   `OBFS_PASSWORD`: Hysteria2 连接时需要的混淆密码
*   `NODE_MAP`: 服务器公网IP与子域名的对应关系
