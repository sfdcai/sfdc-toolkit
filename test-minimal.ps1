# Minimal test
Write-Host "Testing minimal module..." -ForegroundColor Cyan

# Create a simple test module
$testModule = @'
function Test-Function {
    Write-Host "Test function called" -ForegroundColor Green
}
Export-ModuleMember -Function Test-Function
'@

$testModule | Out-File -FilePath "test-module.psm1" -Encoding UTF8

try {
    Import-Module ".\test-module.psm1" -Force
    if (Get-Command Test-Function -ErrorAction SilentlyContinue) {
        Write-Host "Test function found!" -ForegroundColor Green
        Test-Function
    } else {
        Write-Host "Test function NOT found!" -ForegroundColor Red
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Clean up
Remove-Item "test-module.psm1" -Force -ErrorAction SilentlyContinue
