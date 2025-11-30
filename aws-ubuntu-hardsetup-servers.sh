#!/bin/bash

# MVE Servers - Hard Setup Script for AWS Ubuntu
#
# 이 스크립트는 Git 저장소를 원격 상태로 강제 리셋하고 의존성을 재설치합니다.
# 경고: 로컬의 모든 변경사항이 삭제됩니다!
#
# 작동 방식:
# 1. 원격 저장소 페치
# 2. git reset --hard로 원격 상태로 강제 리셋
# 3. 서브모듈 강제 업데이트
# 4. npm 의존성 재설치
# 5. 실행 권한 설정
#
# 사용법:
#   ./aws-ubuntu-hardsetup-servers.sh

cd "$(dirname "$0")"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                                                            ║${NC}"
echo -e "${RED}║                     ⚠  DANGER ZONE  ⚠                      ║${NC}"
echo -e "${RED}║                                                            ║${NC}"
echo -e "${RED}║              MVE Servers Hard Setup (AWS)                  ║${NC}"
echo -e "${RED}║                                                            ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}${BOLD}경고: 이 스크립트는 다음 작업을 수행합니다:${NC}"
echo -e "${RED}  • git reset --hard origin/main (로컬 변경사항 삭제)${NC}"
echo -e "  • 서브모듈 강제 업데이트"
echo -e "  • npm 의존성 재설치"
echo ""
echo -e "${YELLOW}모든 로컬 변경사항이 영구적으로 삭제됩니다!${NC}"
echo -e "계속하기 전에 반드시 변경사항을 백업하세요!"
echo ""

echo ""
echo -e "${RED}${BOLD}⚠  최종 경고: 모든 데이터가 영구적으로 삭제됩니다!  ⚠${NC}"
echo ""
read -p "최종 확인 - 'EXECUTE HARDSETUP'를 정확히 입력하세요: " confirmation

if [ "$confirmation" != "EXECUTE HARDSETUP" ]; then
    echo "작업이 취소되었습니다."
    exit 0
fi

echo ""
echo -e "${GREEN}확인 완료. Hard Setup을 시작합니다...${NC}"
echo ""

# 1. 원격 저장소 페치
echo ""
echo "[1/6] 원격 저장소에서 최신 변경사항 가져오는 중..."
git fetch --all

# 2. 원격의 최신 커밋으로 강제 리셋
echo ""
echo "[2/6] 저장소를 원격 상태로 강제 리셋 중..."
git reset --hard origin/main

# 3. 서브모듈 업데이트
echo ""
echo "[3/6] Git 서브모듈 업데이트 중..."
git submodule update --init --recursive

# 4. 로그인 서버 의존성 설치
echo ""
echo "[4/6] Login Server 의존성 설치 중..."
cd mve-login-server
npm install
cd ..

# 5. 리소스 서버 의존성 설치
echo ""
echo "[5/6] Resource Server 의존성 설치 중..."
cd mve-resource-server
npm install
cd ..

# 6. 실행 권한 설정
echo ""
echo "[6/6] 쉘 스크립트 실행 권한 설정 중..."
chmod +x aws-ubuntu-hardsetup-servers.sh
chmod +x aws-ubuntu-hardsetup-db.sh
chmod +x aws-ubuntu-softsetup-servers.sh
chmod +x aws-ubuntu-softsetup-db.sh
chmod +x aws-ubuntu-start-servers.sh

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║              ✓  Hard Setup 완료!  ✓                        ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
