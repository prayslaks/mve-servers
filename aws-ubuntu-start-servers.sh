#!/bin/bash
cd "$(dirname "$0")"

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║              MVE 서버 시작 (PM2)                           ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# PM2 설치 확인
if ! command -v pm2 &> /dev/null; then
    echo -e "${YELLOW}PM2를 찾을 수 없습니다. 설치 중...${NC}"
    sudo npm install -g pm2
fi

# 이미 구동 중이던 서버 종료
pm2 delete all 2>/dev/null

# 환경 선택
echo ""
echo "환경 선택:"
echo "  1) development"
echo "  2) production"
read -p "선택 (1 또는 2): " env_choice

if [ "$env_choice" = "2" ]; then
    ENV_MODE="production"
    echo -e "${GREEN}PRODUCTION 모드로 서버 시작 중...${NC}"
else
    ENV_MODE="development"
    echo -e "${GREEN}DEVELOPMENT 모드로 서버 시작 중...${NC}"
fi

echo ""
pm2 start ecosystem.config.js --env $ENV_MODE

# PM2 관리에 서버 프로세스 추가
pm2 save

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║              ✓  서버 시작 완료!  ✓                         ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
pm2 status
echo ""
