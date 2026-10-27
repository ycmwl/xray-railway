#!/bin/sh
# 入口脚本：生成 xray 配置 + 订阅文件 + Caddy 反代
set -eu

: "${UUID:?环境变量 UUID 未设置}"
: "${WS_PATH:=ws}"
: "${PORT:=8080}"
DOMAIN="${RAILWAY_PUBLIC_DOMAIN:-localhost}"

# ---- xray 配置：VLESS + WS，监听本机 10000 ----
cat > /etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": 10000,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [{ "id": "$UUID" }],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/$WS_PATH" }
      }
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

# ---- 订阅文件 /sub：base64 编码的 vless 节点链接 ----
LINK="vless://$UUID@$DOMAIN:443?encryption=none&security=tls&type=ws&host=$DOMAIN&path=%2F$WS_PATH#Railway-Xray"
printf '%s' "$LINK" | base64 -w0 | tr -d '\n' > /srv/sub
echo "[entrypoint] subscription ready for domain: $DOMAIN"

# ---- Caddy：$PORT 接管全部流量，/WS_PATH 反代给 xray，/sub 提供订阅 ----
cat > /etc/xray/Caddyfile <<EOF
{
  admin off
}
:$PORT {
  handle /$WS_PATH* {
    reverse_proxy 127.0.0.1:10000
  }
  handle /sub* {
    root * /srv
    file_server
  }
  handle {
    respond "ok" 200
  }
}
EOF

/usr/local/bin/xray -config /etc/xray/config.json &
exec /usr/local/bin/caddy run --config /etc/xray/Caddyfile --adapter caddyfile
