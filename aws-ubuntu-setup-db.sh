#!/bin/bash

# MVE Servers - PostgreSQL Database Setup Script for AWS Ubuntu
# This script initializes both login and resource server databases

cd "$(dirname "$0")"

echo "========================================"
echo "MVE PostgreSQL Database Setup"
echo "========================================"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 환경 변수 로드 함수
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
test_postgres_connection() {
    local db_host=$1
    local db_port=$2
    local db_user=$3

    echo -n "Testing PostgreSQL connection... "
    if PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -c '\q' 2>/dev/null; then
        echo -e "${GREEN}✓ Connected${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed${NC}"
        return 1
    fi
}

# 데이터베이스 생성
create_database() {
    local db_name=$1
    local db_host=$2
    local db_port=$3
    local db_user=$4

    echo -n "Checking if database '$db_name' exists... "

    # 데이터베이스 존재 여부 확인
    if PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$db_name'" | grep -q 1; then
        echo -e "${YELLOW}Already exists${NC}"
        return 0
    else
        echo -e "${NC}Not found${NC}"
        echo -n "Creating database '$db_name'... "

        if PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -c "CREATE DATABASE $db_name;" 2>/dev/null; then
            echo -e "${GREEN}✓ Created${NC}"
            return 0
        else
            echo -e "${RED}✗ Failed${NC}"
            return 1
        fi
    fi
}

# SQL 파일 실행
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

    echo "Executing SQL file: $(basename $sql_file)"

    if PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -f "$sql_file" 2>&1 | grep -v "^$"; then
        echo -e "${GREEN}✓${NC} SQL executed successfully"
        return 0
    else
        echo -e "${RED}✗${NC} SQL execution failed"
        return 1
    fi
}

# ============================================
# 1. Login Server Database Setup
# ============================================
echo ""
echo "========================================"
echo "[1/2] Login Server Database Setup"
echo "========================================"

# .env 파일 로드
if ! load_env "mve-login-server/.env"; then
    echo -e "${RED}ERROR:${NC} Cannot proceed without .env file"
    echo "Please create mve-login-server/.env based on .env.example"
    exit 1
fi

# 환경 변수 확인
LOGIN_DB_HOST=${DB_HOST:-localhost}
LOGIN_DB_PORT=${DB_PORT:-5432}
LOGIN_DB_USER=${DB_USER}
LOGIN_DB_NAME=${DB_NAME}
LOGIN_DB_PASSWORD=${DB_PASSWORD}

echo "Database: $LOGIN_DB_NAME"
echo "Host: $LOGIN_DB_HOST:$LOGIN_DB_PORT"
echo "User: $LOGIN_DB_USER"
echo ""

# PostgreSQL 연결 테스트
if ! test_postgres_connection "$LOGIN_DB_HOST" "$LOGIN_DB_PORT" "$LOGIN_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Cannot connect to PostgreSQL"
    echo "Please check your database credentials and ensure PostgreSQL is running"
    exit 1
fi

# 데이터베이스 생성
if ! create_database "$LOGIN_DB_NAME" "$LOGIN_DB_HOST" "$LOGIN_DB_PORT" "$LOGIN_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Failed to create database"
    exit 1
fi

# init.sql 실행
echo ""
if ! execute_sql_file "mve-login-server/init.sql" "$LOGIN_DB_NAME" "$LOGIN_DB_HOST" "$LOGIN_DB_PORT" "$LOGIN_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Failed to initialize login database"
    exit 1
fi

echo -e "${GREEN}✓${NC} Login Server database initialized successfully"

# ============================================
# 2. Resource Server Database Setup
# ============================================
echo ""
echo "========================================"
echo "[2/2] Resource Server Database Setup"
echo "========================================"

# .env 파일 로드
if ! load_env "mve-resource-server/.env"; then
    echo -e "${RED}ERROR:${NC} Cannot proceed without .env file"
    echo "Please create mve-resource-server/.env based on .env.example"
    exit 1
fi

# 환경 변수 확인
RESOURCE_DB_HOST=${DB_HOST:-localhost}
RESOURCE_DB_PORT=${DB_PORT:-5432}
RESOURCE_DB_USER=${DB_USER}
RESOURCE_DB_NAME=${DB_NAME}
RESOURCE_DB_PASSWORD=${DB_PASSWORD}

echo "Database: $RESOURCE_DB_NAME"
echo "Host: $RESOURCE_DB_HOST:$RESOURCE_DB_PORT"
echo "User: $RESOURCE_DB_USER"
echo ""

# PostgreSQL 연결 테스트
if ! test_postgres_connection "$RESOURCE_DB_HOST" "$RESOURCE_DB_PORT" "$RESOURCE_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Cannot connect to PostgreSQL"
    echo "Please check your database credentials and ensure PostgreSQL is running"
    exit 1
fi

# 데이터베이스 생성 (Login과 같은 DB를 사용할 수도 있음)
if ! create_database "$RESOURCE_DB_NAME" "$RESOURCE_DB_HOST" "$RESOURCE_DB_PORT" "$RESOURCE_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Failed to create database"
    exit 1
fi

# init.sql 실행
echo ""
if ! execute_sql_file "mve-resource-server/init.sql" "$RESOURCE_DB_NAME" "$RESOURCE_DB_HOST" "$RESOURCE_DB_PORT" "$RESOURCE_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Failed to initialize resource database"
    exit 1
fi

echo -e "${GREEN}✓${NC} Resource Server database initialized successfully"

# ============================================
# 완료 메시지
# ============================================
echo ""
echo "========================================"
echo -e "${GREEN}Database Setup Complete!${NC}"
echo "========================================"
echo ""
echo "Databases initialized:"
echo "  - Login Server: $LOGIN_DB_NAME"
echo "  - Resource Server: $RESOURCE_DB_NAME"
echo ""
echo "Note: Redis is required for email verification"
echo "Make sure Redis is installed and running:"
echo "  sudo systemctl status redis"
echo ""
echo "Next steps:"
echo "  1. Start Redis: sudo systemctl start redis"
echo "  2. Run servers: ./aws-ubuntu-start-servers.sh"
echo "  3. Or use PM2: pm2 start ecosystem.config.js --env production"
echo ""
