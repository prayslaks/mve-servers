@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

REM MVE Servers - Resource DB 3D Models Only Reset Script (Development용)
REM
REM 이 스크립트는 resourcedb의 3D 모델 관련 테이블만 초기화합니다.
REM - user_models (유저별 3D 모델)
REM - accessory_presets (액세서리 프리셋)
REM audio_files (음원 데이터)는 그대로 유지됩니다.
REM
REM 사용법:
REM   dev-reset-resourcedb-models.bat

cd /d "%~dp0"
cd ..

echo.
echo ============================================================
echo.
echo          개발용 Resource DB 3D 모델 초기화 스크립트
echo.
echo ============================================================
echo.
echo 이 스크립트는 resourcedb의 3D 모델 테이블만 초기화합니다.
echo.
echo [초기화 대상]
echo   - user_models (유저별 3D 모델)
echo   - accessory_presets (액세서리 프리셋)
echo.
echo [유지되는 데이터]
echo   - audio_files (음원 데이터)
echo.
echo [경고] 모든 유저의 3D 모델과 액세서리 프리셋이 삭제됩니다!
echo.

set /p confirmation="계속하시겠습니까? (y/N): "

if /i not "%confirmation%"=="y" (
    echo 작업이 취소되었습니다.
    exit /b 0
)

echo.
echo Resource DB 3D 모델 초기화를 시작합니다...
echo.

REM ============================================
REM Resource Server Database 3D Models Reset
REM ============================================
echo.
echo ========================================
echo Resource Server 3D Models Reset
echo ========================================

if not exist "mve-resource-server\.env" (
    echo [오류] Environment file not found: mve-resource-server\.env
    exit /b 1
)

echo [✓] Loading environment from: mve-resource-server\.env

REM Load environment variables from .env file
for /f "usebackq tokens=1,* delims==" %%a in ("mve-resource-server\.env") do (
    set "line=%%a"
    if not "!line:~0,1!"=="#" (
        if not "%%b"=="" (
            set "%%a=%%b"
        )
    )
)

if "%DB_HOST%"=="" set DB_HOST=localhost
if "%DB_PORT%"=="" set DB_PORT=5432

echo Database: %DB_NAME%
echo Host: %DB_HOST%:%DB_PORT%
echo.

REM Test PostgreSQL connection
echo Testing PostgreSQL connection...
set PGPASSWORD=%DB_PASSWORD%
psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d postgres -c "\q" 2>nul
if errorlevel 1 (
    echo [✗] Cannot connect to PostgreSQL
    exit /b 1
)
echo [✓] Connected

REM Drop 3D model tables
echo.
echo Dropping 3D model tables...

psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d %DB_NAME% -c "DROP TABLE IF EXISTS accessory_presets CASCADE;" >nul 2>&1
if errorlevel 1 (
    echo [✗] Failed to drop accessory_presets table
    exit /b 1
)
echo [✓] Dropping accessory_presets table

psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d %DB_NAME% -c "DROP TABLE IF EXISTS user_models CASCADE;" >nul 2>&1
if errorlevel 1 (
    echo [✗] Failed to drop user_models table
    exit /b 1
)
echo [✓] Dropping user_models table

psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d %DB_NAME% -c "DROP FUNCTION IF EXISTS update_accessory_presets_updated_at() CASCADE;" >nul 2>&1
echo [✓] Dropping accessory_presets update function

REM Recreate 3D model tables
echo.
echo Recreating 3D model tables...

REM Create user_models table
psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d %DB_NAME% -c "CREATE TABLE IF NOT EXISTS user_models (id SERIAL PRIMARY KEY, user_id INTEGER NOT NULL, model_name VARCHAR(255) NOT NULL, file_path VARCHAR(500) NOT NULL, file_size BIGINT, thumbnail_path VARCHAR(500), is_ai_generated BOOLEAN DEFAULT FALSE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, UNIQUE(user_id, model_name)); CREATE INDEX IF NOT EXISTS idx_user_models_user_id ON user_models(user_id); CREATE INDEX IF NOT EXISTS idx_user_models_name ON user_models(model_name); CREATE INDEX IF NOT EXISTS idx_user_models_is_ai ON user_models(is_ai_generated); CREATE INDEX IF NOT EXISTS idx_user_models_user_is_ai ON user_models(user_id, is_ai_generated); DROP TRIGGER IF EXISTS update_model_timestamp ON user_models; CREATE TRIGGER update_model_timestamp BEFORE UPDATE ON user_models FOR EACH ROW EXECUTE FUNCTION update_timestamp();" >nul 2>&1
if errorlevel 1 (
    echo [✗] Failed to create user_models table
    exit /b 1
)
echo [✓] Creating user_models table

REM Create accessory_presets table
psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d %DB_NAME% -c "CREATE TABLE IF NOT EXISTS accessory_presets (id SERIAL PRIMARY KEY, user_id INTEGER NOT NULL, preset_name VARCHAR(100) NOT NULL, description TEXT, file_path VARCHAR(500) NOT NULL, is_public BOOLEAN DEFAULT FALSE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, UNIQUE(user_id, preset_name)); CREATE OR REPLACE FUNCTION update_accessory_presets_updated_at() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = CURRENT_TIMESTAMP; RETURN NEW; END; $$ LANGUAGE plpgsql; CREATE TRIGGER trigger_update_accessory_presets_updated_at BEFORE UPDATE ON accessory_presets FOR EACH ROW EXECUTE FUNCTION update_accessory_presets_updated_at(); CREATE INDEX idx_accessory_presets_user_id ON accessory_presets(user_id); CREATE INDEX idx_accessory_presets_is_public ON accessory_presets(is_public); CREATE INDEX idx_accessory_presets_created_at ON accessory_presets(created_at DESC);" >nul 2>&1
if errorlevel 1 (
    echo [✗] Failed to create accessory_presets table
    exit /b 1
)
echo [✓] Creating accessory_presets table

echo [✓] Resource Server 3D models reset complete

REM Database status check
echo.
echo ========================================
echo Database Status Check
echo ========================================

for /f %%i in ('psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d %DB_NAME% -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';"') do set TABLE_COUNT=%%i
echo Total tables in database: %TABLE_COUNT%

echo.
echo Table row counts:

for /f %%i in ('psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d %DB_NAME% -tAc "SELECT COUNT(*) FROM audio_files;"') do set AUDIO_COUNT=%%i
echo   - audio_files: %AUDIO_COUNT% (유지됨)

for /f %%i in ('psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d %DB_NAME% -tAc "SELECT COUNT(*) FROM user_models;"') do set MODELS_COUNT=%%i
echo   - user_models: %MODELS_COUNT% (초기화됨)

for /f %%i in ('psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d %DB_NAME% -tAc "SELECT COUNT(*) FROM accessory_presets;"') do set PRESETS_COUNT=%%i
echo   - accessory_presets: %PRESETS_COUNT% (초기화됨)

REM Complete message
echo.
echo ============================================================
echo.
echo         ✓  Resource DB 3D 모델 초기화 완료!  ✓
echo.
echo ============================================================
echo.
echo 초기화된 테이블:
echo   - user_models: 0개 (초기화됨)
echo   - accessory_presets: 0개 (초기화됨)
echo.
echo audio_files 테이블의 음원 데이터는 그대로 유지되었습니다.
echo.

endlocal
