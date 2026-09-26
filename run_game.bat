@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo   Starting Fairytale RPG / Skazki Korolevstva
echo ========================================================

set "GODOT_EXE=C:\Projects\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"

if not exist "!GODOT_EXE!" (
    set "GODOT_EXE=C:\Projects\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
)

if not exist "!GODOT_EXE!" (
    echo [ERROR] Godot executable not found!
    echo Looked at: C:\Projects\tools\godot-4.7.2\
    pause
    exit /b 1
)

echo Launching: !GODOT_EXE!
start "" "!GODOT_EXE!" --path "%~dp0."
exit /b 0