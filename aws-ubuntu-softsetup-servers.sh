#!/bin/bash
cd "$(dirname "$0")"

echo "========================================"
echo "Setup MVE servers on AWS Ubuntu..."
echo "========================================"

# 서브모듈의 로컬 변경사항 제거 (package-lock.json 충돌 방지)
echo ""
echo "[0/6] Cleaning up local changes in submodules..."
cd mve-login-server
git checkout -- package-lock.json 2>/dev/null || true
cd ..
cd mve-resource-server
git checkout -- package-lock.json 2>/dev/null || true
cd ..

# 원격 저장소 페치
echo ""
echo "[1/6] Fetching latest changes..."
git fetch --all

# 최신 버전 풀링
echo ""
echo "[2/6] Pulling latest changes..."
git pull --recurse-submodules

# 서브모듈 업데이트
echo ""
echo "[3/6] Updating git submodules..."
git submodule update --init --recursive

# 로그인 서버 의존성 설치
echo ""
echo "[4/6] Installing Login Server dependencies..."
cd mve-login-server
npm install
cd ..

# 리소스 서버 의존성 설치
echo ""
echo "[5/6] Installing Resource Server dependencies..."
cd mve-resource-server
npm install
cd ..

# PM2 재시작
echo ""
echo "[6/6] Restarting PM2 processes..."
pm2 restart all

echo ""
echo "========================================"
echo "Setup complete! Servers restarted."
echo "========================================"
