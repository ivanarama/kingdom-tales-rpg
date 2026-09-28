@echo off
setlocal enabledelayedexpansion

rem ========================================================
rem  Test gate: run the suite as a SCENE (autoloads required)
rem  and grep the output — Godot may exit with code 0 even
rem  when scripts fail to compile, so exit codes are not safe.
rem ========================================================

set "GODOT_EXE=C:\Projects\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
set "LOG=%TEMP%\skazki_tests.log"

if not exist "%GODOT_EXE%" (
    echo [ERROR] Godot executable not found: %GODOT_EXE%
    exit /b 1
)

echo Running test suite (headless scene^)...
"%GODOT_EXE%" --headless --path "%~dp0." res://tests/test_runner.tscn --quit-after 200000 > "%LOG%" 2>&1

findstr /C:"TEST SUITES PASSED" "%LOG%" >nul
if errorlevel 1 (
    echo [FAILED] Test suite did not report success. Output:
    type "%LOG%"
    exit /b 1
)

findstr /C:"SCRIPT ERROR" /C:"Assertion failed" /C:"Parse Error" "%LOG%" >nul
if not errorlevel 1 (
    echo [FAILED] Errors found in test run. Output:
    type "%LOG%"
    exit /b 1
)

echo [PASSED] Test suite passed (all suites reported success).
exit /b 0
