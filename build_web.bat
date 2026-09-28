@echo off
setlocal enabledelayedexpansion

set "GODOT_EXE=C:\Projects\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"

echo ===================================================================
echo    Building Web (WASM) export: Fairytale RPG
echo ===================================================================

if not exist "builds\web" mkdir "builds\web"

"!GODOT_EXE!" --headless --path "%~dp0." --export-release "Web" "%~dp0builds\web\index.html"
if errorlevel 1 (
    echo [ERROR] Web export failed!
    pause
    exit /b 1
)

echo.
echo [OK] Web build ready: builds\web\index.html
echo      Локальный запуск (например^):
echo      python -m http.server 8080 --directory builds\web
echo      затем откройте http://localhost:8080
pause
