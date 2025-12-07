#!/bin/bash

# MVE Servers - Resource DB 3D Models Only Reset Script (Development용)
#
# 이 스크립트는 resourcedb의 3D 모델 관련 테이블만 초기화합니다.
# - user_models (유저별 3D 모델)
# - accessory_presets (액세서리 프리셋)
# audio_files (음원 데이터)는 그대로 유지됩니다.
#
# 사용법:
#   ./dev-reset-resourcedb-models.sh

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
echo -e "${YELLOW}║          개발용 Resource DB 3D 모델 초기화 스크립트         ║${NC}"
echo -e "${YELLOW}║                                                            ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}이 스크립트는 resourcedb의 3D 모델 테이블만 초기화합니다.${NC}"
echo -e "${GREEN}초기화 대상:${NC}"
echo "  - user_models (유저별 3D 모델)"
echo "  - accessory_presets (액세서리 프리셋)"
echo ""
echo -e "${GREEN}유지되는 데이터:${NC}"
echo "  - audio_files (음원 데이터)"
echo ""
echo -e "${YELLOW}경고: 모든 유저의 3D 모델과 액세서리 프리셋이 삭제됩니다!${NC}"
echo ""

read -p "계속하시겠습니까? (y/N): " confirmation

if [ "$confirmation" != "y" ] && [ "$confirmation" != "Y" ]; then
    echo "작업이 취소되었습니다."
    exit 0
fi

echo ""
echo -e "${GREEN}Resource DB 3D 모델 초기화를 시작합니다...${NC}"
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

execute_sql_command() {
    local sql_command=$1
    local db_name=$2
    local db_host=$3
    local db_port=$4
    local db_user=$5
    local description=$6

    echo -n "$description... "

    if PGPASSWORD=$DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -c "$sql_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# ============================================
# Resource Server Database 3D Models Reset
# ============================================
echo ""
echo "========================================"
echo "Resource Server 3D Models Reset"
echo "========================================"

if ! load_env "mve-resource-server/.env"; then
    echo -e "${RED}ERROR:${NC} Cannot proceed without .env file"
    exit 1
fi

RESOURCE_DB_HOST=${DB_HOST:-localhost}
RESOURCE_DB_PORT=${DB_PORT:-5432}
RESOURCE_DB_USER=${DB_USER}
RESOURCE_DB_NAME=${DB_NAME}
RESOURCE_DB_PASSWORD=${DB_PASSWORD}

echo "Database: $RESOURCE_DB_NAME"
echo "Host: $RESOURCE_DB_HOST:$RESOURCE_DB_PORT"
echo ""

if ! test_postgres_connection "$RESOURCE_DB_HOST" "$RESOURCE_DB_PORT" "$RESOURCE_DB_USER"; then
    echo -e "${RED}ERROR:${NC} Cannot connect to PostgreSQL"
    exit 1
fi

# 3D 모델 관련 테이블 삭제 (CASCADE로 관련 데이터도 모두 삭제)
echo ""
echo "Dropping 3D model tables..."

if ! execute_sql_command \
    "DROP TABLE IF EXISTS accessory_presets CASCADE;" \
    "$RESOURCE_DB_NAME" "$RESOURCE_DB_HOST" "$RESOURCE_DB_PORT" "$RESOURCE_DB_USER" \
    "Dropping accessory_presets table"; then
    echo -e "${RED}ERROR:${NC} Failed to drop accessory_presets table"
    exit 1
fi

if ! execute_sql_command \
    "DROP TABLE IF EXISTS user_models CASCADE;" \
    "$RESOURCE_DB_NAME" "$RESOURCE_DB_HOST" "$RESOURCE_DB_PORT" "$RESOURCE_DB_USER" \
    "Dropping user_models table"; then
    echo -e "${RED}ERROR:${NC} Failed to drop user_models table"
    exit 1
fi

# 관련 함수 삭제
if ! execute_sql_command \
    "DROP FUNCTION IF EXISTS update_accessory_presets_updated_at() CASCADE;" \
    "$RESOURCE_DB_NAME" "$RESOURCE_DB_HOST" "$RESOURCE_DB_PORT" "$RESOURCE_DB_USER" \
    "Dropping accessory_presets update function"; then
    echo -e "${YELLOW}WARNING:${NC} Failed to drop accessory_presets update function (may not exist)"
fi

# 3D 모델 테이블 재생성
echo ""
echo "Recreating 3D model tables..."

# user_models 테이블 재생성
USER_MODELS_SQL="
CREATE TABLE IF NOT EXISTS user_models (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    model_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_size BIGINT,
    thumbnail_path VARCHAR(500),
    is_ai_generated BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, model_name)
);

CREATE INDEX IF NOT EXISTS idx_user_models_user_id ON user_models(user_id);
CREATE INDEX IF NOT EXISTS idx_user_models_name ON user_models(model_name);
CREATE INDEX IF NOT EXISTS idx_user_models_is_ai ON user_models(is_ai_generated);
CREATE INDEX IF NOT EXISTS idx_user_models_user_is_ai ON user_models(user_id, is_ai_generated);

DROP TRIGGER IF EXISTS update_model_timestamp ON user_models;
CREATE TRIGGER update_model_timestamp
    BEFORE UPDATE ON user_models
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
"

if ! execute_sql_command \
    "$USER_MODELS_SQL" \
    "$RESOURCE_DB_NAME" "$RESOURCE_DB_HOST" "$RESOURCE_DB_PORT" "$RESOURCE_DB_USER" \
    "Creating user_models table"; then
    echo -e "${RED}ERROR:${NC} Failed to create user_models table"
    exit 1
fi

# accessory_presets 테이블 재생성
ACCESSORY_PRESETS_SQL="
CREATE TABLE IF NOT EXISTS accessory_presets (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    preset_name VARCHAR(100) NOT NULL,
    description TEXT,
    file_path VARCHAR(500) NOT NULL,
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, preset_name)
);

CREATE OR REPLACE FUNCTION update_accessory_presets_updated_at()
RETURNS TRIGGER AS \$\$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
\$\$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_accessory_presets_updated_at
BEFORE UPDATE ON accessory_presets
FOR EACH ROW
EXECUTE FUNCTION update_accessory_presets_updated_at();

CREATE INDEX idx_accessory_presets_user_id ON accessory_presets(user_id);
CREATE INDEX idx_accessory_presets_is_public ON accessory_presets(is_public);
CREATE INDEX idx_accessory_presets_created_at ON accessory_presets(created_at DESC);
"

if ! execute_sql_command \
    "$ACCESSORY_PRESETS_SQL" \
    "$RESOURCE_DB_NAME" "$RESOURCE_DB_HOST" "$RESOURCE_DB_PORT" "$RESOURCE_DB_USER" \
    "Creating accessory_presets table"; then
    echo -e "${RED}ERROR:${NC} Failed to create accessory_presets table"
    exit 1
fi

echo -e "${GREEN}✓${NC} Resource Server 3D models reset complete"

# 데이터베이스 상태 확인
echo ""
echo "========================================"
echo "Database Status Check"
echo "========================================"

TABLE_COUNT=$(PGPASSWORD=$DB_PASSWORD psql -h "$RESOURCE_DB_HOST" -p "$RESOURCE_DB_PORT" -U "$RESOURCE_DB_USER" -d "$RESOURCE_DB_NAME" -tAc "
SELECT COUNT(*) FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
")

echo "Total tables in database: $TABLE_COUNT"

# 각 테이블의 레코드 수 확인
echo ""
echo "Table row counts:"

AUDIO_COUNT=$(PGPASSWORD=$DB_PASSWORD psql -h "$RESOURCE_DB_HOST" -p "$RESOURCE_DB_PORT" -U "$RESOURCE_DB_USER" -d "$RESOURCE_DB_NAME" -tAc "SELECT COUNT(*) FROM audio_files;")
echo "  - audio_files: $AUDIO_COUNT (유지됨)"

MODELS_COUNT=$(PGPASSWORD=$DB_PASSWORD psql -h "$RESOURCE_DB_HOST" -p "$RESOURCE_DB_PORT" -U "$RESOURCE_DB_USER" -d "$RESOURCE_DB_NAME" -tAc "SELECT COUNT(*) FROM user_models;")
echo "  - user_models: $MODELS_COUNT (초기화됨)"

PRESETS_COUNT=$(PGPASSWORD=$DB_PASSWORD psql -h "$RESOURCE_DB_HOST" -p "$RESOURCE_DB_PORT" -U "$RESOURCE_DB_USER" -d "$RESOURCE_DB_NAME" -tAc "SELECT COUNT(*) FROM accessory_presets;")
echo "  - accessory_presets: $PRESETS_COUNT (초기화됨)"

# ============================================
# 완료 메시지
# ============================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║         ✓  Resource DB 3D 모델 초기화 완료!  ✓             ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "초기화된 테이블:"
echo "  - user_models: 0개 (초기화됨)"
echo "  - accessory_presets: 0개 (초기화됨)"
echo ""
echo -e "${GREEN}audio_files 테이블의 음원 데이터는 그대로 유지되었습니다.${NC}"
echo ""
