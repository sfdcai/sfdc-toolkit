@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM SFDC DevOps Toolkit - Universal Launcher
REM Automatically detects the best execution method and launches the toolkit
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
echo  ____^)^| ^|___/ __/^| ^|__^| ^| ^| ^| ^| ^| ^| ^| ^|
echo ^|_____/^|____^|____/\____/  ^|_^| ^|_^| ^|_^| ^|_^|
echo.
echo SFDC DevOps Toolkit - Universal Launcher
echo Enhanced for Production Use - Cross-Windows Compatibility
echo.

REM Set paths
set "TOOLKIT_ROOT=%~dp0"
set "POWERSHELL_SCRIPT=%TOOLKIT_ROOT%sfdc-toolkit.ps1"
set "BATCH_SCRIPT=%TOOLKIT_ROOT%sfdc-toolkit-enhanced.bat"
set "BASIC_BATCH_SCRIPT=%TOOLKIT_ROOT%sfdc-toolkit.bat"

echo Detecting best execution method...
echo.

REM Check PowerShell availability and version
where powershell >nul 2>&1
if %errorlevel%==0 (
    echo   [*] PowerShell... [DETECTED]
    
    REM Check PowerShell version
    for /f "tokens=*" %%i in ('powershell "$PSVersionTable.PSVersion.Major"') do set "PS_VERSION=%%i"
    if !PS_VERSION! geq 5 (
        echo       Version: !PS_VERSION! - Compatible
        set "POWERSHELL_AVAILABLE=1"
    ) else (
        echo       Version: !PS_VERSION! - Incompatible (requires 5.0+)
        set "POWERSHELL_AVAILABLE=0"
    )
) else (
    echo   [*] PowerShell... [NOT FOUND]
    set "POWERSHELL_AVAILABLE=0"
)

REM Check execution policy
if "%POWERSHELL_AVAILABLE%"=="1" (
    for /f "tokens=*" %%i in ('powershell "Get-ExecutionPolicy"') do set "EXECUTION_POLICY=%%i"
    echo       Execution Policy: %EXECUTION_POLICY%
    
    if "%EXECUTION_POLICY%"=="Restricted" (
        echo       WARNING: Execution policy is restricted
        set "EXECUTION_POLICY_ISSUE=1"
    ) else (
        set "EXECUTION_POLICY_ISSUE=0"
    )
) else (
    set "EXECUTION_POLICY_ISSUE=0"
)

REM Check if scripts exist
if exist "%POWERSHELL_SCRIPT%" (
    echo   [*] PowerShell Script... [FOUND]
    set "PS_SCRIPT_EXISTS=1"
) else (
    echo   [*] PowerShell Script... [NOT FOUND]
    set "PS_SCRIPT_EXISTS=0"
)

if exist "%BATCH_SCRIPT%" (
    echo   [*] Enhanced Batch Script... [FOUND]
    set "ENHANCED_BATCH_EXISTS=1"
) else (
    echo   [*] Enhanced Batch Script... [NOT FOUND]
    set "ENHANCED_BATCH_EXISTS=0"
)

if exist "%BASIC_BATCH_SCRIPT%" (
    echo   [*] Basic Batch Script... [FOUND]
    set "BASIC_BATCH_EXISTS=1"
) else (
    echo   [*] Basic Batch Script... [NOT FOUND]
    set "BASIC_BATCH_EXISTS=0"
)

echo.

REM Determine best execution method
set "EXECUTION_METHOD="

if "%POWERSHELL_AVAILABLE%"=="1" if "%EXECUTION_POLICY_ISSUE%"=="0" if "%PS_SCRIPT_EXISTS%"=="1" (
    set "EXECUTION_METHOD=POWERSHELL"
    echo Recommended execution method: PowerShell (Enhanced Features)
) else if "%ENHANCED_BATCH_EXISTS%"=="1" (
    set "EXECUTION_METHOD=ENHANCED_BATCH"
    echo Recommended execution method: Enhanced Batch (Full Features)
) else if "%BASIC_BATCH_EXISTS%"=="1" (
    set "EXECUTION_METHOD=BASIC_BATCH"
    echo Recommended execution method: Basic Batch (Core Features)
) else (
    set "EXECUTION_METHOD=NONE"
    echo ERROR: No compatible toolkit scripts found!
    pause
    exit /b 1
)

echo.

REM Handle execution policy issues
if "%POWERSHELL_AVAILABLE%"=="1" if "%EXECUTION_POLICY_ISSUE%"=="1" (
    echo WARNING: PowerShell execution policy is restricted.
    echo.
    echo You can either:
    echo   1. Run the batch version (recommended for restricted environments)
    echo   2. Change the execution policy (requires administrator privileges)
    echo.
    set /p "POLICY_CHOICE=Choose option (1 for batch, 2 to change policy, or Enter to continue with batch): "
    
    if "%POLICY_CHOICE%"=="2" (
        echo.
        echo Changing execution policy to RemoteSigned...
        powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"
        if %errorlevel%==0 (
            echo Execution policy changed successfully.
            set "EXECUTION_METHOD=POWERSHELL"
        ) else (
            echo Failed to change execution policy. Using batch version.
            set "EXECUTION_METHOD=ENHANCED_BATCH"
        )
    ) else (
        set "EXECUTION_METHOD=ENHANCED_BATCH"
    )
    echo.
)

REM Show execution options
echo Available execution options:
echo.
if "%POWERSHELL_AVAILABLE%"=="1" if "%PS_SCRIPT_EXISTS%"=="1" (
    echo   [1] PowerShell Version (Enhanced Features, Best Performance)
)
if "%ENHANCED_BATCH_EXISTS%"=="1" (
    echo   [2] Enhanced Batch Version (Full Features, Good Compatibility)
)
if "%BASIC_BATCH_EXISTS%"=="1" (
    echo   [3] Basic Batch Version (Core Features, Maximum Compatibility)
)
echo   [A] Auto-select (Recommended)
echo.

set /p "USER_CHOICE=Select execution method (or press Enter for auto-select): "

if "%USER_CHOICE%"=="1" if "%POWERSHELL_AVAILABLE%"=="1" if "%PS_SCRIPT_EXISTS%"=="1" (
    set "EXECUTION_METHOD=POWERSHELL"
) else if "%USER_CHOICE%"=="2" if "%ENHANCED_BATCH_EXISTS%"=="1" (
    set "EXECUTION_METHOD=ENHANCED_BATCH"
) else if "%USER_CHOICE%"=="3" if "%BASIC_BATCH_EXISTS%"=="1" (
    set "EXECUTION_METHOD=BASIC_BATCH"
) else if "%USER_CHOICE%"=="A" (
    REM Keep the auto-selected method
) else if not "%USER_CHOICE%"=="" (
    echo Invalid choice. Using auto-selected method.
)

echo.
echo Launching SFDC DevOps Toolkit...
echo Execution Method: %EXECUTION_METHOD%
echo.

REM Execute the selected method
if "%EXECUTION_METHOD%"=="POWERSHELL" (
    echo Starting PowerShell version...
    powershell -ExecutionPolicy Bypass -File "%POWERSHELL_SCRIPT%"
) else if "%EXECUTION_METHOD%"=="ENHANCED_BATCH" (
    echo Starting Enhanced Batch version...
    call "%BATCH_SCRIPT%"
) else if "%EXECUTION_METHOD%"=="BASIC_BATCH" (
    echo Starting Basic Batch version...
    call "%BASIC_BATCH_SCRIPT%"
) else (
    echo ERROR: No valid execution method available!
    pause
    exit /b 1
)

echo.
echo SFDC DevOps Toolkit session ended.
pause
