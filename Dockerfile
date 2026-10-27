# Xray (VLESS + WebSocket) on Railway
# TLS 由 Railway 边缘节点终止，容器内部只跑明文 WS。
FROM alpine:3.21

RUN apk add --no-cache ca-certificates curl unzip \
 && mkdir -p /usr/local/bin /etc/xray /srv \
 && curl -sL -o /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip \
 && unzip -o -q /tmp/xray.zip -d /usr/local/bin xray \
 && chmod +x /usr/local/bin/xray \
 && rm -f /tmp/xray.zip \
 && curl -sL -o /usr/local/bin/caddy "https://caddyserver.com/api/download?os=linux&arch=amd64" \
 && chmod +x /usr/local/bin/caddy \
 && caddy version && xray version | head -1

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Railway 注入 $PORT；$UUID 必填；$WS_PATH 为混淆路径
ENV WS_PATH=ws
EXPOSE 8080
CMD ["/entrypoint.sh"]
