#!/bin/bash
cd "$(dirname "$0")"

echo "========================================"
echo "Setup MVE servers on AWS Ubuntu..."
echo "========================================"

# 서브모듈의 로컬 변경사항 제거 (package-lock.json 충돌 방지)
echo ""
echo "[1/8] Cleaning up local changes in submodules..."
cd mve-login-server
git checkout -- package-lock.json 2>/dev/null || true
cd ..
cd mve-resource-server
git checkout -- package-lock.json 2>/dev/null || true
cd ..

# Nginx 재구동
echo ""
echo "[2/8] reloaed nginx configuration..."
sudo nginx -t && sudo systemctl reload nginx

# 원격 저장소 페치
echo ""
echo "[3/8] Fetching latest changes..."
git fetch --all

# 최신 버전 풀링
echo ""
echo "[4/8] Pulling latest changes..."
git pull --recurse-submodules

# 서브모듈 업데이트
echo ""
echo "[5/8] Updating git submodules..."
git submodule update --init --recursive

# 로그인 서버 의존성 설치
echo ""
echo "[6/8] Installing Login Server dependencies..."
cd mve-login-server
npm install
cd ..

# 리소스 서버 의존성 설치
echo ""
echo "[7/8] Installing Resource Server dependencies..."
cd mve-resource-server
npm install
cd ..

# PM2 재시작
echo ""
echo "[8/8] Restarting PM2 processes..."
pm2 restart all

echo ""
echo "========================================"
echo "Setup complete! Servers restarted."
echo "========================================"
