#!/bin/bash

# MVE Servers - PostgreSQL Database Hard Setup Script for AWS Ubuntu
#
# 이 스크립트는 데이터베이스를 완전히 삭제하고 재생성합니다.
# 경고: 모든 데이터가 삭제됩니다! 프로덕션 환경에서는 주의하여 사용하세요.
#
# 작동 방식:
# 1. 기존 데이터베이스를 완전히 DROP (존재하는 경우)
# 2. 새로운 데이터베이스 생성
# 3. init.sql을 실행하여 스키마 및 초기 데이터 설정
#
# 사용법:
#   ./aws-ubuntu-hardsetup-db.sh

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
echo -e "${RED}║            MVE PostgreSQL Database Hard Setup              ║${NC}"
echo -e "${RED}║                                                            ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}${BOLD}경고: 이 스크립트는 다음 작업을 수행합니다:${NC}"
echo -e "${RED}  • 기존 데이터베이스 완전 삭제 (DROP)${NC}"
echo -e "  • 새 데이터베이스 생성 (CREATE)"
echo -e "  • init.sql 실행하여 스키마 재생성"
echo ""
echo -e "${YELLOW}모든 데이터가 영구적으로 삭제됩니다!${NC}"
echo -e "계속하기 전에 반드시 데이터를 백업하세요!"
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

# ============================================
# 함수 정의
# ============================================

# 환경 변수 로드
# .env 파일에서 환경 변수를 읽어옵니다.
load_env() {
    local env_file=$1
    if [ -f "$env_file" ]; then
        echo -e "${GREEN}✓${NC} Loading environment from: $env_file"
        export $(grep -v '^#' "$env_file" | xargs)
    else
        echo -e "${RED}✗${NC} Environment file not found: $env_file"
        return 1
    fi
}

# PostgreSQL 연결 테스트
# 데이터베이스 서버에 연결 가능한지 확인합니다.
test_postgres_connection() {
    local db_host=$1
    local db_port=$2
    local db_user=$3

    echo -n "Testing PostgreSQL connection... "
    if PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -c '\q' 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# 데이터베이스 강제 삭제
# 기존 연결을 모두 종료하고 데이터베이스를 삭제합니다.
# 연결된 세션이 있으면 먼저 종료시킵니다.
drop_database() {
    local db_name=$1
    local db_host=$2
    local db_port=$3
    local db_user=$4

    # 데이터베이스 존재 여부 확인
    if PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$db_name'" | grep -q 1; then
        echo -n "Dropping database '$db_name'... "

        # 기존 연결 종료 (다른 세션이 연결되어 있으면 DROP이 실패하므로)
        PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -c "
            SELECT pg_terminate_backend(pg_stat_activity.pid)
            FROM pg_stat_activity
            WHERE pg_stat_activity.datname = '$db_name'
            AND pid <> pg_backend_pid();
        " >/dev/null 2>&1

        # 데이터베이스 삭제
        if PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -c "DROP DATABASE IF EXISTS $db_name;" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
            return 0
        else
            echo -e "${RED}✗${NC}"
            return 1
        fi
    else
        echo "데이터베이스 '$db_name'가 존재하지 않음 (삭제 건너뜀)"
        return 0
    fi
}

# 데이터베이스 생성
# 새로운 빈 데이터베이스를 생성합니다.
create_database() {
    local db_name=$1
    local db_host=$2
    local db_port=$3
    local db_user=$4

    echo -n "Creating database '$db_name'... "

    if PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -c "CREATE DATABASE $db_name;" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# SQL 파일 실행
# init.sql 파일을 실행하여 테이블, 인덱스 등을 생성합니다.
execute_sql_file() {
    local sql_file=$1
    local db_name=$2
    local db_host=$3
    local db_port=$4
    local db_user=$5

    if [ ! -f "$sql_file" ]; then
        echo -e "${RED}✗${NC} SQL file not found: $sql_file"
        return 1
    fi

    echo -n "Executing SQL file: $(basename $sql_file)... "

    # SQL 실행 (출력 억제, 에러만 표시)
    if PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -f "$sql_file" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# ============================================
# 1. Login Server Database Setup
# ============================================
echo ""
echo "========================================"
echo "[1/2] Login Server Database Hard Setup"
echo "========================================"

# .env 파일 로드
if ! load_env "mve-login-server/.env"; then
    echo -e "${RED}ERROR:${NC} Cannot proceed without .env file"
    exit 1
fi

# 환경 변수 설정
LOGIN_DB_HOST=${DB_HOST:-localhost}
LOGIN_DB_PORT=${DB_PORT:-5432}
LOGIN_DB_USER=${DB_USER}
LOGIN_DB_NAME=${DB_NAME}
LOGIN_DB_PASSWORD=${DB_PASSWORD}

echo "Database: $LOGIN_DB_NAME"
echo "Host: $LOGIN_DB_HOST:$LOGIN_DB_PORT"
echo ""

# PostgreSQL 연결 테스트
if ! test_postgres_connection "$LOGIN_DB_HOST" "$LOGIN_DB_PORT" "$LOGIN_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Cannot connect to PostgreSQL"
    exit 1
fi

# 기존 데이터베이스 삭제
if ! drop_database "$LOGIN_DB_NAME" "$LOGIN_DB_HOST" "$LOGIN_DB_PORT" "$LOGIN_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Failed to drop database"
    exit 1
fi

# 새 데이터베이스 생성
if ! create_database "$LOGIN_DB_NAME" "$LOGIN_DB_HOST" "$LOGIN_DB_PORT" "$LOGIN_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Failed to create database"
    exit 1
fi

# init.sql 실행
if ! execute_sql_file "mve-login-server/init.sql" "$LOGIN_DB_NAME" "$LOGIN_DB_HOST" "$LOGIN_DB_PORT" "$LOGIN_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Failed to initialize login database"
    exit 1
fi

echo -e "${GREEN}✓${NC} Login Server database hard setup complete"

# ============================================
# 2. Resource Server Database Setup
# ============================================
echo ""
echo "========================================"
echo "[2/2] Resource Server Database Hard Setup"
echo "========================================"

# .env 파일 로드
if ! load_env "mve-resource-server/.env"; then
    echo -e "${RED}ERROR:${NC} Cannot proceed without .env file"
    exit 1
fi

# 환경 변수 설정
RESOURCE_DB_HOST=${DB_HOST:-localhost}
RESOURCE_DB_PORT=${DB_PORT:-5432}
RESOURCE_DB_USER=${DB_USER}
RESOURCE_DB_NAME=${DB_NAME}
RESOURCE_DB_PASSWORD=${DB_PASSWORD}

echo "Database: $RESOURCE_DB_NAME"
echo "Host: $RESOURCE_DB_HOST:$RESOURCE_DB_PORT"
echo ""

# PostgreSQL 연결 테스트
if ! test_postgres_connection "$RESOURCE_DB_HOST" "$RESOURCE_DB_PORT" "$RESOURCE_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Cannot connect to PostgreSQL"
    exit 1
fi

# 기존 데이터베이스 삭제 (Login과 같은 DB를 사용하는 경우 건너뜀)
if [ "$RESOURCE_DB_NAME" != "$LOGIN_DB_NAME" ]; then
    if ! drop_database "$RESOURCE_DB_NAME" "$RESOURCE_DB_HOST" "$RESOURCE_DB_PORT" "$RESOURCE_DB_USER"; then
        echo -e "${RED}ERROR:${NC} Failed to drop database"
        exit 1
    fi

    # 새 데이터베이스 생성
    if ! create_database "$RESOURCE_DB_NAME" "$RESOURCE_DB_HOST" "$RESOURCE_DB_PORT" "$RESOURCE_DB_USER"; then
        echo -e "${RED}ERROR:${NC} Failed to create database"
        exit 1
    fi
else
    echo "Login Server와 동일한 데이터베이스 사용 (삭제/생성 건너뜀)"
fi

# init.sql 실행
if ! execute_sql_file "mve-resource-server/init.sql" "$RESOURCE_DB_NAME" "$RESOURCE_DB_HOST" "$RESOURCE_DB_PORT" "$RESOURCE_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Failed to initialize resource database"
    exit 1
fi

echo -e "${GREEN}✓${NC} Resource Server database hard setup complete"

# ============================================
# 완료 메시지
# ============================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║              ✓  Hard Setup 완료!  ✓                        ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "재생성된 데이터베이스:"
echo "  - Login Server: $LOGIN_DB_NAME"
echo "  - Resource Server: $RESOURCE_DB_NAME"
echo ""
