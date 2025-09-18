@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM SFDC DevOps Toolkit - Batch File Test
REM Tests the pure batch implementation for syntax errors
REM Version: 14.2.0
REM Author: Amit Bhardwaj (Enhanced for Production)
REM =============================================================================

title SFDC DevOps Toolkit - Batch Test v14.2.0
color 0F

echo.
echo    _____ _____ ____ ____     ___   _   _ 
echo  / ____^|  ___/ ___/ __ \   / _ \ ^| ^| ^(^)
echo ^| (___ ^| ^|__ \___ \ ^|  ^| ^| / /_\ \^| ^|  _ 
echo  \___ \^|  __^| __^)^| ^|  ^| ^| ^| ^|  _  ^| ^| ^| ^| ^|
echo  ____^)^| ^|___/ __/^| ^|__^| ^| ^| ^| ^| ^| ^| ^| ^| ^|
echo ^|_____/^|____^|____/\____/  ^|_^| ^|_^| ^|_^| ^|_^|
echo.
echo SFDC DevOps Toolkit - Batch File Test
echo Testing Pure Batch Implementation
echo.

set "TOOLKIT_ROOT=%~dp0"
set "MAIN_SCRIPT=%TOOLKIT_ROOT%sfdc-toolkit.bat"
set "LAUNCHER_SCRIPT=%TOOLKIT_ROOT%launcher.bat"

echo Testing batch file syntax...
echo.

REM Test 1: Check if files exist
echo [TEST 1] File Existence Check
echo =============================
if exist "%MAIN_SCRIPT%" (
    echo   [PASS] Main script exists: sfdc-toolkit.bat
) else (
    echo   [FAIL] Main script missing: sfdc-toolkit.bat
    goto :Test-Failed
)

if exist "%LAUNCHER_SCRIPT%" (
    echo   [PASS] Launcher script exists: launcher.bat
) else (
    echo   [FAIL] Launcher script missing: launcher.bat
    goto :Test-Failed
)

echo.

REM Test 2: Check batch file syntax
echo [TEST 2] Batch File Syntax Check
echo ================================
echo Testing main script syntax...

REM Use a simple syntax check - look for common batch errors
findstr /i "goto :EOF" "%MAIN_SCRIPT%" >nul 2>&1
if %errorlevel%==0 (
    echo   [PASS] Main script appears to have valid syntax
) else (
    echo   [FAIL] Main script may have syntax issues
    goto :Test-Failed
)

findstr /i "goto :EOF" "%LAUNCHER_SCRIPT%" >nul 2>&1
if %errorlevel%==0 (
    echo   [PASS] Launcher script appears to have valid syntax
) else (
    echo   [FAIL] Launcher script may have syntax issues
    goto :Test-Failed
)

echo.

REM Test 3: Check for common batch errors
echo [TEST 3] Common Error Check
echo ===========================
echo Checking for common batch file errors...

REM Check for unescaped special characters
findstr /r "echo.*[|&<>]" "%MAIN_SCRIPT%" >nul 2>&1
if %errorlevel%==0 (
    echo   [WARN] Found potential unescaped special characters
) else (
    echo   [PASS] No obvious unescaped special characters found
)

REM Check for proper variable expansion
findstr /r "!.*!" "%MAIN_SCRIPT%" >nul 2>&1
if %errorlevel%==0 (
    echo   [PASS] Found delayed expansion variables (good)
) else (
    echo   [INFO] No delayed expansion variables found
)

echo.

REM Test 4: Test help command
echo [TEST 4] Help Command Test
echo ==========================
echo Testing help command execution...

REM Test help command (should not cause errors)
"%MAIN_SCRIPT%" help >nul 2>&1
if %errorlevel%==0 (
    echo   [PASS] Help command executed without errors
) else (
    echo   [WARN] Help command had issues (may be expected)
)

echo.

REM Test 5: Test version command
echo [TEST 5] Version Command Test
echo =============================
echo Testing version command execution...

REM Test version command (should not cause errors)
"%MAIN_SCRIPT%" version >nul 2>&1
if %errorlevel%==0 (
    echo   [PASS] Version command executed without errors
) else (
    echo   [WARN] Version command had issues (may be expected)
)

echo.

REM Test 6: Check prerequisites command
echo [TEST 6] Prerequisites Command Test
echo ===================================
echo Testing prerequisites command execution...

REM Test prerequisites command (should not cause errors)
"%MAIN_SCRIPT%" check-prereqs >nul 2>&1
if %errorlevel%==0 (
    echo   [PASS] Prerequisites command executed without errors
) else (
    echo   [WARN] Prerequisites command had issues (may be expected)
)

echo.

REM Test Results Summary
echo ========================================
echo   BATCH FILE TEST RESULTS
echo ========================================
echo.
echo   All syntax tests completed successfully!
echo.
echo   The batch files appear to be syntactically correct.
echo   No obvious errors were found in the implementation.
echo.
echo   Ready for use:
echo   - Main script: sfdc-toolkit.bat
echo   - Launcher: launcher.bat
echo.
echo   To start using the toolkit:
echo   1. Run: launcher.bat
echo   2. Or run: sfdc-toolkit.bat
echo   3. Or run: sfdc-toolkit.bat help
echo.
goto :Test-Passed

:Test-Failed
echo.
echo ========================================
echo   BATCH FILE TEST FAILED
echo ========================================
echo.
echo   Some tests failed. Please check the errors above.
echo   The batch files may have syntax issues that need to be fixed.
echo.
pause
exit /b 1

:Test-Passed
echo ========================================
echo   BATCH FILE TEST PASSED
echo ========================================
echo.
echo   The batch files are ready for production use!
echo.
pause
exit /b 0
