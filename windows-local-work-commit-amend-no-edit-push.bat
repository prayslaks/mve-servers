@echo off
chcp 65001 >nul
echo.
echo ============================================================
echo.
echo            MVE 커밋 수정 및 푸시 (Windows 로컬)         
echo.
echo ============================================================
echo.

echo [1/3] Login Server 작업 중...
cd ./mve-login-server
git add . >nul 2>&1
git commit --amend --no-edit >nul 2>&1
git push -f origin main >nul 2>&1
if errorlevel 1 (
    echo [✗] Login Server 실패
    cd ..
    pause
    exit /b 1
) else (
    echo [✓] Login Server 완료
)
cd ..

echo.
echo [2/3] Resource Server 작업 중...
cd ./mve-resource-server
git add . >nul 2>&1
git commit --amend --no-edit >nul 2>&1
git push -f origin main >nul 2>&1
if errorlevel 1 (
    echo [✗] Resource Server 실패
    cd ..
    pause
    exit /b 1
) else (
    echo [✓] Resource Server 완료
)
cd ..

echo.
echo [3/3] 메인 레포지토리 작업 중...
git add . >nul 2>&1
git commit --amend --no-edit >nul 2>&1
git push -f origin main >nul 2>&1
if errorlevel 1 (
    echo [✗] 메인 레포지토리 실패
    pause
    exit /b 1
) else (
    echo [✓] 메인 레포지토리 완료
)

echo.
echo ============================================================
echo.
echo                   ✓  모든 작업 완료!  ✓
echo.
echo ============================================================
echo.
pause
