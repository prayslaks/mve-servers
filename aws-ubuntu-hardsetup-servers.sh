#!/bin/bash
cd "$(dirname "$0")"

echo "========================================"
echo "Hard Setup MVE servers on AWS Ubuntu..."
echo "========================================"
echo ""
echo "WARNING: This script will perform the following actions:"
echo "  - git reset --hard origin/main (all local changes will be lost)"
echo "  - Force update submodules"
echo "  - Reinstall npm dependencies"
echo ""
echo "Please backup any local modifications before proceeding!"
echo ""
read -p "Do you want to continue? (type 'yes' to proceed): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Operation cancelled."
    exit 1
fi

# 원격 저장소 페치
echo ""
echo "[1/6] Fetching latest changes..."
git fetch --all

# 원격의 최신 커밋으로 강제 리셋
echo ""
echo "[2/6] Hard Reset Repository..."
git reset --hard origin/main

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

# 권한 초기화
echo ""
echo "[6/6] Set execute permissions for shell scripts..."
chmod +x aws-ubuntu-hardsetup-servers.sh
chmod +x aws-ubuntu-setup-servers.sh
chmod +x aws-ubuntu-start-servers.sh

echo ""
echo "========================================"
echo "Hard Setup complete!"
echo "========================================"
