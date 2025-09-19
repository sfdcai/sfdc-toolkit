# Test module syntax
Write-Host "Testing module syntax..." -ForegroundColor Cyan

try {
    # Try to dot-source the module to see syntax errors
    . ".\modules\SFDC-Toolkit-Configuration.psm1"
    Write-Host "Module loaded successfully!" -ForegroundColor Green
    
    # Check if function exists
    if (Get-Command Initialize-ToolkitConfiguration -ErrorAction SilentlyContinue) {
        Write-Host "Function Initialize-ToolkitConfiguration found!" -ForegroundColor Green
    } else {
        Write-Host "Function Initialize-ToolkitConfiguration NOT found!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Syntax Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
}
