# Debug module loading
Write-Host "Debugging module loading..." -ForegroundColor Cyan

# Test 1: Check if module file exists
$modulePath = ".\modules\SFDC-Toolkit-Configuration.psm1"
if (Test-Path $modulePath) {
    Write-Host "Module file exists: $modulePath" -ForegroundColor Green
} else {
    Write-Host "Module file NOT found: $modulePath" -ForegroundColor Red
    exit
}

# Test 2: Try to import module
try {
    Write-Host "Importing module..." -ForegroundColor Yellow
    Import-Module $modulePath -Force -ErrorAction Stop
    Write-Host "Module imported successfully!" -ForegroundColor Green
} catch {
    Write-Host "Import failed: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# Test 3: List all functions in the module
Write-Host "Functions in module:" -ForegroundColor Yellow
Get-Command -Module SFDC-Toolkit-Configuration | ForEach-Object {
    Write-Host "  $($_.Name)" -ForegroundColor Cyan
}

# Test 4: Check specific function
if (Get-Command Initialize-ToolkitConfiguration -ErrorAction SilentlyContinue) {
    Write-Host "Initialize-ToolkitConfiguration found!" -ForegroundColor Green
} else {
    Write-Host "Initialize-ToolkitConfiguration NOT found!" -ForegroundColor Red
}

Write-Host "Debug completed." -ForegroundColor Cyan
