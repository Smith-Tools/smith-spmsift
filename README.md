# Smith SPMSift 📦

**Enhanced Swift Package Manager analysis tool**

[![Swift Version](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-mOS%20%7C%20iOS%20%7C%20visionOS-lightgrey.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Smith SPSift provides comprehensive Swift Package Manager analysis with Smith Framework integration, converting verbose SPM output into structured, token-efficient formats designed for AI agents and modern development workflows.

## 🎯 **Overview**

Smith SPSift specializes in **Swift Package Manager analysis**, offering:

- **📦 Package Validation** - Comprehensive package structure analysis
- **🔍 Dependency Analysis** - Graph complexity and circular import detection
- **📊 Performance Insights** - Package resolution timing and bottleneck identification
- **🚨 Issue Detection** - Common SPM problems and smart recommendations

## 🚀 **Quick Start**

### **Installation**
```bash
# Install via Homebrew
brew install smith-tools/smith/smith-spmsift

# Or build from source
git clone https://github.com/Smith-Tools/smith-spmsift
cd smith-spmsift
swift build
```

### **Basic Usage**
```bash
# Validate current package
smith-spmsift validate

# Analyze package structure
smith-spmsift analyze --json

# Parse package dump output
swift package dump-package | smith-spmsift parse

# Check dependencies
smith-spmsift analyze --dependencies
```

## 📋 **Commands**

### **✅ validate**
Validate Swift Package Manager package configuration.

```bash
smith-spmsift validate [--project <path>] [--deep] [--verbose]
```

**Example:**
```bash
$ smith-spmsift validate
✅ SMITH SPM VALIDATION
=======================
✅ Package.swift is valid
✅ Dependencies are resolvable
✅ Target configuration is optimal
✅ Import structure is clean

📊 Package Summary:
- Targets: 3
- Dependencies: 7
- Import Depth: Average 2.3
- Status: HEALTHY
```

### **🔍 analyze**
Comprehensive package analysis with detailed metrics.

```bash
smith-spmsift analyze [--project <path>] [--format json] [--dependencies] [--deep]
```

**Example:**
```json
{
  "project": "/Users/developer/MyPackage",
  "analysis": {
    "package_structure": {
      "targets": [
        {
          "name": "MyLibrary",
          "type": "library",
          "platforms": ["iOS", "macOS"],
          "dependencies": 5
        }
      ],
      "dependencies": [
        {
          "name": "swift-nio",
          "version": "2.40.0",
          "type": "remote"
        }
      ]
    },
    "metrics": {
      "targets_count": 3,
      "dependencies_count": 7,
      "import_depth_avg": 2.3,
      "resolution_time": 1.2
    },
    "issues": [],
    "recommendations": [
      "Consider using exact version pins for production dependencies",
      "Review circular import risks in complex targets"
    ]
  }
}
```

### **📝 parse**
Parse Swift Package Manager output from stdin.

```bash
smith-spmsift parse [--format json] [--verbose]
```

**Example:**
```bash
$ swift package dump-package | smith-spmsift parse
{
  "name": "MyPackage",
  "platforms": ["iOS", "macOS", "tvOS", "watchOS"],
  "products": [
    {
      "name": "MyLibrary",
      "type": {
        "library": ["automatic"]
      }
    }
  ],
  "targets": 3,
  "dependencies": 7
}
```

### **⚡ optimize**
Analyze and suggest package optimization improvements.

```bash
smith-spmsift optimize [--project <path>] [--aggressive]
```

## 🔧 **Advanced Features**

### **🔗 Dependency Graph Analysis**
```bash
smith-spmsift analyze --dependencies --format json
```

**Output:**
```json
{
  "dependency_graph": {
    "nodes": ["MyLibrary", "DependencyA", "DependencyB"],
    "edges": [
      {"from": "MyLibrary", "to": "DependencyA"},
      {"from": "MyLibrary", "to": "DependencyB"}
    ],
    "complexity": "low",
    "max_depth": 3,
    "circular_deps": false
  }
}
```

### **🚨 Issue Detection**

Smith SPSift automatically detects:

- **Circular Imports** - Self-referencing packages
- **Deep Import Chains** - Packages with >10 imports
- **Large Dependencies** - swift-syntax, GRDB, TCA
- **Missing Platforms** - Incomplete platform support
- **Version Conflicts** - Incompatible dependency versions

### **📈 Performance Metrics**

```bash
smith-spmsift analyze --metrics
```

**Metrics:**
- **Resolution Time**: Package dependency resolution speed
- **Import Depth**: Average import chain length
- **Target Count**: Number of build targets
- **Dependency Count**: External dependencies
- **File Count**: Source files in package

## 🏗️ **Integration Examples**

### **GitHub Actions**
```yaml
name: Smith SPM Analysis

on: [push, pull_request]

jobs:
  spm-analysis:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v4
    - name: Install Smith SPSift
      run: |
        brew tap smith-tools/smith
        brew install smith-spmsift

    - name: Analyze Package
      run: |
        smith-spmsift analyze --format json > spm-analysis.json

    - name: Upload Results
      uses: actions/upload-artifact@v4
      with:
        name: spm-analysis
        path: spm-analysis.json
```

### **Swift Integration**
```swift
import Foundation

struct PackageAnalyzer {
    static func analyze(packagePath: String) async throws -> PackageAnalysis {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/smith-spmsift")
        process.arguments = ["analyze", "--project", packagePath, "--format", "json"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return try JSONDecoder().decode(PackageAnalysis.self, from: data)
    }
}
```

### **Pre-commit Hook**
```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "🔍 Running Smith SPM validation..."
smith-spmsift validate

if [ $? -ne 0 ]; then
    echo "❌ Package validation failed"
    exit 1
fi

echo "✅ Package validation passed"
```

## 📊 **Output Formats**

### **JSON Format**
```json
{
  "project": "/path/to/package",
  "analysis": {
    "package_structure": {...},
    "metrics": {...},
    "issues": [...],
    "recommendations": [...]
  },
  "timestamp": "2024-11-16T17:30:00Z"
}
```

### **Compact Format**
```json
{"project":"MyPackage","targets":3,"dependencies":7,"issues":0,"status":"healthy"}
```

### **TOON Format**
```
| PROJECT MyPackage
| TARGETS 3
| DEPENDENCIES 7
| STATUS HEALTHY
```

## 🧪 **Testing**

```bash
# Run all tests
swift test

# Test specific functionality
swift test --filter ValidateTests
swift test --filter AnalyzeTests

# Test with sample packages
smith-spmsift validate --project ./TestPackage
```

## 📈 **Performance**

| Package Size | Analysis Time | Memory Usage |
|-------------|---------------|-------------|
| Small (5 deps) | ~100ms | ~3MB |
| Medium (15 deps) | ~800ms | ~12MB |
| Large (50+ deps) | ~3s | ~35MB |
| Complex (100+ deps) | ~8s | ~60MB |

## 🔍 **Issue Categories**

### **Critical Issues**
- **Exit Code 1**: Circular imports detected
- **Exit Code 0 with warnings**: Deep imports detected

### **Common Issues**
- **Missing platforms**: Incomplete platform support
- **Large dependencies**: Performance impact
- **Version conflicts**: Compatibility problems
- **Unused dependencies**: Package bloat

## 🔄 **Migration from swift package**

**Before:**
```bash
swift package dump-package
# Manual parsing of verbose output
```

**After:**
```bash
swift package dump-package | smith-spmsift parse --format json
# Structured, token-efficient analysis
```

## 🤝 **Contributing**

**Development Setup:**
```bash
git clone https://github.com/Smith-Tools/smith-spmsift
cd smith-spmsift
swift build
swift test
```

## 📄 **License**

Smith SPSift is available under the [MIT License](LICENSE).

## 🔗 **Related Projects**

- **[Smith Core](https://github.com/Smith-Tools/smith-core)** - Shared framework
- **[Smith CLI](https://github.com/Smith-Tools/smith-cli)** - Unified interface
- **[XCSift](https://github.com/Smith-Tools/xcsift)** - Xcode build analysis
- **[Smith SBSift](https://github.com/Smith-Tools/smith-sbsift)** - Swift build analysis

---

**Smith SPSift - Context-efficient Swift Package Manager analysis**