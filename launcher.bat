@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM SFDC DevOps Toolkit - Simple Launcher
REM Pure batch file launcher with no PowerShell dependencies
REM Version: 14.2.0
REM Author: Amit Bhardwaj (Enhanced for Production)
REM =============================================================================

title SFDC DevOps Toolkit Launcher v14.2.0
color 0F

echo.
echo    _____ _____ ____ ____     ___   _   _ 
echo  / ____^|  ___/ ___/ __ \   / _ \ ^| ^| ^(^)
echo ^| (___ ^| ^|__ \___ \ ^|  ^| ^| / /_\ \^| ^|  _ 
echo  \___ \^|  __^| __^)^| ^|  ^| ^| ^| ^|  _  ^| ^| ^| ^| ^|
echo  ____^)^| ^|___/ __/^| ^|__^| ^| ^| ^| ^| ^| ^| ^| ^| ^|
echo ^|_____/^|____^|____/\____/  ^|_^| ^|_^| ^|_^| ^|_^|
echo.
echo SFDC DevOps Toolkit - Pure Batch Version
echo Enhanced for Production Use
echo.

REM Set paths
set "TOOLKIT_ROOT=%~dp0"
set "MAIN_SCRIPT=%TOOLKIT_ROOT%sfdc-toolkit.bat"

REM Check if main script exists
if not exist "%MAIN_SCRIPT%" (
    echo ERROR: Main toolkit script not found!
    echo Expected location: %MAIN_SCRIPT%
    pause
    exit /b 1
)

echo Starting SFDC DevOps Toolkit...
echo.

REM Launch the main script
call "%MAIN_SCRIPT%" %*

echo.
echo SFDC DevOps Toolkit session ended.
pause
