# SFDC DevOps Toolkit - Enhanced Production Version

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg) ![Batch](https://img.shields.io/badge/Batch-Compatible-green.svg) ![Salesforce CLI](https://img.shields.io/badge/sf-CLI-blue) ![License](https://img.shields.io/badge/License-MIT-green.svg) ![Windows](https://img.shields.io/badge/Windows-10%2B-blue.svg)

A professional-grade, production-ready Salesforce development and DevOps toolkit with **cross-Windows compatibility**. This enhanced version provides multiple execution methods (PowerShell, Enhanced Batch, Basic Batch) ensuring compatibility across all Windows environments while maintaining full functionality.

**Enhanced by:** Amit Bhardwaj  
**Original Author:** Amit Bhardwaj  
**Version:** 14.2.0 (Production Ready)

---

## 🚀 Quick Start

### Option 1: Universal Launcher (Recommended)
```batch
sfdc-toolkit-launcher.bat
```
The launcher automatically detects the best execution method for your environment.

### Option 2: Direct Execution
```batch
# PowerShell (Enhanced Features)
sfdc-toolkit.ps1

# Enhanced Batch (Full Features)
sfdc-toolkit-enhanced.bat

# Basic Batch (Core Features)
sfdc-toolkit.bat
```

---

## 🎯 Enhanced Features

### **Cross-Platform Compatibility**
- **PowerShell Version**: Full-featured with advanced error handling and logging
- **Enhanced Batch Version**: Complete functionality with improved batch scripting
- **Basic Batch Version**: Core features for maximum compatibility
- **Universal Launcher**: Automatically selects the best execution method

### **Production-Ready Enhancements**
- **Advanced Error Handling**: Comprehensive error tracking and recovery
- **Enhanced Logging**: Multi-level logging with audit trails
- **Intelligent Deployment**: Smart deployment with automatic rollback
- **Backup & Restore**: Project data backup and restoration capabilities
- **Performance Monitoring**: Real-time performance tracking
- **Security Features**: Audit logging and secure credential handling

### **Original Features (All Preserved)**
- **Self-Contained Project Structure**: No global dependencies
- **Interactive Menu System**: User-friendly, color-coded interface
- **Dual Org Management**: Source and Destination org handling
- **Advanced Org Comparison**: Multiple comparison modes with CSV reports
- **Delta Package Generation**: Intelligent change detection
- **Advanced Deployment Engine**: Support for destructive changes and testing
- **Manifest Generation**: Full and custom package.xml creation
- **Metadata Analysis**: Local profile and permission set analysis

---

## ⚙️ Prerequisites

### Required (All Versions)
1. **Windows 10** or higher
2. **Salesforce CLI (`sf`)** - [Download](https://developer.salesforce.com/tools/sfdxcli)

### Recommended (Enhanced Features)
3. **PowerShell 5.1+** (for PowerShell version)
4. **Git** (for version control integration)
5. **Visual Studio Code** (for visual comparisons)

### Optional (Advanced Features)
6. **PowerShell 7.0+** (for latest PowerShell features)
7. **Windows Terminal** (for enhanced console experience)

---

## 🏗️ Architecture

### **Multi-Execution Architecture**
```
sfdc-toolkit-launcher.bat (Universal Launcher)
├── sfdc-toolkit.ps1 (PowerShell - Enhanced)
├── sfdc-toolkit-enhanced.bat (Enhanced Batch)
└── sfdc-toolkit.bat (Basic Batch - Core)
```

### **Enhanced Project Structure**
```
Your-Project/
├── .sfdc-toolkit/           # Toolkit configuration
│   ├── settings.json        # Project settings
│   ├── toolkit.log          # Main log file
│   ├── errors.log           # Error log
│   ├── audit.log            # Audit trail
│   └── metadata_map.json    # Metadata mappings
├── delta-deployment/        # Generated delta packages
├── deployment-backups/      # Automatic backups
└── _source_metadata/        # Retrieved source metadata
    └── _target_metadata/    # Retrieved target metadata
```

---

## 📋 Usage Guide

### **1. Initial Setup**
```batch
# Run the universal launcher
sfdc-toolkit-launcher.bat

# Or run directly
sfdc-toolkit.ps1
```

### **2. Project Management**
1. **Create/Select Project**: Choose or create a project folder
2. **Authorize Orgs**: Connect to your Salesforce orgs
3. **Configure Settings**: Set API versions and preferences

### **3. Core Workflows**

#### **Org Comparison & Delta Generation**
```
Main Menu → [1] Compare Orgs & Generate Delta Package
├── Retrieve metadata from both orgs
├── Generate intelligent delta package
├── Create deployment-ready package.xml
└── Generate CSV comparison report
```

#### **Intelligent Deployment**
```
Main Menu → [4] Intelligent Deployment with Rollback
├── Pre-deployment validation
├── Automatic backup creation
├── Deployment with monitoring
└── Automatic rollback on failure
```

#### **Visual Comparison**
```
Main Menu → [2] Quick Visual Compare in VS Code
├── Retrieve metadata (if needed)
├── Launch VS Code with side-by-side diff
└── Visual comparison of all components
```

---

## 🔧 Configuration

### **Enhanced Configuration File**
The toolkit uses `sfdc-toolkit-config.json` for advanced configuration:

```json
{
  "defaults": {
    "apiVersion": "61.0",
    "logLevel": "INFO",
    "testLevel": "RunLocalTests",
    "backupBeforeDeployment": true,
    "rollbackOnFailure": true
  },
  "deployment": {
    "strategies": {
      "quick": { "testLevel": "NoTestRun" },
      "standard": { "testLevel": "RunLocalTests" },
      "comprehensive": { "testLevel": "RunAllTestsInOrg" },
      "intelligent": { "rollback": true, "monitoring": true }
    }
  }
}
```

### **Logging Configuration**
- **Main Log**: `toolkit.log` - All activities
- **Error Log**: `errors.log` - Errors and warnings
- **Audit Log**: `audit.log` - Security and compliance
- **Deployment Log**: `deployments.log` - Deployment activities

---

## 🛡️ Security & Compliance

### **Audit Features**
- Complete audit trail of all actions
- User interaction logging
- System change tracking
- Compliance reporting

### **Security Measures**
- Secure credential handling
- Encrypted configuration options
- Permission-based access control
- Safe deployment practices

---

## 📊 Monitoring & Analytics

### **Performance Tracking**
- Real-time deployment monitoring
- Performance metrics collection
- Resource usage tracking
- Error rate monitoring

### **Reporting**
- Session summaries with statistics
- Error and warning counts
- Performance reports
- Compliance dashboards

---

## 🔄 Backup & Recovery

### **Automatic Backups**
- Pre-deployment backups
- Project data snapshots
- Configuration backups
- Metadata backups

### **Restore Capabilities**
- Point-in-time restoration
- Selective data recovery
- Configuration rollback
- Complete project restoration

---

## 🚨 Troubleshooting

### **Common Issues**

#### **PowerShell Execution Policy**
```batch
# Fix execution policy
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
```

#### **Salesforce CLI Not Found**
```batch
# Install Salesforce CLI
npm install -g @salesforce/cli
```

#### **Permission Issues**
- Run as Administrator if needed
- Check folder permissions
- Ensure write access to project directory

### **Debug Mode**
```batch
# Enable debug logging
sfdc-toolkit.ps1 -LogLevel DEBUG -Verbose
```

---

## 📈 Performance Optimization

### **Caching**
- Metadata type caching
- Org information caching
- Project settings caching
- Intelligent cache invalidation

### **Parallel Processing**
- Concurrent metadata retrieval
- Parallel file processing
- Multi-threaded comparisons
- Background operations

---

## 🔄 Migration from Original

### **Backward Compatibility**
- All original features preserved
- Original project structure supported
- Configuration migration available
- Seamless upgrade path

### **Migration Steps**
1. Backup existing projects
2. Download enhanced version
3. Run migration utility (if needed)
4. Verify functionality

---

## 📚 Advanced Usage

### **Command Line Parameters**
```batch
# PowerShell version
sfdc-toolkit.ps1 -ProjectPath "C:\MyProject" -LogLevel DEBUG -Verbose

# Batch version
sfdc-toolkit-enhanced.bat /project:"C:\MyProject" /log:DEBUG
```

### **Automation**
```batch
# Automated deployment
sfdc-toolkit.ps1 -SkipPrerequisites -UseBatchVersion
```

---

## 🤝 Contributing

### **Development Setup**
1. Clone the repository
2. Install prerequisites
3. Run tests
4. Submit pull requests

### **Testing**
- Unit tests for core functions
- Integration tests for workflows
- Compatibility tests across Windows versions
- Performance benchmarks

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Original Author**: Amit Bhardwaj
- **Enhanced by**: Amit Bhardwaj
- **Community**: Salesforce Developer Community
- **Contributors**: All contributors and testers

---

## 📞 Support

### **Documentation**
- [Full Documentation](docs/)
- [API Reference](docs/api/)
- [Troubleshooting Guide](docs/troubleshooting/)

### **Community**
- [GitHub Issues](https://github.com/your-repo/issues)
- [Discussions](https://github.com/your-repo/discussions)
- [LinkedIn](https://linkedin.com/in/salesforce-technical-architect)

---

## 🔮 Roadmap

### **Version 15.0 (Planned)**
- [ ] Cloud deployment support
- [ ] CI/CD pipeline integration
- [ ] Advanced analytics dashboard
- [ ] Multi-org management
- [ ] API-based integrations

### **Version 14.3 (Next)**
- [ ] Enhanced error recovery
- [ ] Performance optimizations
- [ ] Additional metadata types
- [ ] Improved UI/UX

---

**Ready to streamline your Salesforce DevOps workflow? Start with the Universal Launcher and experience the power of production-ready Salesforce development tools!**
