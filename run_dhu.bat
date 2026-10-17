@echo off
title Android Auto Desktop Head Unit (DHU)
echo ==============================================
echo   Darb - Android Auto Desktop Head Unit (DHU)
echo ==============================================
echo.
echo [1/2] Forwarding port 5277 from connected phone...
"C:\Users\PC\AppData\Local\Android\Sdk\platform-tools\adb.exe" forward tcp:5277 tcp:5277

echo.
echo [2/2] Launching Google Desktop Head Unit window...
echo (The car screen will open in a separate window)
cd /d "C:\Users\PC\AppData\Local\Android\Sdk\extras\google\auto"
desktop-head-unit.exe -c config\default_720p.ini

pause
