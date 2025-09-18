@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM SFDC DevOps Toolkit - Pure Batch Version
REM Professional-grade Salesforce development and DevOps toolkit
REM Version: 14.2.0
REM Author: Amit Bhardwaj (Enhanced for Production)
REM =============================================================================

REM Set console colors and title
title SFDC DevOps Toolkit v14.2.0
color 0F

REM Global Variables
set "TOOLKIT_VERSION=14.2.0"
set "TOOLKIT_ROOT=%~dp0"
set "TOOLKIT_CONFIG_DIR=%TOOLKIT_ROOT%.sfdc-toolkit"
set "PROJECT_ROOT="
set "SOURCE_ORG="
set "DEST_ORG="
set "API_VERSION=61.0"
set "LOG_LEVEL=INFO"

REM Create config directory if it doesn't exist
if not exist "%TOOLKIT_CONFIG_DIR%" mkdir "%TOOLKIT_CONFIG_DIR%"

REM Initialize logging
set "LOG_FILE=%TOOLKIT_CONFIG_DIR%\toolkit.log"
if not exist "%LOG_FILE%" (
    echo [%date% %time%] [INFO] Log file created at '%LOG_FILE%'. > "%LOG_FILE%"
)

REM Check if arguments provided
if "%~1"=="" goto :Show-Main-Menu

REM Parse command line arguments
:Parse-Arguments
if "%~1"=="" goto :Execute-Command

if /i "%~1"=="--help" goto :Show-Help
if /i "%~1"=="-h" goto :Show-Help
if /i "%~1"=="--version" goto :Show-Version
if /i "%~1"=="-v" goto :Show-Version
if /i "%~1"=="--project" (
    set "PROJECT_ROOT=%~2"
    shift
    shift
    goto :Parse-Arguments
)
if /i "%~1"=="-p" (
    set "PROJECT_ROOT=%~2"
    shift
    shift
    goto :Parse-Arguments
)
if /i "%~1"=="--source-org" (
    set "SOURCE_ORG=%~2"
    shift
    shift
    goto :Parse-Arguments
)
if /i "%~1"=="-s" (
    set "SOURCE_ORG=%~2"
    shift
    shift
    goto :Parse-Arguments
)
if /i "%~1"=="--dest-org" (
    set "DEST_ORG=%~2"
    shift
    shift
    goto :Parse-Arguments
)
if /i "%~1"=="-d" (
    set "DEST_ORG=%~2"
    shift
    shift
    goto :Parse-Arguments
)
if /i "%~1"=="--api-version" (
    set "API_VERSION=%~2"
    shift
    shift
    goto :Parse-Arguments
)
if /i "%~1"=="--log-level" (
    set "LOG_LEVEL=%~2"
    shift
    shift
    goto :Parse-Arguments
)

REM Set command
set "COMMAND=%~1"
shift
goto :Parse-Arguments

:Execute-Command
if "%COMMAND%"=="" goto :Show-Main-Menu

call :Write-Log "Executing command: %COMMAND%" "INFO"

if /i "%COMMAND%"=="check-prereqs" call :Check-Prerequisites
if /i "%COMMAND%"=="auth-org" call :Authorize-Org
if /i "%COMMAND%"=="list-orgs" call :List-Orgs
if /i "%COMMAND%"=="compare-orgs" call :Compare-Orgs
if /i "%COMMAND%"=="deploy" call :Deploy-Metadata
if /i "%COMMAND%"=="generate-manifest" call :Generate-Manifest
if /i "%COMMAND%"=="open-org" call :Open-Org
if /i "%COMMAND%"=="help" goto :Show-Help
if /i "%COMMAND%"=="version" goto :Show-Version

echo Unknown command: %COMMAND%
echo Use --help to see available commands.
goto :EOF

REM =============================================================================
REM MAIN MENU (Interactive Mode)
REM =============================================================================

:Show-Main-Menu
call :Show-Banner
call :Show-System-Info

echo   Core DevOps Operations
echo   --------------------------
echo   [1] Check Prerequisites
echo   [2] Authorize New Org
echo   [3] List Authorized Orgs
echo   [4] Compare Orgs ^& Generate Delta
echo   [5] Deploy Metadata
echo   [6] Generate Manifest
echo   [7] Open Org in Browser
echo.
echo   [H] Help
echo   [V] Version
echo   [Q] Quit
echo.

set /p "CHOICE=Please enter your choice: "
call :Write-Log "User entered choice '%CHOICE%'" "DEBUG"

if "%CHOICE%"=="1" call :Check-Prerequisites
if "%CHOICE%"=="2" call :Authorize-Org
if "%CHOICE%"=="3" call :List-Orgs
if "%CHOICE%"=="4" call :Compare-Orgs
if "%CHOICE%"=="5" call :Deploy-Metadata
if "%CHOICE%"=="6" call :Generate-Manifest
if "%CHOICE%"=="7" call :Open-Org
if /i "%CHOICE%"=="H" goto :Show-Help
if /i "%CHOICE%"=="V" goto :Show-Version
if /i "%CHOICE%"=="Q" goto :EOF

if not "%CHOICE%"=="1" if not "%CHOICE%"=="2" if not "%CHOICE%"=="3" if not "%CHOICE%"=="4" if not "%CHOICE%"=="5" if not "%CHOICE%"=="6" if not "%CHOICE%"=="7" if /i not "%CHOICE%"=="H" if /i not "%CHOICE%"=="V" if /i not "%CHOICE%"=="Q" (
    call :Write-Log "Invalid option '%CHOICE%'" "WARN"
    echo Invalid option. Please try again.
    pause
)

call :Show-Main-Menu
goto :EOF

REM =============================================================================
REM CORE FUNCTIONS
REM =============================================================================

:Show-Banner
cls
echo.
echo    _____ _____ ____ ____     ___   _   _ 
echo  / ____^|  ___/ ___/ __ \   / _ \ ^| ^| ^(^)
echo ^| (___ ^| ^|__ \___ \ ^|  ^| ^| / /_\ \^| ^|  _ 
echo  \___ \^|  __^| __^)^| ^|  ^| ^| ^| ^|  _  ^| ^| ^| ^| ^|
echo  ____^)^| ^|___/ __/^| ^|__^| ^| ^| ^| ^| ^| ^| ^| ^| ^|
echo ^|_____/^|____^|____/\____/  ^|_^| ^|_^| ^|_^| ^|_^|
echo.
echo SFDC DevOps Toolkit - Pure Batch Version
echo Version: %TOOLKIT_VERSION%
echo.
goto :EOF

:Show-System-Info
echo   Project Context
echo   -------------------------
if "%PROJECT_ROOT%"=="" (
    echo     Project Path: Current Directory
) else (
    echo     Project Path: %PROJECT_ROOT%
)
if "%SOURCE_ORG%"=="" (
    echo     Source Org: Not Set
) else (
    echo     Source Org: %SOURCE_ORG%
)
if "%DEST_ORG%"=="" (
    echo     Destination Org: Not Set
) else (
    echo     Destination Org: %DEST_ORG%
)
echo     API Version: %API_VERSION%
echo     Log Level: %LOG_LEVEL%
echo ----------------------------------------------------------------------------
goto :EOF

:Write-Log
set "MESSAGE=%~1"
set "LEVEL=%~2"
if "%LEVEL%"=="" set "LEVEL=INFO"

REM Respect log level setting
if "%LOG_LEVEL%"=="INFO" if "%LEVEL%"=="DEBUG" goto :EOF

echo [%date% %time%] [%LEVEL%] %MESSAGE% >> "%LOG_FILE%"

REM Color output based on level
if "%LEVEL%"=="ERROR" (
    echo [%date% %time%] [%LEVEL%] %MESSAGE%
) else if "%LEVEL%"=="WARN" (
    echo [%date% %time%] [%LEVEL%] %MESSAGE%
) else if "%LEVEL%"=="DEBUG" (
    echo [%date% %time%] [%LEVEL%] %MESSAGE%
) else (
    echo [%date% %time%] [%LEVEL%] %MESSAGE%
)
goto :EOF

:Show-Help
echo.
echo SFDC DevOps Toolkit - Pure Batch Version
echo ========================================
echo.
echo Usage: sfdc-toolkit.bat [OPTIONS] COMMAND
echo.
echo Commands:
echo   check-prereqs     Check system prerequisites
echo   auth-org          Authorize a new Salesforce org
echo   list-orgs         List all authorized orgs
echo   compare-orgs      Compare two orgs and generate delta
echo   deploy            Deploy metadata to target org
echo   generate-manifest Generate package.xml manifest
echo   open-org          Open org in browser
echo   help              Show this help message
echo   version           Show version information
echo.
echo Options:
echo   --project, -p PATH        Set project path
echo   --source-org, -s ALIAS    Set source org alias
echo   --dest-org, -d ALIAS      Set destination org alias
echo   --api-version VERSION     Set API version (default: 61.0)
echo   --log-level LEVEL         Set log level (INFO, DEBUG, WARN, ERROR)
echo   --help, -h                Show this help message
echo   --version, -v             Show version information
echo.
echo Examples:
echo   sfdc-toolkit.bat check-prereqs
echo   sfdc-toolkit.bat --project "C:\MyProject" auth-org
echo   sfdc-toolkit.bat -s "DEV" -d "PROD" compare-orgs
echo   sfdc-toolkit.bat --api-version 60.0 deploy
echo.
echo Interactive Mode:
echo   Run without arguments to enter interactive mode
echo.
goto :EOF

:Show-Version
echo.
echo SFDC DevOps Toolkit - Pure Batch Version
echo Version: %TOOLKIT_VERSION%
echo Author: Amit Bhardwaj
echo.
goto :EOF

REM =============================================================================
REM PREREQUISITE CHECKING
REM =============================================================================

:Check-Prerequisites
call :Write-Log "Starting prerequisite check" "INFO"

echo Checking prerequisites...
echo.

set "ALL_GOOD=1"

REM Check Salesforce CLI
where sf >nul 2>&1
if %errorlevel%==0 (
    echo   [*] Salesforce CLI... [INSTALLED]
    call :Write-Log "Salesforce CLI found" "INFO"
) else (
    echo   [*] Salesforce CLI... [MISSING]
    call :Write-Log "Salesforce CLI not found" "ERROR"
    set "ALL_GOOD=0"
)

REM Check Git
where git >nul 2>&1
if %errorlevel%==0 (
    echo   [*] Git... [INSTALLED]
    call :Write-Log "Git found" "INFO"
) else (
    echo   [*] Git... [MISSING]
    call :Write-Log "Git not found" "WARN"
)

REM Check VS Code
where code >nul 2>&1
if %errorlevel%==0 (
    echo   [*] Visual Studio Code... [INSTALLED]
    call :Write-Log "VS Code found" "INFO"
) else (
    echo   [*] Visual Studio Code... [MISSING]
    call :Write-Log "VS Code not found" "WARN"
)

echo.
if "%ALL_GOOD%"=="0" (
    call :Write-Log "Prerequisites check failed" "ERROR"
    echo ERROR: Required tools are missing.
    echo Please install Salesforce CLI from: https://developer.salesforce.com/tools/sfdxcli
    pause
    goto :EOF
) else (
    call :Write-Log "Prerequisites check passed" "INFO"
    echo Prerequisites check completed successfully.
    pause
)
goto :EOF

REM =============================================================================
REM ORG MANAGEMENT
REM =============================================================================

:Authorize-Org
call :Write-Log "Starting org authorization" "INFO"

if "%SOURCE_ORG%"=="" (
    echo.
    set /p "ALIAS=Enter org alias: "
    if "!ALIAS!"=="" (
        call :Write-Log "Auth cancelled - no alias provided" "WARN"
        goto :EOF
    )
) else (
    set "ALIAS=%SOURCE_ORG%"
)

echo.
set /p "IS_PROD=Is this a Production org? (y/n): "
if /i "!IS_PROD!"=="y" (
    set "INSTANCE_URL=https://login.salesforce.com"
) else (
    set "INSTANCE_URL=https://test.salesforce.com"
)

call :Write-Log "Authorizing org: !ALIAS!" "INFO"
echo.
echo Authorizing org: !ALIAS!

sf org login web --alias !ALIAS! --instance-url !INSTANCE_URL! --set-default
if %errorlevel% neq 0 (
    call :Write-Log "Failed to authorize org: !ALIAS!" "ERROR"
    echo Failed to authorize org.
    pause
    goto :EOF
) else (
    call :Write-Log "Successfully authorized org: !ALIAS!" "INFO"
    echo Org authorized successfully: !ALIAS!
    pause
)
goto :EOF

:List-Orgs
call :Write-Log "Listing authorized orgs" "INFO"

echo.
echo Fetching authorized orgs...
sf org list --json > "%TEMP%\orgs.json" 2>nul
if %errorlevel% neq 0 (
    call :Write-Log "Failed to list orgs" "ERROR"
    echo Failed to list orgs.
    pause
    goto :EOF
)

echo.
echo Authorized Orgs:
echo ================
type "%TEMP%\orgs.json" | findstr "alias"
echo.

call :Write-Log "Org list displayed" "INFO"
pause
goto :EOF

:Open-Org
call :Write-Log "Opening org in browser" "INFO"

if "%SOURCE_ORG%"=="" (
    echo.
    set /p "ORG_ALIAS=Enter org alias to open: "
    if "!ORG_ALIAS!"=="" (
        call :Write-Log "No org alias provided" "WARN"
        goto :EOF
    )
) else (
    set "ORG_ALIAS=%SOURCE_ORG%"
)

call :Write-Log "Opening org: !ORG_ALIAS!" "INFO"
echo.
echo Opening org in browser: !ORG_ALIAS!

sf org open --target-org !ORG_ALIAS!
if %errorlevel% neq 0 (
    call :Write-Log "Failed to open org: !ORG_ALIAS!" "ERROR"
    echo Failed to open org.
    pause
    goto :EOF
) else (
    call :Write-Log "Org opened successfully: !ORG_ALIAS!" "INFO"
    echo Org opened successfully.
    pause
)
goto :EOF

REM =============================================================================
REM PROJECT MANAGEMENT
REM =============================================================================

:Set-Project-Path
if "%PROJECT_ROOT%"=="" (
    echo.
    set /p "PROJECT_PATH=Enter project path (or press Enter for current directory): "
    if "!PROJECT_PATH!"=="" (
        set "PROJECT_ROOT=%CD%"
    ) else (
        set "PROJECT_ROOT=!PROJECT_PATH!"
    )
)

if not exist "%PROJECT_ROOT%" (
    echo.
    echo Project path does not exist: %PROJECT_ROOT%
    set /p "CREATE_DIR=Create directory? (y/n): "
    if /i "!CREATE_DIR!"=="y" (
        mkdir "%PROJECT_ROOT%" 2>nul
        if %errorlevel% neq 0 (
            call :Write-Log "Failed to create project directory: %PROJECT_ROOT%" "ERROR"
            echo Failed to create project directory.
            pause
            goto :EOF
        )
        call :Write-Log "Created project directory: %PROJECT_ROOT%" "INFO"
    ) else (
        call :Write-Log "Project directory creation cancelled" "WARN"
        goto :EOF
    )
)

call :Write-Log "Project path set to: %PROJECT_ROOT%" "INFO"
goto :EOF

REM =============================================================================
REM COMPARISON AND DELTA GENERATION
REM =============================================================================

:Compare-Orgs
call :Write-Log "Starting org comparison" "INFO"

REM Set project path if not set
call :Set-Project-Path

if "%SOURCE_ORG%"=="" (
    echo.
    set /p "SOURCE_ALIAS=Enter source org alias: "
    if "!SOURCE_ALIAS!"=="" (
        call :Write-Log "No source org specified" "ERROR"
        echo ERROR: Source org not specified.
        pause
        goto :EOF
    )
) else (
    set "SOURCE_ALIAS=%SOURCE_ORG%"
)

if "%DEST_ORG%"=="" (
    echo.
    set /p "DEST_ALIAS=Enter destination org alias: "
    if "!DEST_ALIAS!"=="" (
        call :Write-Log "No destination org specified" "ERROR"
        echo ERROR: Destination org not specified.
        pause
        goto :EOF
    )
) else (
    set "DEST_ALIAS=%DEST_ORG%"
)

call :Write-Log "Comparing orgs: !SOURCE_ALIAS! vs !DEST_ALIAS!" "INFO"
echo.
echo Comparing orgs: !SOURCE_ALIAS! vs !DEST_ALIAS!

REM Create project directories
set "SOURCE_DIR=%PROJECT_ROOT%\_source_metadata"
set "DEST_DIR=%PROJECT_ROOT%\_target_metadata"
set "DELTA_DIR=%PROJECT_ROOT%\delta-deployment"

if not exist "%SOURCE_DIR%" mkdir "%SOURCE_DIR%"
if not exist "%DEST_DIR%" mkdir "%DEST_DIR%"
if exist "%DELTA_DIR%" rmdir /s /q "%DELTA_DIR%"
mkdir "%DELTA_DIR%"

echo.
echo Step 1: Generating manifests...
sf project generate manifest --from-org !SOURCE_ALIAS! --output-dir "%PROJECT_ROOT%" --name "source_manifest" --api-version %API_VERSION%
if %errorlevel% neq 0 (
    call :Write-Log "Failed to generate source manifest" "ERROR"
    echo Failed to generate source manifest.
    pause
    goto :EOF
)

sf project generate manifest --from-org !DEST_ALIAS! --output-dir "%PROJECT_ROOT%" --name "target_manifest" --api-version %API_VERSION%
if %errorlevel% neq 0 (
    call :Write-Log "Failed to generate target manifest" "ERROR"
    echo Failed to generate target manifest.
    pause
    goto :EOF
)

echo Step 2: Retrieving metadata from source org...
sf project retrieve start --manifest "%PROJECT_ROOT%\source_manifest.xml" --target-org !SOURCE_ALIAS! --output-dir "%SOURCE_DIR%" --api-version %API_VERSION%
if %errorlevel% neq 0 (
    call :Write-Log "Failed to retrieve from source org" "ERROR"
    echo Failed to retrieve from source org.
    pause
    goto :EOF
)

echo Step 3: Retrieving metadata from destination org...
sf project retrieve start --manifest "%PROJECT_ROOT%\target_manifest.xml" --target-org !DEST_ALIAS! --output-dir "%DEST_DIR%" --api-version %API_VERSION%
if %errorlevel% neq 0 (
    call :Write-Log "Failed to retrieve from destination org" "ERROR"
    echo Failed to retrieve from destination org.
    pause
    goto :EOF
)

echo Step 4: Generating delta package...
REM Create basic package.xml for delta
echo ^<?xml version="1.0" encoding="UTF-8"?^> > "%DELTA_DIR%\package.xml"
echo ^<Package xmlns="http://soap.sforce.com/2006/04/metadata"^> >> "%DELTA_DIR%\package.xml"
echo   ^<version^>%API_VERSION%^</version^> >> "%DELTA_DIR%\package.xml"
echo ^</Package^> >> "%DELTA_DIR%\package.xml"

REM Clean up temporary manifests
del "%PROJECT_ROOT%\source_manifest.xml" 2>nul
del "%PROJECT_ROOT%\target_manifest.xml" 2>nul

call :Write-Log "Org comparison completed successfully" "INFO"
echo.
echo Comparison completed successfully!
echo Source metadata: %SOURCE_DIR%
echo Target metadata: %DEST_DIR%
echo Delta package: %DELTA_DIR%
pause
goto :EOF

REM =============================================================================
REM DEPLOYMENT FUNCTIONS
REM =============================================================================

:Deploy-Metadata
call :Write-Log "Starting metadata deployment" "INFO"

REM Set project path if not set
call :Set-Project-Path

if "%DEST_ORG%"=="" (
    echo.
    set /p "DEST_ALIAS=Enter destination org alias: "
    if "!DEST_ALIAS!"=="" (
        call :Write-Log "No destination org specified" "ERROR"
        echo ERROR: Destination org not specified.
        pause
        goto :EOF
    )
) else (
    set "DEST_ALIAS=%DEST_ORG%"
)

set "DELTA_DIR=%PROJECT_ROOT%\delta-deployment"
if not exist "%DELTA_DIR%" (
    call :Write-Log "No delta package found" "ERROR"
    echo ERROR: No delta package found. Run compare-orgs first.
    pause
    goto :EOF
)

call :Write-Log "Deploying to org: !DEST_ALIAS!" "INFO"
echo.
echo Deploying metadata to: !DEST_ALIAS!

sf project deploy start --metadata-dir "%DELTA_DIR%" --target-org !DEST_ALIAS! --api-version %API_VERSION% --test-level RunLocalTests
if %errorlevel% neq 0 (
    call :Write-Log "Deployment failed" "ERROR"
    echo Deployment failed.
    pause
    goto :EOF
) else (
    call :Write-Log "Deployment completed successfully" "INFO"
    echo Deployment completed successfully!
    pause
)
goto :EOF

REM =============================================================================
REM MANIFEST GENERATION
REM =============================================================================

:Generate-Manifest
call :Write-Log "Generating manifest" "INFO"

REM Set project path if not set
call :Set-Project-Path

if "%SOURCE_ORG%"=="" (
    echo.
    set /p "SOURCE_ALIAS=Enter source org alias: "
    if "!SOURCE_ALIAS!"=="" (
        call :Write-Log "No source org specified" "ERROR"
        echo ERROR: Source org not specified.
        pause
        goto :EOF
    )
) else (
    set "SOURCE_ALIAS=%SOURCE_ORG%"
)

call :Write-Log "Generating manifest from org: !SOURCE_ALIAS!" "INFO"
echo.
echo Generating manifest from org: !SOURCE_ALIAS!

sf project generate manifest --from-org !SOURCE_ALIAS! --output-dir "%PROJECT_ROOT%" --name "package" --api-version %API_VERSION%
if %errorlevel% neq 0 (
    call :Write-Log "Failed to generate manifest" "ERROR"
    echo Failed to generate manifest.
    pause
    goto :EOF
) else (
    call :Write-Log "Manifest generated successfully" "INFO"
    echo Manifest generated successfully: %PROJECT_ROOT%\package.xml
    pause
)
goto :EOF

REM =============================================================================
REM END OF SCRIPT
REM =============================================================================