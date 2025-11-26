---
name: smith-spmsift
description: Swift Package Manager analysis and dependency validation. Automatically triggers for:
             Package structure analysis, dependency resolution, SPM issues, circular imports
allowed-tools: [Bash, Read]
executables: ["~/.local/bin/smith-spmsift", ".build/release/smith-spmsift", "smith-spmsift"]
---

# Swift Package Manager Analysis

Analyzes Swift Package Manager output to extract package structure, dependencies, and issues.

## Automatic Usage

This skill activates when users ask about:
- "Analyze my package structure"
- "Check for dependency issues"
- "Show package dependencies"
- "Are there circular dependencies"
- "Package complexity analysis"

## Commands

**Analyze package structure** (token-optimized):
```bash
swift package dump-package | spmsift
# Returns: JSON with targets, dependencies, issues (~95% reduction vs raw output)

# With specific format
swift package dump-package | spmsift --format json
swift package dump-package | spmsift --format summary
swift package dump-package | spmsift --format detailed
```

**Analyze dependencies**:
```bash
swift package show-dependencies | spmsift --analyze
# Returns: Dependency tree analysis with conflict detection
```

**Analyze resolution process**:
```bash
swift package resolve | spmsift --format json
# Returns: Resolution metrics and any issues
```

**Include performance metrics**:
```bash
swift package dump-package | spmsift --metrics
# Returns: Parse time, complexity score, estimated index time
```

## Output Structure

- **targets**: Count, types (executable, library, test)
- **dependencies**: External, local, circular imports, version conflicts
- **issues**: Identified problems with severity levels
- **metrics**: Parse time, complexity, estimation data

## Integration with Smith Tools

Works with the Smith Tools ecosystem:

- **smith-sbsift** - Swift build analysis
- **smith-validation** - Architectural validation
- **smith-xcsift** - Xcode workspace analysis

## Performance

- Parse time: <1ms for large packages
- Output size: 95%+ reduction vs raw output
- Memory: Minimal streaming processing
- Context efficiency: <5KB output for any package size

## CI/CD Integration

Perfect for GitHub Actions and automated workflows:

```yaml
- name: Analyze Package
  run: swift package dump-package | spmsift --format json > package-analysis.json
```

---

**smith-spmsift** - Making Swift Package Manager analysis AI-friendly

Last Updated: November 26, 2025
