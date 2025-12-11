@echo off
cd /d "%~dp0"
cd ..

echo ========================================
echo Start MVE servers...

start "Login Server" /d "%~dp0..\mve-login-server" start-login-server.bat
start "Resource Server" /d "%~dp0..\mve-resource-server" start-resource-server.bat

echo All server execution commands have been sent.
echo This window will be shut down in 10 sec...
echo ========================================

timeout /t 10
