# Test simple module
Write-Host "Testing simple module..." -ForegroundColor Cyan

try {
    Import-Module ".\modules\SFDC-Toolkit-Configuration-Simple.psm1" -Force
    Write-Host "Module imported successfully!" -ForegroundColor Green
    
    # Check if function exists
    if (Get-Command Initialize-ToolkitConfiguration -ErrorAction SilentlyContinue) {
        Write-Host "Function Initialize-ToolkitConfiguration found!" -ForegroundColor Green
        
        # Test the function
        $result = Initialize-ToolkitConfiguration
        Write-Host "Initialization result: $result" -ForegroundColor Green
        
        if ($Script:Config) {
            Write-Host "Config loaded successfully!" -ForegroundColor Green
            Write-Host "Author: $($Script:Config.AuthorName)" -ForegroundColor Cyan
            Write-Host "Has LatestVersion: $($Script:Config.PSObject.Properties.Name -contains 'LatestVersion')" -ForegroundColor Cyan
            if ($Script:Config.PSObject.Properties.Name -contains 'LatestVersion') {
                Write-Host "Latest Version: $($Script:Config.LatestVersion)" -ForegroundColor Cyan
            }
        }
    } else {
        Write-Host "Function Initialize-ToolkitConfiguration NOT found!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Test completed." -ForegroundColor Cyan
