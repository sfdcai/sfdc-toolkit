# Test script to verify remote configuration fetching
Write-Host "Testing remote configuration fetching..." -ForegroundColor Cyan

# Import the configuration module
Import-Module ".\modules\SFDC-Toolkit-Configuration.psm1" -Force

# Test the remote configuration URL
$testUrl = "https://raw.githubusercontent.com/sfdcai/sfdc-toolkit/refs/heads/main/control.json"
Write-Host "Testing URL: $testUrl" -ForegroundColor Yellow

try {
    # Force TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Test basic connectivity
    $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -ErrorAction Stop
    Write-Host "HTTP Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Content Length: $($response.Content.Length) characters" -ForegroundColor Green
    
    # Try to parse JSON
    $config = $response.Content | ConvertFrom-Json
    Write-Host "JSON parsed successfully!" -ForegroundColor Green
    Write-Host "Available keys: $($config.PSObject.Properties.Name -join ', ')" -ForegroundColor Cyan
    
    if ($config.isActive) {
        Write-Host "Tool is active: $($config.isActive)" -ForegroundColor Green
    }
    
    if ($config.latestVersion) {
        Write-Host "Latest version: $($config.latestVersion)" -ForegroundColor Green
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
}

Write-Host "Test completed." -ForegroundColor Cyan
