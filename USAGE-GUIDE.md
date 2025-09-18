# SFDC DevOps Toolkit - Simple Usage Guide

## Quick Start (No UI)

### Option 1: Use the Fixed Launcher
```batch
sfdc-toolkit-launcher-fixed.bat
```

### Option 2: Direct Execution

#### PowerShell Version (Recommended)
```powershell
.\sfdc-toolkit-simple.ps1 help
```

#### Batch Version
```batch
sfdc-toolkit-simple.bat help
```

## Available Commands

### 1. Check Prerequisites
```batch
# Batch
sfdc-toolkit-simple.bat check-prereqs

# PowerShell
.\sfdc-toolkit-simple.ps1 check-prereqs
```

### 2. Authorize a New Org
```batch
# Batch
sfdc-toolkit-simple.bat auth-org

# PowerShell
.\sfdc-toolkit-simple.ps1 auth-org
```

### 3. List Authorized Orgs
```batch
# Batch
sfdc-toolkit-simple.bat list-orgs

# PowerShell
.\sfdc-toolkit-simple.ps1 list-orgs
```

### 4. Compare Two Orgs
```batch
# Batch
sfdc-toolkit-simple.bat --source-org "DEV" --dest-org "PROD" compare-orgs

# PowerShell
.\sfdc-toolkit-simple.ps1 -SourceOrg "DEV" -DestOrg "PROD" -Command compare-orgs
```

### 5. Deploy Metadata
```batch
# Batch
sfdc-toolkit-simple.bat --dest-org "PROD" deploy

# PowerShell
.\sfdc-toolkit-simple.ps1 -DestOrg "PROD" -Command deploy
```

### 6. Generate Manifest
```batch
# Batch
sfdc-toolkit-simple.bat --source-org "DEV" generate-manifest

# PowerShell
.\sfdc-toolkit-simple.ps1 -SourceOrg "DEV" -Command generate-manifest
```

### 7. Open Org in Browser
```batch
# Batch
sfdc-toolkit-simple.bat --source-org "DEV" open-org

# PowerShell
.\sfdc-toolkit-simple.ps1 -SourceOrg "DEV" -Command open-org
```

## Common Workflows

### Workflow 1: Compare and Deploy
```batch
# 1. Compare orgs
sfdc-toolkit-simple.bat --source-org "DEV" --dest-org "PROD" compare-orgs

# 2. Deploy changes
sfdc-toolkit-simple.bat --dest-org "PROD" deploy
```

### Workflow 2: Generate and Deploy Manifest
```batch
# 1. Generate manifest from source org
sfdc-toolkit-simple.bat --source-org "DEV" generate-manifest

# 2. Deploy using the generated manifest
sfdc-toolkit-simple.bat --dest-org "PROD" deploy
```

## Parameters

### Batch Version Parameters
- `--project PATH` - Set project path
- `--source-org ALIAS` - Set source org alias
- `--dest-org ALIAS` - Set destination org alias
- `--api-version VERSION` - Set API version (default: 61.0)
- `--log-level LEVEL` - Set log level (INFO, DEBUG, WARN, ERROR)

### PowerShell Version Parameters
- `-ProjectPath PATH` - Set project path
- `-SourceOrg ALIAS` - Set source org alias
- `-DestOrg ALIAS` - Set destination org alias
- `-ApiVersion VERSION` - Set API version (default: 61.0)
- `-LogLevel LEVEL` - Set log level (INFO, DEBUG, WARN, ERROR)

## Examples

### Example 1: Basic Comparison
```batch
sfdc-toolkit-simple.bat --source-org "DEV" --dest-org "PROD" --project "C:\MyProject" compare-orgs
```

### Example 2: Deploy with Custom API Version
```batch
sfdc-toolkit-simple.bat --dest-org "PROD" --api-version "60.0" deploy
```

### Example 3: PowerShell with Debug Logging
```powershell
.\sfdc-toolkit-simple.ps1 -SourceOrg "DEV" -DestOrg "PROD" -LogLevel "DEBUG" -Command compare-orgs
```

## Troubleshooting

### PowerShell Execution Policy Error
If you get an execution policy error, run:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Salesforce CLI Not Found
Install Salesforce CLI from: https://developer.salesforce.com/tools/sfdxcli

### Batch File Syntax Error
Use the fixed launcher: `sfdc-toolkit-launcher-fixed.bat`

## File Structure After Operations

```
Your-Project/
├── .sfdc-toolkit/
│   └── toolkit.log          # Log file
├── _source_metadata/        # Retrieved from source org
├── _target_metadata/        # Retrieved from target org
├── delta-deployment/        # Generated delta package
│   └── package.xml         # Deployment manifest
└── package.xml             # Generated manifest (if using generate-manifest)
```

## Log Files

All operations are logged to: `.sfdc-toolkit\toolkit.log`

Log levels:
- **INFO**: General information
- **DEBUG**: Detailed debugging information
- **WARN**: Warnings
- **ERROR**: Errors

## Need Help?

Run any command with `help` to see usage information:
```batch
sfdc-toolkit-simple.bat help
```

Or:
```powershell
.\sfdc-toolkit-simple.ps1 help
```
