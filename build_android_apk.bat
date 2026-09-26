@echo off
setlocal enabledelayedexpansion

set "GODOT_EXE=C:\Projects\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
if not exist "!GODOT_EXE!" (
    set "GODOT_EXE=C:\Projects\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
)
set "ADB_EXE=C:\Users\ibrog\AppData\Local\Android\Sdk\platform-tools\adb.exe"

echo ===================================================================
echo    Building Android APK: Fairytale RPG
echo ===================================================================

if not exist "builds" mkdir builds

echo [1/3] Compiling and exporting APK with Godot...
"!GODOT_EXE!" --headless --path "%~dp0." --export-debug "Android" "%~dp0builds\fairytale_rpg.apk"
if errorlevel 1 (
    echo [ERROR] APK Export failed!
    pause
    exit /b 1
)

if not exist "%~dp0builds\fairytale_rpg.apk" (
    echo [ERROR] File builds\fairytale_rpg.apk was not found!
    pause
    exit /b 1
)

echo [2/3] APK successfully built at:
echo %~dp0builds\fairytale_rpg.apk
echo.

echo [3/3] Checking connected Android devices via ADB...
if exist "!ADB_EXE!" (
    "!ADB_EXE!" devices
    echo.
    set /p INSTALL_CHOICE="Install now to connected phone? (y/n): "
    if /i "!INSTALL_CHOICE!"=="y" (
        echo Installing onto device...
        "!ADB_EXE!" install -r "%~dp0builds\fairytale_rpg.apk"
        echo Launching app...
        "!ADB_EXE!" shell am start -n org.antigravity.fairytale_rpg/com.godot.game.GodotApp
    )
) else (
    echo ADB not found, but APK is ready in builds\ folder.
)

echo.
echo ===================================================================
echo How to install manually:
echo 1. Copy builds\fairytale_rpg.apk to your phone (USB, Telegram, Drive)
echo 2. Tap on the APK file on phone to install
echo ===================================================================
pause
exit /b 0