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
pm2 delete all 2>/dev/null

# ecosystem.config.js를 사용하여 서버 구동
echo ""
echo "Starting servers using ecosystem.config.js..."
pm2 start ecosystem.config.js --env production

# PM2 관리에 서버 프로세스 추가
pm2 save

echo ""
echo "========================================"
echo "Servers started!"
echo ""
pm2 status
echo "========================================"
