@echo off
chcp 65001 >nul
echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║                                                            ║
echo ║              MVE 서버 Pull (Windows 로컬)                  ║
echo ║                                                            ║
echo ╚════════════════════════════════════════════════════════════╝
echo.

echo [1/4] 원격 저장소에서 최신 변경사항 가져오는 중...
git fetch --all
if errorlevel 1 (
    echo [오류] Git fetch 실패
    pause
    exit /b 1
)

echo.
echo [2/4] 최신 변경사항 풀링 중...
git pull --recurse-submodules
if errorlevel 1 (
    echo [오류] Git pull 실패
    pause
    exit /b 1
)

echo.
echo [3/4] Git 서브모듈 업데이트 중...
git submodule update --init --recursive
if errorlevel 1 (
    echo [오류] 서브모듈 업데이트 실패
    pause
    exit /b 1
)

echo.
echo [4/4] 서브모듈 최신 상태 확인...
cd mve-login-server
git status
cd ..
echo.
cd mve-resource-server
git status
cd ..

echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║                                                            ║
echo ║              ✓  Pull 완료!  ✓                              ║
echo ║                                                            ║
echo ╚════════════════════════════════════════════════════════════╝
echo.
pause
