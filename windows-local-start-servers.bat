@echo off
cd /d "%~dp0"

echo ========================================
echo Start MVE servers...

start "Login Server" /d "%~dp0mve-login-server" start-login-server.bat
start "Resource Server" /d "%~dp0mve-resource-server" start-resource-server.bat

echo All server execution commands have been sent.
echo This window will be shut down in 10 sec...
echo ========================================

timeout /t 10
