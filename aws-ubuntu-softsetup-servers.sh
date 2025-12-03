#!/bin/bash
cd "$(dirname "$0")"

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║              MVE 서버 Soft Setup (AWS)                     ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 서브모듈의 로컬 변경사항 제거 (package-lock.json 충돌 방지)
echo ""
echo "[1/8] 서브모듈의 로컬 변경사항 정리 중..."
cd mve-login-server
git checkout -- package-lock.json 2>/dev/null || true
cd ..
cd mve-resource-server
git checkout -- package-lock.json 2>/dev/null || true
cd ..

# Nginx 재구동
echo ""
echo "[2/8] Nginx 설정 재로드 중..."
sudo nginx -t && sudo systemctl reload nginx

# 원격 저장소 페치
echo ""
echo "[3/8] 원격 저장소에서 최신 변경사항 가져오는 중..."
git fetch --all

# 최신 버전 풀링
echo ""
echo "[4/8] 최신 변경사항 풀링 중..."
git pull --recurse-submodules

# 서브모듈 업데이트
echo ""
echo "[5/8] Git 서브모듈 업데이트 중..."
git submodule update --init --recursive

# 로그인 서버 의존성 설치
echo ""
echo "[6/8] Login Server 의존성 설치 중..."
cd mve-login-server
npm install
cd ..

# 리소스 서버 의존성 설치
echo ""
echo "[7/8] Resource Server 의존성 설치 중..."
cd mve-resource-server
npm install
cd ..

# PM2 재시작 (ecosystem.config.js 사용)
echo ""
echo "[8/8] ecosystem.config.js로 PM2 프로세스 재시작 중..."
echo ""
echo "환경 선택:"
echo "  1) development"
echo "  2) production"
read -p "선택 (1 또는 2): " env_choice

if [ "$env_choice" = "2" ]; then
    ENV_MODE="production"
    echo -e "${GREEN}PRODUCTION 모드로 시작 중...${NC}"
else
    ENV_MODE="development"
    echo -e "${GREEN}DEVELOPMENT 모드로 시작 중...${NC}"
fi

echo ""
pm2 restart ecosystem.config.js --env $ENV_MODE

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║              ✓  Soft Setup 완료!  ✓                        ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
