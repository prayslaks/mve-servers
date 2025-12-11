@echo off
cd /d "%~dp0"
cd ..

echo ========================================
echo Setup MVE servers on Windows...
echo ========================================

echo.
echo [1/5] Fetching latest changes...
git fetch --all

echo.
echo [2/5] Pulling latest changes...
git pull

echo.
echo [3/5] Updating git submodules...
git submodule update --init --recursive

echo.
echo [4/5] Installing Login Server dependencies...
cd mve-login-server
call npm install
cd ..

echo.
echo [5/5] Installing Resource Server dependencies...
cd mve-resource-server
call npm install
cd ..

echo.
echo ========================================
echo Setup complete!
echo ========================================

timeout /t 10
