#!/bin/bash
cd "$(dirname "$0")"

echo "========================================"
echo "Setup MVE servers on AWS Ubuntu..."
echo "========================================"

# 원격 저장소 페치
echo ""
echo "[1/5] Fetching latest changes..."
git fetch --all

# 최신 버전 풀링
echo ""
echo "[2/5] Pulling latest changes..."
git pull --recurse-submodules

# 서브모듈 업데이트
echo ""
echo "[3/5] Updating git submodules..."
git submodule update --init --recursive

# 로그인 서버 의존성 설치
echo ""
echo "[4/5] Installing Login Server dependencies..."
cd mve-login-server
npm install
cd ..

# 리소스 서버 의존성 설치
echo ""
echo "[5/5] Installing Resource Server dependencies..."
cd mve-resource-server
npm install
cd ..

echo ""
echo "========================================"
echo "Setup complete!"
echo "========================================"
