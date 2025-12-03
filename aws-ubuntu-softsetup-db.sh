#!/bin/bash

# MVE Servers - PostgreSQL Database Soft Setup Script for AWS Ubuntu
#
# 이 스크립트는 데이터베이스를 안전하게 초기화합니다.
# 기존 데이터베이스가 있으면 생성을 건너뛰고, init.sql만 실행합니다.
#
# 작동 방식:
# 1. .env 파일에서 데이터베이스 연결 정보 로드
# 2. PostgreSQL 연결 테스트
# 3. 데이터베이스가 없으면 생성 (있으면 건너뜀)
# 4. init.sql 실행 (테이블 생성/업데이트)
#
# 사용법:
#   ./aws-ubuntu-softsetup-db.sh

cd "$(dirname "$0")"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║              MVE 데이터베이스 Soft Setup (AWS)             ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# 함수 정의
# ============================================

# 환경 변수 로드
# .env 파일에서 DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME 등을 읽어옵니다.
# grep -v '^#'으로 주석 라인을 제외하고, export로 환경 변수로 설정합니다.
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
# psql 명령어로 postgres 기본 데이터베이스에 연결을 시도합니다.
# \q 명령으로 바로 종료하며, 연결만 테스트합니다.
# 성공하면 0 반환, 실패하면 1 반환
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

# 데이터베이스 생성
# pg_database 시스템 카탈로그를 조회하여 데이터베이스 존재 여부를 확인합니다.
# 이미 존재하면 생성을 건너뛰고, 없으면 CREATE DATABASE를 실행합니다.
create_database() {
    local db_name=$1
    local db_host=$2
    local db_port=$3
    local db_user=$4

    echo -n "Checking if database '$db_name' exists... "

    # 데이터베이스 존재 여부 확인
    # -tAc 옵션: -t(헤더 제거), -A(정렬 없음), -c(명령 실행)
    if PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$db_name'" | grep -q 1; then
        echo -e "${YELLOW}Already exists${NC}"
        return 0
    else
        echo -e "${NC}Not found${NC}"
        echo -n "Creating database '$db_name'... "

        # 데이터베이스 생성 (에러 출력 억제)
        if PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -c "CREATE DATABASE $db_name;" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
            return 0
        else
            echo -e "${RED}✗${NC}"
            return 1
        fi
    fi
}

# SQL 파일 실행
# init.sql 파일을 읽어서 데이터베이스에 실행합니다.
# -f 옵션으로 파일 경로를 지정하며, 테이블 생성, 인덱스 생성 등의 DDL을 실행합니다.
# psql의 출력을 모두 억제하고 필수 메시지만 표시합니다.
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

    # SQL 실행 (모든 출력 억제, 에러만 stderr로 표시)
    if PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -f "$sql_file" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        # 에러 발생 시 상세 내용 표시
        echo "Running SQL again to show errors:"
        PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -f "$sql_file"
        return 1
    fi
}

# ============================================
# 1. Login Server Database Setup
# ============================================
echo ""
echo "========================================"
echo "[1/2] Login Server 데이터베이스 셋업"
echo "========================================"

# .env 파일 로드
if ! load_env "mve-login-server/.env"; then
    echo -e "${RED}ERROR:${NC} Cannot proceed without .env file"
    exit 1
fi

# 환경 변수 설정
# DB_HOST가 없으면 기본값 localhost 사용
LOGIN_DB_HOST=${DB_HOST:-localhost}
LOGIN_DB_PORT=${DB_PORT:-5432}
LOGIN_DB_USER=${DB_USER}
LOGIN_DB_NAME=${DB_NAME}

echo "Database: $LOGIN_DB_NAME"
echo "Host: $LOGIN_DB_HOST:$LOGIN_DB_PORT"
echo ""

# PostgreSQL 연결 테스트
if ! test_postgres_connection "$LOGIN_DB_HOST" "$LOGIN_DB_PORT" "$LOGIN_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Cannot connect to PostgreSQL"
    exit 1
fi

# 데이터베이스 생성 (없는 경우에만)
if ! create_database "$LOGIN_DB_NAME" "$LOGIN_DB_HOST" "$LOGIN_DB_PORT" "$LOGIN_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Failed to create database"
    exit 1
fi

# init.sql 실행
if ! execute_sql_file "mve-login-server/init.sql" "$LOGIN_DB_NAME" "$LOGIN_DB_HOST" "$LOGIN_DB_PORT" "$LOGIN_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Failed to initialize login database"
    exit 1
fi

echo -e "${GREEN}✓${NC} Login Server database setup complete"

# ============================================
# 2. Resource Server Database Setup
# ============================================
echo ""
echo "========================================"
echo "[2/2] Resource Server 데이터베이스 셋업"
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

echo "Database: $RESOURCE_DB_NAME"
echo "Host: $RESOURCE_DB_HOST:$RESOURCE_DB_PORT"
echo ""

# PostgreSQL 연결 테스트
if ! test_postgres_connection "$RESOURCE_DB_HOST" "$RESOURCE_DB_PORT" "$RESOURCE_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Cannot connect to PostgreSQL"
    exit 1
fi

# Resource DB는 이제 항상 분리되어 있음
if ! create_database "$RESOURCE_DB_NAME" "$RESOURCE_DB_HOST" "$RESOURCE_DB_PORT" "$RESOURCE_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Failed to create database"
    exit 1
fi

# init.sql 실행
if ! execute_sql_file "mve-resource-server/init.sql" "$RESOURCE_DB_NAME" "$RESOURCE_DB_HOST" "$RESOURCE_DB_PORT" "$RESOURCE_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Failed to initialize resource database"
    exit 1
fi

echo -e "${GREEN}✓${NC} Resource Server database setup complete"

# ============================================
# 완료 메시지
# ============================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║              ✓  Soft Setup 완료!  ✓                        ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "초기화된 데이터베이스:"
echo "  - Login Server: $LOGIN_DB_NAME"
echo "  - Resource Server: $RESOURCE_DB_NAME"
echo ""
