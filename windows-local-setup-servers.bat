@echo off
cd /d "%~dp0"

echo ========================================
echo Setup MVE servers...

start "Login Server Setup" /d "%~dp0mve-login-server" setup-login-server.bat
start "Resource Server Setup" /d "%~dp0mve-resource-server" setup-resource-server.bat

echo All server Setup commands have been sent.
echo This window will be shut down in 10 sec...
echo ========================================

timeout /t 10
