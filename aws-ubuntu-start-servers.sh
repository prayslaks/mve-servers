#!/bin/bash
cd "$(dirname "$0")"

echo "========================================"
echo "Starting MVE servers with PM2..."
echo "========================================"

# PM2 설치 확인
if ! command -v pm2 &> /dev/null; then
    echo "PM2 not found. Installing..."
    sudo npm install -g pm2
fi

# 이미 구동 중이던 서버 종료
pm2 delete mve-login-server 2>/dev/null
pm2 delete mve-resource-server 2>/dev/null

# 서버 구동
echo ""
echo "[1/2] Starting Login Server..."
pm2 start mve-login-server/server.js --name mve-login-server

echo ""
echo "[2/2] Starting Resource Server..."
pm2 start mve-resource-server/server.js --name mve-resource-server

# PM2 관리에 서버 프로세스 추가
pm2 save

echo ""
echo "========================================"
echo "Servers started!"
echo ""
pm2 status
echo "========================================"
