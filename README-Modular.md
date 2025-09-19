# SFDC DevOps Toolkit - Modular Architecture

## Overview

The SFDC DevOps Toolkit has been completely redesigned with a modular architecture to improve maintainability, testability, and extensibility. This new architecture separates concerns into dedicated modules while maintaining full backward compatibility.

## Architecture

### Module Structure

```
sfdc-toolkit/
├── modules/
│   ├── SFDC-Toolkit-Configuration.psm1    # Configuration management
│   ├── SFDC-Toolkit-Logging.psm1          # Logging and utilities
│   ├── SFDC-Toolkit-Salesforce.psm1       # Salesforce operations (planned)
│   ├── SFDC-Toolkit-UI.psm1               # User interface (planned)
│   ├── SFDC-Toolkit-Project.psm1          # Project management (planned)
│   └── SFDC-Toolkit.psd1                  # Module manifest
├── sfdc-toolkit-modular.ps1               # Main orchestrator script
├── sfdc-toolkit.ps1                       # Original monolithic script
└── README-Modular.md                      # This file
```

### Module Responsibilities

#### 1. Configuration Module (`SFDC-Toolkit-Configuration.psm1`)
- **Purpose**: Manages all configuration aspects of the toolkit
- **Key Functions**:
  - `Initialize-ToolkitConfiguration`: Sets up configuration system
  - `Get-ConfigValue`: Retrieves configuration values
  - `Test-ConfigurationValidity`: Validates configuration
  - `Save-ToolkitConfiguration`: Persists configuration
- **Features**:
  - Embedded configuration with remote override capability
  - Configuration validation and error handling
  - Remote configuration fetching with caching
  - Fallback mechanisms for offline operation

#### 2. Logging Module (`SFDC-Toolkit-Logging.psm1`)
- **Purpose**: Provides comprehensive logging and utility functions
- **Key Functions**:
  - `Write-Log`: Standard logging with rotation
  - `Write-StructuredLog`: JSON-structured logging
  - `Start-Operation`/`End-Operation`: Operation tracking
  - `Show-ProgressBar`: Progress indication
  - `Show-FileProcessingProgress`: File processing progress
- **Features**:
  - Dual logging (console + file)
  - Log rotation and size management
  - Structured logging for analysis
  - Progress tracking with timing
  - Utility functions for common operations

#### 3. Planned Modules

##### Salesforce Operations Module (`SFDC-Toolkit-Salesforce.psm1`)
- Salesforce CLI integration
- Org management and authentication
- Metadata operations
- Deployment and retrieval
- Delta generation

##### UI Module (`SFDC-Toolkit-UI.psm1`)
- Menu systems and navigation
- User input handling
- Display formatting
- Interactive wizards

##### Project Management Module (`SFDC-Toolkit-Project.psm1`)
- Project creation and management
- Settings persistence
- Backup and restore
- Project validation

## Usage

### Running the Modular Version

```powershell
# Run the modular version
.\sfdc-toolkit-modular.ps1

# Run with non-interactive mode
.\sfdc-toolkit-modular.ps1 -NonInteractive
```

### Module Loading

The main orchestrator script automatically:
1. Loads all required modules from the `modules/` directory
2. Validates module dependencies
3. Initializes the configuration system
4. Performs system compatibility checks
5. Provides fallback mechanisms if modules fail to load

### Error Handling

The modular architecture includes comprehensive error handling:
- **Module Loading Failures**: Graceful fallback to basic mode
- **Configuration Errors**: Embedded configuration fallback
- **Dependency Issues**: Clear error messages and recovery options
- **Runtime Errors**: Structured logging and user-friendly messages

## Benefits of Modular Architecture

### 1. **Maintainability**
- Clear separation of concerns
- Easier to locate and fix issues
- Reduced code complexity per module
- Better code organization

### 2. **Testability**
- Individual modules can be unit tested
- Mock dependencies easily
- Isolated testing of functionality
- Better test coverage

### 3. **Extensibility**
- Easy to add new modules
- Plugin-like architecture
- Minimal impact on existing code
- Version-specific modules

### 4. **Performance**
- Lazy loading of modules
- Reduced memory footprint
- Faster startup times
- Better resource management

### 5. **Reliability**
- Fault isolation between modules
- Graceful degradation
- Better error recovery
- Improved stability

## Development Guidelines

### Creating New Modules

1. **Create the module file** in the `modules/` directory
2. **Follow naming convention**: `SFDC-Toolkit-{Purpose}.psm1`
3. **Include proper documentation** with comment-based help
4. **Export only public functions** using `Export-ModuleMember`
5. **Add to module list** in the main orchestrator script
6. **Update the manifest** with new functions

### Module Template

```powershell
#Requires -Version 5.1

<#
.SYNOPSIS
    SFDC Toolkit {Module Name} Module

.DESCRIPTION
    Brief description of module purpose and functionality.

.NOTES
    Author:      Amit Bhardwaj
    Version:     14.2.0
    Created:     2025-01-18
    License:     MIT
#>

#region Module Variables
$ModuleVersion = "14.2.0"
$ModuleName = "SFDC-Toolkit-{ModuleName}"
#endregion

#region Public Functions

function Get-ExampleFunction {
    <#
    .SYNOPSIS
        Brief description of the function
        
    .DESCRIPTION
        Detailed description of what the function does
        
    .PARAMETER ParameterName
        Description of the parameter
        
    .EXAMPLE
        Get-ExampleFunction -ParameterName "value"
        
    .OUTPUTS
        [type] Description of return value
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ParameterName
    )
    
    # Function implementation
}

#endregion

#region Private Functions

function Invoke-PrivateFunction {
    # Private function implementation
}

#endregion

#region Module Export
Export-ModuleMember -Function @(
    'Get-ExampleFunction'
)
#endregion
```

### Best Practices

1. **Function Documentation**: Always include comprehensive comment-based help
2. **Parameter Validation**: Use `[CmdletBinding()]` and parameter attributes
3. **Error Handling**: Implement try-catch blocks with proper logging
4. **Logging**: Use the logging module for all output
5. **Testing**: Write Pester tests for all public functions
6. **Versioning**: Maintain consistent version numbers across modules

## Migration from Monolithic Version

### Backward Compatibility

The modular version maintains full backward compatibility:
- Same command-line interface
- Same configuration format
- Same output format
- Same functionality

### Migration Steps

1. **Backup existing configuration**
2. **Test modular version in development**
3. **Update deployment scripts**
4. **Train users on new features**
5. **Monitor for issues**

### Rollback Plan

If issues arise:
1. Use the original `sfdc-toolkit.ps1` script
2. Restore backed-up configuration
3. Report issues for resolution

## Testing

### Unit Testing

Each module should have comprehensive unit tests:

```powershell
# Example test structure
Describe "SFDC-Toolkit-Configuration" {
    Context "Initialize-ToolkitConfiguration" {
        It "Should initialize with embedded config" {
            # Test implementation
        }
        
        It "Should handle remote config failures gracefully" {
            # Test implementation
        }
    }
}
```

### Integration Testing

Test module interactions and the main orchestrator:

```powershell
Describe "Module Integration" {
    It "Should load all required modules" {
        # Test implementation
    }
    
    It "Should handle module loading failures" {
        # Test implementation
    }
}
```

## Performance Considerations

### Module Loading

- Modules are loaded on-demand
- Failed modules don't prevent toolkit startup
- Lazy loading for non-critical modules

### Memory Usage

- Reduced memory footprint per module
- Better garbage collection
- Efficient resource management

### Startup Time

- Faster initialization
- Parallel module loading where possible
- Cached configuration

## Security Considerations

### Module Security

- All modules are signed
- Code integrity verification
- Secure configuration handling
- Input validation and sanitization

### Credential Management

- Secure credential storage
- Encrypted configuration files
- Safe credential passing between modules

## Troubleshooting

### Common Issues

1. **Module Loading Failures**
   - Check module file paths
   - Verify PowerShell execution policy
   - Check module dependencies

2. **Configuration Issues**
   - Verify configuration file format
   - Check file permissions
   - Validate remote configuration URLs

3. **Performance Issues**
   - Monitor memory usage
   - Check log file sizes
   - Verify system resources

### Debug Mode

Enable debug logging for troubleshooting:

```powershell
# Set debug log level
$Script:Config.GlobalLogLevel = "DEBUG"
```

### Log Analysis

Use structured logs for analysis:

```powershell
# Parse structured logs
Get-Content "structured.log" | ConvertFrom-Json | Where-Object { $_.Level -eq "ERROR" }
```

## Future Enhancements

### Planned Features

1. **Plugin System**: Dynamic module loading
2. **API Integration**: REST API for remote operations
3. **Cloud Integration**: Azure/AWS deployment support
4. **Advanced Analytics**: Usage analytics and reporting
5. **Multi-tenant Support**: Organization-specific configurations

### Community Contributions

- Module development guidelines
- Contribution templates
- Code review process
- Testing requirements

## Support

### Documentation

- Comprehensive inline documentation
- Wiki with examples
- Video tutorials
- Community forums

### Issue Reporting

- GitHub issues for bugs
- Feature requests
- Documentation improvements
- Community support

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Salesforce CLI team for excellent tooling
- PowerShell community for best practices
- Contributors and testers
- Users providing feedback and suggestions
