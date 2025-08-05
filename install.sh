#!/bin/bash

# ===========================================
# Hysteria2 一键安装脚本 (稳定版)
# 项目: https://github.com/Fanjuanjuan7/hysteria2-cloud
# 作者: Fanjuanjuan7
# 功能: 自动部署 Hysteria2 节点 (适配 Ubuntu 20.04+)
# ===========================================

set -e # 遇到错误立即停止

echo "🚀 开始部署 Hysteria2 节点..."

# --- 基础配置 (请根据你的实际情况修改这里) ---
MAIN_DOMAIN="fanjuanjuan.uno"  # <-- 修改为你的主域名
OBFS_PASSWORD="AutoGenPassword2025!" # <-- 混淆密码，可以修改为你喜欢的

# IP 到子域名的映射表 (请确保与你的DNS解析一致)
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

# 1. 获取本机公网IP
echo "🌐 正在获取本机公网IP..."
IP=$(curl -s --max-time 10 https://icanhazip.com || curl -s --max-time 10 https://ifconfig.me/ip)
if [ -z "$IP" ]; then
    echo "❌ 错误：无法获取公网IP，请检查网络。"
    exit 1
fi
echo "✅ 本机IP是: $IP"

# 2. 根据IP查找对应的子域名
SUBDOMAIN=""
for node_ip in "${!NODE_MAP[@]}"; do
    if [ "$node_ip" == "$IP" ]; then
        SUBDOMAIN="${NODE_MAP[$node_ip]}"
        break
    fi
done

if [ -z "$SUBDOMAIN" ]; then
    echo "❌ 错误：本机IP $IP 没有在配置列表中找到对应的子域名。"
    echo "💡 请检查你的IP地址或 NODE_MAP 配置是否正确。"
    exit 1
fi

DOMAIN="$SUBDOMAIN.$MAIN_DOMAIN"
echo "🎯 找到匹配的节点域名: $DOMAIN"

# 3. 更新系统并安装必要软件
echo "🔧 正在更新系统并安装必要软件..."
sudo apt update > /dev/null 2>&1
sudo apt install curl wget sudo ufw certbot -y > /dev/null 2>&1

# 4. 安装 Hysteria2 (关键：使用 bash 而非 sh)
echo "⬇️ 正在安装 Hysteria2..."
curl -fsSL https://get.hy2.sh/ | bash > /dev/null 2>&1

# 5. 申请SSL证书
echo "🔐 正在申请免费SSL证书..."
sudo systemctl stop nginx > /dev/null 2>&1 || true # 防止80端口被占用
sudo certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos -m "admin@$MAIN_DOMAIN" --keep-until-expiring > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ 证书申请失败，请检查域名解析是否已生效。"
    exit 1
fi
echo "✅ SSL证书申请成功!"

# 6. 创建 Hysteria2 配置文件
echo "⚙️ 正在生成配置文件..."
sudo mkdir -p /etc/hysteria
sudo tee /etc/hysteria/config.yaml > /dev/null <<EOF
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
EOF

# 7. 创建 systemd 服务，设置开机自启
echo "🔄 正在设置系统服务..."
sudo tee /etc/systemd/system/hysteria-server.service > /dev/null <<EOF
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
EOF

sudo systemctl daemon-reexec
sudo systemctl enable hysteria-server > /dev/null 2>&1
sudo systemctl start hysteria-server

# 8. 配置防火墙
echo "🛡️ 正在配置防火墙..."
sudo ufw allow ssh > /dev/null 2>&1 || true
sudo ufw allow 443/tcp > /dev/null 2>&1 || true
sudo ufw allow 443/udp > /dev/null 2>&1 || true
echo "y" | sudo ufw enable > /dev/null 2>&1 || true

# 9. 设置证书自动续期
echo "🔁 正在设置证书自动续期..."
(crontab -l 2>/dev/null | grep -v "certbot renew"; echo "0 3 * * 1 /usr/bin/certbot renew --quiet && sudo systemctl restart hysteria-server") | crontab -

# --- 新增：生成节点信息 JSON 文件 ---
echo "📄 正在生成节点信息文件 /root/hy2_node_info.json ..."
cat > /root/hy2_node_info.json << JSON_EOF
{
  "name": "$SUBDOMAIN",
  "type": "hysteria2",
  "server": "$DOMAIN",
  "port": 443,
  "password": "$OBFS_PASSWORD",
  "sni": "$DOMAIN",
  "skip-cert-verify": false
}
JSON_EOF
echo "✅ 节点信息文件已生成: /root/hy2_node_info.json"
echo "💡 请将此文件内容复制到你的订阅聚合文件中。"

# --- 新增：生成单节点订阅链接 ---
echo "🔗 正在生成单节点订阅信息..."

# 1. 生成标准 Hysteria 2 YAML 配置片段 (使用列表格式)
NODE_CONFIG_YAML=$(cat << YAML_EOF
- name: "$SUBDOMAIN"
  type: hysteria2
  server: "$DOMAIN"
  port: 443
  password: "$OBFS_PASSWORD"
  sni: "$DOMAIN"
  skip-cert-verify: false
YAML_EOF
)

# 2. 将 YAML 配置转换为 Base64 编码
# 注意：echo -n 用于避免在末尾添加换行符
# 在 Linux 上使用 base64 -w 0 生成单行无换行的 Base64
# 在 macOS 上，base64 默认不换行。为兼容性，我们先尝试 -b 0 (macOS) 如果失败则不加参数 (Linux)
if echo "test" | base64 -b 0 > /dev/null 2>&1; then
    # macOS
    SUBSCRIPTION_BASE64=$(echo -n "$NODE_CONFIG_YAML" | base64 -b 0)
else
    # Linux
    SUBSCRIPTION_BASE64=$(echo -n "$NODE_CONFIG_YAML" | base64 -w 0)
fi

# 3. 显示信息
echo "✅ 单节点订阅信息已生成!"
echo "----------------------------------------"
echo "📡 节点配置 (YAML):"
echo "$NODE_CONFIG_YAML"
echo "----------------------------------------"
echo "🔑 Base64 编码:"
echo "$SUBSCRIPTION_BASE64"
echo "----------------------------------------"
echo "🌐 订阅链接构建方法:"
echo "   请将下面的 <BASE64_ENCODED_STRING> 替换为上面的 Base64 字符串"
echo "   最终订阅链接为 (可尝试粘贴到支持的客户端):"
echo "   hysteria2://subscriptions?sub=<BASE64_ENCODED_STRING>"
echo "   (某些客户端可能直接支持粘贴 Base64 内容)"
echo "----------------------------------------"

echo ""
echo "🎉 Hysteria2 节点已成功部署！"
echo "----------------------------------------"
echo "🖥️  节点地址 (Address): $DOMAIN"
echo "🔌 节点端口 (Port): 443"
echo "🔑 混淆密码 (Obfs Password): $OBFS_PASSWORD"
echo "📡 协议 (Protocol): Hysteria2"
echo "🔒 传输层安全 (TLS): 开启"
echo "🔄 证书续期: 已设置 (每周一凌晨3点)"
echo "----------------------------------------"
echo "💡 请在 PassWall 或其他客户端中使用以上信息添加节点。"
echo "💡 请确保阿里云安全组也放行了 443 TCP 和 443 UDP 端口。"
