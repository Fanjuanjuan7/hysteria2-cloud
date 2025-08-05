#!/bin/bash

set -e

echo "🚀 开始部署 Hysteria2 节点..."

# --- 配置区 (请根据你的实际情况修改) ---
MAIN_DOMAIN="fanjuanjuan.uno"
OBFS_PASSWORD="AutoGenPassword2025!"

declare -A NODE_MAP
NODE_MAP["47.250.188.56"]="my1"
NODE_MAP["47.250.196.213"]="my2"
NODE_MAP["47.250.118.183"]="my3"
NODE_MAP["47.250.47.126"]="my4"
NODE_MAP["47.250.112.149"]="my5"
NODE_MAP["47.250.196.35"]="my6"
NODE_MAP["47.254.238.236"]="my7"
NODE_MAP["47.250.37.253"]="my8"
NODE_MAP["47.250.10.103"]="my9"
NODE_MAP["47.254.232.177"]="my10"
NODE_MAP["47.254.230.29"]="my11"
NODE_MAP["8.213.207.96"]="th1"
NODE_MAP["47.87.66.115"]="th2"
NODE_MAP["8.213.193.15"]="th5"
NODE_MAP["8.213.199.81"]="th6"
NODE_MAP["8.213.226.92"]="th7"
NODE_MAP["47.81.9.144"]="th8"
NODE_MAP["8.213.194.226"]="th9"
NODE_MAP["8.213.232.126"]="th10"
# --- 配置结束 ---

echo "🌐 获取本机公网IP..."
IP=$(curl -s --max-time 10 https://icanhazip.com || curl -s --max-time 10 https://ifconfig.me/ip)
if [ -z "$IP" ]; then
    echo "❌ 错误：无法获取公网IP"
    exit 1
fi
echo "✅ 本机IP: $IP"

SUBDOMAIN=""
for node_ip in "${!NODE_MAP[@]}"; do
    if [ "$node_ip" == "$IP" ]; then
        SUBDOMAIN="${NODE_MAP[$node_ip]}"
        break
    fi
done

if [ -z "$SUBDOMAIN" ]; then
    echo "❌ 错误：IP $IP 未在配置列表中找到"
    exit 1
fi

DOMAIN="$SUBDOMAIN.$MAIN_DOMAIN"
echo "🎯 节点域名: $DOMAIN"

echo "🔧 更新系统并安装软件..."
sudo apt update > /dev/null 2>&1
sudo apt install curl wget sudo ufw certbot -y > /dev/null 2>&1

echo "⬇️ 安装 Hysteria2..."
curl -fsSL https://get.hy2.sh/ | sh > /dev/null 2>&1

echo "🔐 申请SSL证书..."
sudo systemctl stop nginx > /dev/null 2>&1 || true
sudo certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos -m "admin@$MAIN_DOMAIN" --keep-until-expiring > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ 证书申请失败"
    exit 1
fi
echo "✅ SSL证书申请成功!"

echo "⚙️ 生成配置文件..."
sudo mkdir -p /etc/hysteria
sudo tee /etc/hysteria/config.yaml > /dev/null <<CONFIG_EOF
listen: :443

tls:
  cert: /etc/letsencrypt/live/$DOMAIN/fullchain.pem
  key: /etc/letsencrypt/live/$DOMAIN/privkey.pem
  alpn: h3

obfs:
  type: salamander
  password: "$OBFS_PASSWORD"

bandwidth:
  up: "100 mbps"
  down: "100 mbps"

log-level: info
CONFIG_EOF

echo "🔄 设置系统服务..."
sudo tee /etc/systemd/system/hysteria-server.service > /dev/null <<SERVICE_EOF
[Unit]
Description=Hysteria Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
SERVICE_EOF

sudo systemctl daemon-reexec
sudo systemctl enable hysteria-server > /dev/null 2>&1
sudo systemctl start hysteria-server

echo "🛡️ 配置防火墙..."
sudo ufw allow ssh > /dev/null 2>&1 || true
sudo ufw allow 443/tcp > /dev/null 2>&1 || true
sudo ufw allow 443/udp > /dev/null 2>&1 || true
echo "y" | sudo ufw enable > /dev/null 2>&1 || true

echo "🔁 设置证书自动续期..."
(crontab -l 2>/dev/null | grep -v "certbot renew"; echo "0 3 * * 1 /usr/bin/certbot renew --quiet && sudo systemctl restart hysteria-server") | crontab -

echo ""
echo "🎉 Hysteria2 部署完成！"
echo "----------------------------------------"
echo "🖥️  节点地址: $DOMAIN"
echo "🔌 节点端口: 443"
echo "🔑 混淆密码: $OBFS_PASSWORD"
echo "📡 协议: Hysteria2"
echo "🔒 TLS: 开启"
echo "🔄 证书续期: 已设置 (每周一凌晨3点)"
echo "----------------------------------------"
