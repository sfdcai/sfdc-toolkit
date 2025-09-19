# Test function syntax
Write-Host "Testing function syntax..." -ForegroundColor Cyan

# Create a test with the exact function signature
$testCode = @'
function Initialize-ToolkitConfiguration {
    [CmdletBinding()]
    param()
    
    Write-Host "Test function called" -ForegroundColor Green
    return $true
}

Export-ModuleMember -Function Initialize-ToolkitConfiguration
'@

$testCode | Out-File -FilePath "test-function.psm1" -Encoding UTF8

try {
    Import-Module ".\test-function.psm1" -Force
    if (Get-Command Initialize-ToolkitConfiguration -ErrorAction SilentlyContinue) {
        Write-Host "Function found!" -ForegroundColor Green
        $result = Initialize-ToolkitConfiguration
        Write-Host "Result: $result" -ForegroundColor Green
    } else {
        Write-Host "Function NOT found!" -ForegroundColor Red
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Clean up
Remove-Item "test-function.psm1" -Force -ErrorAction SilentlyContinue
