#!/bin/bash

# MVE Servers - Login DB Only Reset Script (Development용)
#
# 이 스크립트는 logindb만 초기화합니다.
# resourcedb의 음원 데이터는 그대로 유지됩니다.
#
# 사용법:
#   ./dev-reset-logindb.sh

cd "$(dirname "$0")"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║                                                            ║${NC}"
echo -e "${YELLOW}║              개발용 Login DB 초기화 스크립트                ║${NC}"
echo -e "${YELLOW}║                                                            ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}이 스크립트는 logindb만 초기화합니다.${NC}"
echo -e "${GREEN}resourcedb의 음원 데이터는 그대로 유지됩니다.${NC}"
echo ""
echo -e "${YELLOW}경고: logindb의 모든 유저 정보가 삭제됩니다!${NC}"
echo ""

read -p "계속하시겠습니까? (y/N): " confirmation

if [ "$confirmation" != "y" ] && [ "$confirmation" != "Y" ]; then
    echo "작업이 취소되었습니다."
    exit 0
fi

echo ""
echo -e "${GREEN}Login DB 초기화를 시작합니다...${NC}"
echo ""

# ============================================
# 함수 정의
# ============================================

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

drop_database() {
    local db_name=$1
    local db_host=$2
    local db_port=$3
    local db_user=$4

    if PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$db_name'" | grep -q 1; then
        echo -n "Dropping database '$db_name'... "

        PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -c "
            SELECT pg_terminate_backend(pg_stat_activity.pid)
            FROM pg_stat_activity
            WHERE pg_stat_activity.datname = '$db_name'
            AND pid <> pg_backend_pid();
        " >/dev/null 2>&1

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

    if PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -f "$sql_file" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# ============================================
# Login Server Database Reset
# ============================================
echo ""
echo "========================================"
echo "Login Server Database Reset"
echo "========================================"

if ! load_env "mve-login-server/.env"; then
    echo -e "${RED}ERROR:${NC} Cannot proceed without .env file"
    exit 1
fi

LOGIN_DB_HOST=${DB_HOST:-localhost}
LOGIN_DB_PORT=${DB_PORT:-5432}
LOGIN_DB_USER=${DB_USER}
LOGIN_DB_NAME=${DB_NAME}
LOGIN_DB_PASSWORD=${DB_PASSWORD}

echo "Database: $LOGIN_DB_NAME"
echo "Host: $LOGIN_DB_HOST:$LOGIN_DB_PORT"
echo ""

if ! test_postgres_connection "$LOGIN_DB_HOST" "$LOGIN_DB_PORT" "$LOGIN_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Cannot connect to PostgreSQL"
    exit 1
fi

if ! drop_database "$LOGIN_DB_NAME" "$LOGIN_DB_HOST" "$LOGIN_DB_PORT" "$LOGIN_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Failed to drop database"
    exit 1
fi

if ! create_database "$LOGIN_DB_NAME" "$LOGIN_DB_HOST" "$LOGIN_DB_PORT" "$LOGIN_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Failed to create database"
    exit 1
fi

if ! execute_sql_file "mve-login-server/init.sql" "$LOGIN_DB_NAME" "$LOGIN_DB_HOST" "$LOGIN_DB_PORT" "$LOGIN_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Failed to initialize login database"
    exit 1
fi

echo -e "${GREEN}✓${NC} Login Server database reset complete"

# ============================================
# 완료 메시지
# ============================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║              ✓  Login DB 초기화 완료!  ✓                   ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "초기화된 데이터베이스:"
echo "  - Login Server: $LOGIN_DB_NAME (초기화됨)"
echo ""
echo -e "${GREEN}resourcedb의 음원 데이터는 그대로 유지되었습니다.${NC}"
echo ""
