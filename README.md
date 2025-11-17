# smith-spmsift - Swift Package Manager Analysis

> **Context-efficient Swift Package Manager analysis for development and agentic workflows.**

Tool converting verbose Swift Package Manager output into structured, minimal-context JSON. Reduces output by 95%+ while preserving all diagnostic information for complex dependency analysis.

## 🎯 What is smith-spmsift?

smith-spmsift solves the context bloat problem:

**Problem:** SPM commands generate massive output:
- `swift package dump-package` → 200+ lines of JSON
- `swift package show-dependencies` → 100+ dependency tree
- `swift package resolve` → Verbose resolution logs

**Solution:** Structured JSON output with 95%+ context savings:
```bash
swift package dump-package | spmsift
# → {"targets": 61, "dependencies": 17, "issues": []}
```

**Result:** Complex packages like Scroll (61 targets, 17 dependencies) analyzed in minimal context.

## Installation

### From Source

```bash
git clone https://github.com/elkraneo/spmsift.git
cd spmsift
swift build -c release
cp .build/release/spmsift /usr/local/bin/
```

### Homebrew

```bash
# Custom tap is required (not in main Homebrew repository)
brew tap elkraneo/tap
brew install spmsift

# Verify installation
which spmsift  # Should show /opt/homebrew/bin/spmsift

# Access documentation
man spmsift    # Comprehensive manual page
```

**Note**: Both spmsift and sbsift are distributed via the custom tap `elkraneo/tap` and are not available in the official Homebrew core repository.

## Usage

### Basic Usage

```bash
# Analyze package structure
swift package dump-package | spmsift

# Analyze dependencies
swift package show-dependencies | spmsift

# Analyze resolution process
swift package resolve | spmsift
```

### Output Formats

```bash
# JSON output (default)
swift package dump-package | spmsift

# Summary format (minimal)
swift package dump-package | spmsift --format summary

# Detailed format (includes diagnostics)
swift package dump-package | spmsift --format detailed
```

### Filtering by Severity

```bash
# Only show errors and critical issues
swift package dump-package | spmsift --severity error

# Show all issues including info
swift package dump-package | spmsift --severity info
```

### Performance Metrics

```bash
# Include parse time and complexity metrics
swift package dump-package | spmsift --metrics
```

### Verbose Output

```bash
# Include raw output for debugging
swift package dump-package | spmsift --verbose
```

## Output Examples

### JSON Output

```json
{
  "command": "dump-package",
  "success": true,
  "targets": {
    "count": 61,
    "hasTestTargets": true,
    "platforms": ["iOS 15.0", "macOS 12.0"],
    "executables": ["MyApp"],
    "libraries": ["MyLibrary"]
  },
  "dependencies": {
    "count": 17,
    "external": [
      {
        "name": "swift-composable-architecture",
        "version": "1.23.1",
        "type": "source-control",
        "url": "https://github.com/pointfreeco/swift-composable-architecture"
      }
    ],
    "local": [],
    "circularImports": false,
    "versionConflicts": []
  },
  "issues": [
    {
      "type": "version_conflict",
      "severity": "warning",
      "target": "MyTarget",
      "message": "Using branch 'main' may cause instability"
    }
  ],
  "metrics": {
    "parseTime": 0.001,
    "complexity": "high",
    "estimatedIndexTime": "45-90s"
  }
}
```

### Summary Output

```json
{
  "command": "dump-package",
  "success": true,
  "targets": 61,
  "dependencies": 17,
  "issues": 1
}
```

## 🔄 Integration with Smith Tools

smith-spmsift works with the complete Smith Tools ecosystem:

- **smith-skill** - Architectural validation
- **smith-core** - Universal Swift patterns
- **smith-sbsift** - Swift build analysis
- **sosumi-skill** - Apple documentation

**Usage Pattern:**
```
Package issues? → smith-spmsift
Build errors? → smith-sbsift
Architecture? → smith-skill
API reference? → sosumi-skill
```

### Smith Skill Integration

```bash
#!/bin/bash
# Used by smith-skill validators
swift package dump-package 2>&1 | spmsift --format json
swift package show-dependencies 2>&1 | spmsift --analyze
```

### GitHub Actions Example

```yaml
- name: Analyze Package Structure
  run: |
    swift package dump-package | spmsift --format summary > package-analysis.json
    swift package show-dependencies | spmsift --format json >> deps.json
```

## 📊 Performance

| Metric | Before spmsift | After spmsift | Savings |
|--------|--------|----------|---------|
| Output Size | 200KB+ | < 5KB | 95%+ |
| Context Usage | High | Minimal | 95%+ |
| Parse Time | N/A | < 1ms | Instant |
| Error Detection | Manual | Automated | 100% |

## ✨ Features

- **Pipe-based interface** - Seamless integration like xcsift
- **Multi-command support** - dump-package, show-dependencies, resolve, describe, update
- **Structured JSON output** - Programmatic analysis and automation
- **Context-optimized** - < 5KB output for any package size
- **Error detection** - Identifies circular dependencies, version conflicts
- **High performance** - < 1ms parse time for large packages
- **Configurable output** - JSON, summary, detailed formats
- **Built-in metrics** - Performance and complexity analysis

## 📋 Requirements

- **Swift 5.5+**
- **macOS 11.0+** (Monterey or later)

## 🔗 Related Tools

- **[smith-sbsift](../smith-sbsift/)** - Swift build analysis
- **[smith-skill](../smith-skill/)** - Architecture validation
- **[smith-core](../smith-core/)** - Universal patterns
- **[xcsift](https://github.com/ldomaradzki/xcsift)** - Xcode build output analysis

## 🤝 Contributing

Contributions welcome! Please:

1. Report SPM analysis issues with examples
2. Suggest new output formats
3. Improve dependency resolution detection
4. Add integration examples
5. Follow commit message guidelines (see main README)

## 📄 License

MIT - See [LICENSE](LICENSE) for details

---

**smith-spmsift - Making Swift Package Manager analysis AI-friendly**

*Last updated: November 17, 2025*