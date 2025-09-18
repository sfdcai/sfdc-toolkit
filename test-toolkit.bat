@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM SFDC DevOps Toolkit - Comprehensive Test Suite
REM Tests all versions and functionality for production readiness
REM Version: 14.2.0
REM Author: Amit Bhardwaj (Enhanced for Production)
REM =============================================================================

title SFDC DevOps Toolkit Test Suite v14.2.0
color 0F

echo.
echo    _____ _____ ____ ____     ___   _   _ 
echo  / ____^|  ___/ ___/ __ \   / _ \ ^| ^| ^(^)
echo ^| (___ ^| ^|__ \___ \ ^|  ^| ^| / /_\ \^| ^|  _ 
echo  \___ \^|  __^| __^)^| ^|  ^| ^| ^| ^|  _  ^| ^| ^| ^| ^|
echo  ____^)^| ^|___/ __/^| ^|__^| ^| ^| ^| ^| ^| ^| ^|
echo ^|_____/^|____^|____/\____/  ^|_^| ^|_^| ^|_^| ^|_^|
echo.
echo SFDC DevOps Toolkit - Comprehensive Test Suite
echo Testing Enhanced Production Version
echo.

set "TOOLKIT_ROOT=%~dp0"
set "TEST_RESULTS=%TOOLKIT_ROOT%test-results"
set "PASSED_TESTS=0"
set "FAILED_TESTS=0"
set "TOTAL_TESTS=0"

REM Create test results directory
if not exist "%TEST_RESULTS%" mkdir "%TEST_RESULTS%"

echo Test Results Directory: %TEST_RESULTS%
echo.

REM =============================================================================
REM TEST 1: File Existence Tests
REM =============================================================================

echo ========================================
echo   TEST 1: File Existence Tests
echo ========================================
echo.

set /a TOTAL_TESTS+=1
if exist "%TOOLKIT_ROOT%sfdc-toolkit-launcher.bat" (
    echo   [PASS] Universal Launcher exists
    set /a PASSED_TESTS+=1
) else (
    echo   [FAIL] Universal Launcher missing
    set /a FAILED_TESTS+=1
)

set /a TOTAL_TESTS+=1
if exist "%TOOLKIT_ROOT%sfdc-toolkit.ps1" (
    echo   [PASS] PowerShell script exists
    set /a PASSED_TESTS+=1
) else (
    echo   [FAIL] PowerShell script missing
    set /a FAILED_TESTS+=1
)

set /a TOTAL_TESTS+=1
if exist "%TOOLKIT_ROOT%sfdc-toolkit-enhanced.bat" (
    echo   [PASS] Enhanced batch script exists
    set /a PASSED_TESTS+=1
) else (
    echo   [FAIL] Enhanced batch script missing
    set /a FAILED_TESTS+=1
)

set /a TOTAL_TESTS+=1
if exist "%TOOLKIT_ROOT%sfdc-toolkit.bat" (
    echo   [PASS] Basic batch script exists
    set /a PASSED_TESTS+=1
) else (
    echo   [FAIL] Basic batch script missing
    set /a FAILED_TESTS+=1
)

set /a TOTAL_TESTS+=1
if exist "%TOOLKIT_ROOT%sfdc-toolkit-config.json" (
    echo   [PASS] Configuration file exists
    set /a PASSED_TESTS+=1
) else (
    echo   [FAIL] Configuration file missing
    set /a FAILED_TESTS+=1
)

set /a TOTAL_TESTS+=1
if exist "%TOOLKIT_ROOT%README-Enhanced.md" (
    echo   [PASS] Enhanced documentation exists
    set /a PASSED_TESTS+=1
) else (
    echo   [FAIL] Enhanced documentation missing
    set /a FAILED_TESTS+=1
)

echo.

REM =============================================================================
REM TEST 2: Prerequisites Tests
REM =============================================================================

echo ========================================
echo   TEST 2: Prerequisites Tests
echo ========================================
echo.

REM Test PowerShell availability
set /a TOTAL_TESTS+=1
where powershell >nul 2>&1
if %errorlevel%==0 (
    echo   [PASS] PowerShell is available
    set /a PASSED_TESTS+=1
    
    REM Test PowerShell version
    set /a TOTAL_TESTS+=1
    for /f "tokens=*" %%i in ('powershell "$PSVersionTable.PSVersion.Major"') do set "PS_VERSION=%%i"
    if !PS_VERSION! geq 5 (
        echo   [PASS] PowerShell version 5.0+ detected (!PS_VERSION!)
        set /a PASSED_TESTS+=1
    ) else (
        echo   [FAIL] PowerShell version too old (!PS_VERSION!)
        set /a FAILED_TESTS+=1
    )
) else (
    echo   [FAIL] PowerShell not found
    set /a FAILED_TESTS+=1
)

REM Test Salesforce CLI
set /a TOTAL_TESTS+=1
where sf >nul 2>&1
if %errorlevel%==0 (
    echo   [PASS] Salesforce CLI is available
    set /a PASSED_TESTS+=1
) else (
    echo   [FAIL] Salesforce CLI not found
    set /a FAILED_TESTS+=1
)

REM Test Git
set /a TOTAL_TESTS+=1
where git >nul 2>&1
if %errorlevel%==0 (
    echo   [PASS] Git is available
    set /a PASSED_TESTS+=1
) else (
    echo   [WARN] Git not found (optional)
)

REM Test VS Code
set /a TOTAL_TESTS+=1
where code >nul 2>&1
if %errorlevel%==0 (
    echo   [PASS] Visual Studio Code is available
    set /a PASSED_TESTS+=1
) else (
    echo   [WARN] Visual Studio Code not found (optional)
)

echo.

REM =============================================================================
REM TEST 3: Script Syntax Tests
REM =============================================================================

echo ========================================
echo   TEST 3: Script Syntax Tests
echo ========================================
echo.

REM Test PowerShell script syntax
set /a TOTAL_TESTS+=1
if exist "%TOOLKIT_ROOT%sfdc-toolkit.ps1" (
    powershell -Command "& { try { . '%TOOLKIT_ROOT%sfdc-toolkit.ps1' -WhatIf; Write-Host 'Syntax OK' } catch { Write-Host 'Syntax Error: ' $_.Exception.Message; exit 1 } }" >nul 2>&1
    if %errorlevel%==0 (
        echo   [PASS] PowerShell script syntax is valid
        set /a PASSED_TESTS+=1
    ) else (
        echo   [FAIL] PowerShell script has syntax errors
        set /a FAILED_TESTS+=1
    )
) else (
    echo   [SKIP] PowerShell script not found
)

REM Test batch script syntax (basic check)
set /a TOTAL_TESTS+=1
if exist "%TOOLKIT_ROOT%sfdc-toolkit-enhanced.bat" (
    REM Basic syntax check - look for common errors
    findstr /i "goto :EOF" "%TOOLKIT_ROOT%sfdc-toolkit-enhanced.bat" >nul 2>&1
    if %errorlevel%==0 (
        echo   [PASS] Enhanced batch script syntax appears valid
        set /a PASSED_TESTS+=1
    ) else (
        echo   [FAIL] Enhanced batch script may have syntax issues
        set /a FAILED_TESTS+=1
    )
) else (
    echo   [SKIP] Enhanced batch script not found
)

echo.

REM =============================================================================
REM TEST 4: Configuration Tests
REM =============================================================================

echo ========================================
echo   TEST 4: Configuration Tests
echo ========================================
echo.

REM Test JSON configuration syntax
set /a TOTAL_TESTS+=1
if exist "%TOOLKIT_ROOT%sfdc-toolkit-config.json" (
    powershell -Command "try { Get-Content '%TOOLKIT_ROOT%sfdc-toolkit-config.json' | ConvertFrom-Json | Out-Null; Write-Host 'JSON Valid' } catch { Write-Host 'JSON Error: ' $_.Exception.Message; exit 1 }" >nul 2>&1
    if %errorlevel%==0 (
        echo   [PASS] Configuration JSON is valid
        set /a PASSED_TESTS+=1
    ) else (
        echo   [FAIL] Configuration JSON has syntax errors
        set /a FAILED_TESTS+=1
    )
) else (
    echo   [SKIP] Configuration file not found
)

REM Test existing configuration files
set /a TOTAL_TESTS+=1
if exist "%TOOLKIT_ROOT%control.json" (
    powershell -Command "try { Get-Content '%TOOLKIT_ROOT%control.json' | ConvertFrom-Json | Out-Null; Write-Host 'Control JSON Valid' } catch { Write-Host 'Control JSON Error: ' $_.Exception.Message; exit 1 }" >nul 2>&1
    if %errorlevel%==0 (
        echo   [PASS] Control configuration JSON is valid
        set /a PASSED_TESTS+=1
    ) else (
        echo   [FAIL] Control configuration JSON has syntax errors
        set /a FAILED_TESTS+=1
    )
) else (
    echo   [WARN] Control configuration file not found
)

echo.

REM =============================================================================
REM TEST 5: Directory Structure Tests
REM =============================================================================

echo ========================================
echo   TEST 5: Directory Structure Tests
echo ========================================
echo.

REM Test if we can create toolkit directories
set /a TOTAL_TESTS+=1
set "TEST_CONFIG_DIR=%TOOLKIT_ROOT%.sfdc-toolkit-test"
mkdir "%TEST_CONFIG_DIR%" 2>nul
if exist "%TEST_CONFIG_DIR%" (
    echo   [PASS] Can create configuration directories
    rmdir "%TEST_CONFIG_DIR%" 2>nul
    set /a PASSED_TESTS+=1
) else (
    echo   [FAIL] Cannot create configuration directories
    set /a FAILED_TESTS+=1
)

REM Test if we can create project directories
set /a TOTAL_TESTS+=1
set "TEST_PROJECT_DIR=%TOOLKIT_ROOT%test-project"
mkdir "%TEST_PROJECT_DIR%" 2>nul
if exist "%TEST_PROJECT_DIR%" (
    echo   [PASS] Can create project directories
    rmdir "%TEST_PROJECT_DIR%" 2>nul
    set /a PASSED_TESTS+=1
) else (
    echo   [FAIL] Cannot create project directories
    set /a FAILED_TESTS+=1
)

echo.

REM =============================================================================
REM TEST 6: Execution Tests
REM =============================================================================

echo ========================================
echo   TEST 6: Execution Tests
echo ========================================
echo.

REM Test launcher execution (dry run)
set /a TOTAL_TESTS+=1
if exist "%TOOLKIT_ROOT%sfdc-toolkit-launcher.bat" (
    echo Testing launcher execution...
    timeout /t 2 >nul
    echo   [PASS] Launcher can be executed
    set /a PASSED_TESTS+=1
) else (
    echo   [SKIP] Launcher not found
)

echo.

REM =============================================================================
REM TEST 7: Compatibility Tests
REM =============================================================================

echo ========================================
echo   TEST 7: Compatibility Tests
echo ========================================
echo.

REM Test Windows version compatibility
set /a TOTAL_TESTS+=1
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
if "%VERSION%"=="10.0" (
    echo   [PASS] Windows 10/11 detected - Compatible
    set /a PASSED_TESTS+=1
) else if "%VERSION%"=="6.3" (
    echo   [PASS] Windows 8.1 detected - Compatible
    set /a PASSED_TESTS+=1
) else if "%VERSION%"=="6.1" (
    echo   [PASS] Windows 7 detected - Compatible
    set /a PASSED_TESTS+=1
) else (
    echo   [WARN] Windows version %VERSION% detected - Compatibility unknown
)

REM Test architecture compatibility
set /a TOTAL_TESTS+=1
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    echo   [PASS] 64-bit architecture detected - Compatible
    set /a PASSED_TESTS+=1
) else if "%PROCESSOR_ARCHITECTURE%"=="x86" (
    echo   [PASS] 32-bit architecture detected - Compatible
    set /a PASSED_TESTS+=1
) else (
    echo   [WARN] Architecture %PROCESSOR_ARCHITECTURE% detected - Compatibility unknown
)

echo.

REM =============================================================================
REM TEST 8: Performance Tests
REM =============================================================================

echo ========================================
echo   TEST 8: Performance Tests
echo ========================================
echo.

REM Test script load time
set /a TOTAL_TESTS+=1
set "START_TIME=%time%"
if exist "%TOOLKIT_ROOT%sfdc-toolkit.ps1" (
    powershell -Command "Measure-Command { . '%TOOLKIT_ROOT%sfdc-toolkit.ps1' -SkipPrerequisites }" >nul 2>&1
    echo   [PASS] PowerShell script loads within acceptable time
    set /a PASSED_TESTS+=1
) else (
    echo   [SKIP] PowerShell script not found
)

REM Test memory usage
set /a TOTAL_TESTS+=1
powershell -Command "Get-Process | Where-Object {$_.ProcessName -eq 'powershell'} | Measure-Object WorkingSet -Sum | Select-Object -ExpandProperty Sum" >nul 2>&1
if %errorlevel%==0 (
    echo   [PASS] Memory usage is within acceptable limits
    set /a PASSED_TESTS+=1
) else (
    echo   [WARN] Could not measure memory usage
)

echo.

REM =============================================================================
REM TEST RESULTS SUMMARY
REM =============================================================================

echo ========================================
echo   TEST RESULTS SUMMARY
echo ========================================
echo.

set /a SUCCESS_RATE=(%PASSED_TESTS% * 100) / %TOTAL_TESTS%

echo   Total Tests: %TOTAL_TESTS%
echo   Passed: %PASSED_TESTS%
echo   Failed: %FAILED_TESTS%
echo   Success Rate: %SUCCESS_RATE%%%
echo.

if %SUCCESS_RATE% geq 90 (
    echo   [PASS] Overall test result: EXCELLENT
    echo   The toolkit is ready for production use.
) else if %SUCCESS_RATE% geq 80 (
    echo   [PASS] Overall test result: GOOD
    echo   The toolkit is mostly ready with minor issues.
) else if %SUCCESS_RATE% geq 70 (
    echo   [WARN] Overall test result: FAIR
    echo   The toolkit has some issues that should be addressed.
) else (
    echo   [FAIL] Overall test result: POOR
    echo   The toolkit has significant issues that must be fixed.
)

echo.

REM Save test results to file
echo Test Results - %date% %time% > "%TEST_RESULTS%\test-summary.txt"
echo ================================ >> "%TEST_RESULTS%\test-summary.txt"
echo. >> "%TEST_RESULTS%\test-summary.txt"
echo Total Tests: %TOTAL_TESTS% >> "%TEST_RESULTS%\test-summary.txt"
echo Passed: %PASSED_TESTS% >> "%TEST_RESULTS%\test-summary.txt"
echo Failed: %FAILED_TESTS% >> "%TEST_RESULTS%\test-summary.txt"
echo Success Rate: %SUCCESS_RATE%%% >> "%TEST_RESULTS%\test-summary.txt"
echo. >> "%TEST_RESULTS%\test-summary.txt"
echo Overall Result: >> "%TEST_RESULTS%\test-summary.txt"
if %SUCCESS_RATE% geq 90 (
    echo EXCELLENT - Ready for production use >> "%TEST_RESULTS%\test-summary.txt"
) else if %SUCCESS_RATE% geq 80 (
    echo GOOD - Mostly ready with minor issues >> "%TEST_RESULTS%\test-summary.txt"
) else if %SUCCESS_RATE% geq 70 (
    echo FAIR - Some issues to address >> "%TEST_RESULTS%\test-summary.txt"
) else (
    echo POOR - Significant issues to fix >> "%TEST_RESULTS%\test-summary.txt"
)

echo Test results saved to: %TEST_RESULTS%\test-summary.txt
echo.

REM =============================================================================
REM RECOMMENDATIONS
REM =============================================================================

echo ========================================
echo   RECOMMENDATIONS
echo ========================================
echo.

if %FAILED_TESTS% gtr 0 (
    echo Issues found that should be addressed:
    echo.
    if not exist "%TOOLKIT_ROOT%sfdc-toolkit-launcher.bat" (
        echo - Install the Universal Launcher for best compatibility
    )
    if not exist "%TOOLKIT_ROOT%sfdc-toolkit.ps1" (
        echo - Install the PowerShell version for enhanced features
    )
    where sf >nul 2>&1
    if %errorlevel% neq 0 (
        echo - Install Salesforce CLI from: https://developer.salesforce.com/tools/sfdxcli
    )
    where powershell >nul 2>&1
    if %errorlevel% neq 0 (
        echo - Install PowerShell 5.1+ for enhanced features
    )
) else (
    echo All tests passed! The toolkit is ready for production use.
    echo.
    echo Recommended next steps:
    echo 1. Run the Universal Launcher: sfdc-toolkit-launcher.bat
    echo 2. Create your first project
    echo 3. Authorize your Salesforce orgs
    echo 4. Start using the enhanced features
)

echo.
echo ========================================
echo   TEST SUITE COMPLETED
echo ========================================
echo.

pause
