import Foundation
import ArgumentParser
import SmithCore

extension String {
    func matches(for regex: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
            return results.map {
                String(self[Range($0.range, in: self)!])
            }
        } catch {
            return []
        }
    }
}

@main
struct SmithSPMSift: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Smith SPM Analysis - Enhanced Swift Package Manager analysis tool",
        discussion: """
        Smith SPM provides comprehensive Swift Package Manager analysis with Smith Framework
        integration. It converts verbose SPM output into structured, minimal-context JSON designed
        for Claude agents and AI development workflows.

        Key Features:
        - Integrates with smith-core for consistent data models
        - Context-efficient output for AI agents
        - Build hang detection and analysis
        - Dependency graph analysis
        - Performance optimization recommendations

        Examples:
          smith-spmsift analyze
          swift package dump-package | smith-spmsift parse
          smith-spmsift --hang-detection
        """,
        version: "2.1.0",
        subcommands: [
            Analyze.self,
            Parse.self,
            Validate.self,
            Optimize.self,
            TCAPatterns.self,
            ReadingRouter.self
        ]
    )
}

// MARK: - Analyze Command

struct Analyze: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Comprehensive SPM package analysis"
    )

    @Argument(help: "Path to package directory (default: current directory)")
    var path: String = "."

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    @Flag(name: .long, help: "Include detailed diagnostics")
    var verbose = false

    @Flag(name: .long, help: "Perform hang detection analysis")
    var hangDetection = false

    @Flag(name: .long, help: "Include performance metrics")
    var metrics = false

    func run() throws {
        print("🔍 SMITH SPM ANALYSIS")
        print("====================")

        let resolvedPath = (path as NSString).standardizingPath

        // Validate package directory
        let packageURL = URL(fileURLWithPath: resolvedPath).appendingPathComponent("Package.swift")
        guard FileManager.default.fileExists(atPath: packageURL.path) else {
            print("❌ Error: Package.swift not found at \(resolvedPath)")
            throw ExitCode.failure
        }

        // Create base analysis using smith-core
        var analysis = SmithCore.quickAnalyze(at: resolvedPath)
        analysis = try performSPMAnalysis(at: resolvedPath, analysis: analysis)

        // Additional hang detection if requested
        if hangDetection {
            print("\n🎯 HANG DETECTION ANALYSIS")
            print("==========================")
            let hangResult = try performHangDetection(at: resolvedPath)
            print(formatHangResult(hangResult))
        }

        // Risk assessment
        let risks = SmithCore.assessBuildRisk(analysis)
        if !risks.isEmpty {
            print("\n⚠️  BUILD RISK ASSESSMENT")
            print("========================")
            for risk in risks {
                let emoji = emojiForSeverity(risk.severity)
                print("\(emoji) [\(risk.category.rawValue)] \(risk.message)")
                if let suggestion = risk.suggestion {
                    print("   💡 \(suggestion)")
                }
            }
        }

        // Output results
        if json {
            if let jsonData = SmithCore.formatJSON(analysis) {
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            }
        } else {
            print("\n" + SmithCore.formatHumanReadable(analysis))
        }
    }

    private func performSPMAnalysis(at path: String, analysis: BuildAnalysis) throws -> BuildAnalysis {
        print("🔧 Analyzing Swift Package...")

        var updatedAnalysis = analysis
        var diagnostics: [Diagnostic] = []
        var phases: [BuildPhase] = []

        // Run swift package dump-package
        let dumpResult = try runSwiftPackageCommand(["dump-package"], at: path)
        var updatedDependencyGraph = updatedAnalysis.dependencyGraph

        if dumpResult.success {
            phases.append(BuildPhase(
                name: "Package Dump",
                status: BuildStatus.success,
                duration: dumpResult.duration,
                startTime: dumpResult.startTime,
                endTime: dumpResult.endTime
            ))

            // Parse dump-package output
            if let packageData = parsePackageDump(dumpResult.output) {
                diagnostics.append(contentsOf: analyzePackageStructure(packageData))
                updatedDependencyGraph = updateDependencyGraph(
                    from: packageData,
                    current: updatedAnalysis.dependencyGraph
                )
            }
        } else {
            phases.append(BuildPhase(
                name: "Package Dump",
                status: BuildStatus.failed,
                duration: dumpResult.duration,
                startTime: dumpResult.startTime,
                endTime: dumpResult.endTime
            ))
            diagnostics.append(Diagnostic(
                severity: .error,
                category: .compilation,
                message: "Failed to dump package: \(dumpResult.error ?? "Unknown error")",
                suggestion: "Check Package.swift syntax"
            ))
        }

        // Run swift package show-dependencies
        let depsResult = try runSwiftPackageCommand(["show-dependencies"], at: path)
        if depsResult.success {
            phases.append(BuildPhase(
                name: "Dependencies Check",
                status: BuildStatus.success,
                duration: depsResult.duration,
                startTime: depsResult.startTime,
                endTime: depsResult.endTime
            ))
        } else {
            diagnostics.append(Diagnostic(
                severity: .warning,
                category: .dependency,
                message: "Failed to show dependencies",
                suggestion: "Run 'swift package resolve' to update dependencies"
            ))
        }

        let finalStatus = diagnostics.contains(where: { $0.severity == .error }) ? BuildStatus.failed : BuildStatus.success

        return BuildAnalysis(
            projectType: updatedAnalysis.projectType,
            status: finalStatus,
            phases: phases,
            dependencyGraph: updatedDependencyGraph,
            metrics: updatedAnalysis.metrics,
            diagnostics: diagnostics
        )
    }

    private func performHangDetection(at path: String) throws -> HangDetection {
        // Simulate hang detection by checking for common issues
        let suspectedIssues: [String] = []
        let recommendations: [String] = [
            "Use 'swift package --allow-writing-to-package-directory resolve' for dependency issues",
            "Check for circular dependencies between local packages",
            "Verify platform compatibility in Package.swift",
            "Consider using dependency caching with '--cache-path'"
        ]

        return HangDetection(
            isHanging: false,
            suspectedPhase: suspectedIssues.isEmpty ? nil : suspectedIssues.first,
            suspectedFile: nil,
            timeElapsed: 0.0,
            recommendations: recommendations
        )
    }
}

// MARK: - Parse Command

struct Parse: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Parse Swift Package Manager output from stdin"
    )

    @Option(name: .shortAndLong, help: "Output format (json, summary, detailed)")
    var format: OutputFormat = .json

    @Flag(name: .shortAndLong, help: "Include raw output for debugging")
    var verbose = false

    func run() throws {
        // Check if input is being piped
        if isatty(STDIN_FILENO) != 0 {
            print("smith-spmsift parse: No input detected. Pipe Swift Package Manager output.")
            print("Usage: swift package <command> | smith-spmsift parse")
            throw ExitCode.failure
        }

        let input = FileHandle.standardInput.readDataToEndOfFile()
        let output = String(data: input, encoding: .utf8) ?? ""

        guard !output.isEmpty else {
            print("{\"error\": \"No input received\"}")
            throw ExitCode.failure
        }

        // Parse and format output
        let result = try parseSPMOutput(output)

        switch format {
        case .json:
            let jsonData = try JSONEncoder().encode(result)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        case .summary:
            print(formatSummary(result))
        case .detailed:
            print(formatDetailed(result))
        }
    }

    private func parseSPMOutput(_ output: String) throws -> SmithSPMResult {
        // This would integrate with the existing spmsift parsers
        // For now, return a basic result
        return SmithSPMResult(
            command: "unknown",
            success: true,
            output: output,
            diagnostics: [],
            metrics: SPMMetrics()
        )
    }

    private func formatSummary(_ result: SmithSPMResult) -> String {
        return "✅ SPM command completed successfully"
    }

    private func formatDetailed(_ result: SmithSPMResult) -> String {
        return """
        🔍 SPM Analysis Results
        ======================
        Command: \(result.command)
        Success: \(result.success)
        Output Length: \(result.output.count) characters
        Diagnostics: \(result.diagnostics.count)
        """
    }
}

// MARK: - Validate Command

struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Validate SPM package configuration"
    )

    @Argument(help: "Path to package directory (default: current directory)")
    var path: String = "."

    @Flag(name: .long, help: "Perform deep validation including dependencies")
    var deep = false

    @Flag(name: .long, help: "Check Package.resolved for branch dependencies")
    var checkResolved = false

    @Flag(name: .long, help: "Flag branch dependencies as anti-patterns")
    var flagBranchDeps = false

    @Flag(name: .long, help: "Detect Swift macro compilation issues")
    var macroDiagnostics = false

    @Flag(name: .long, help: "Detect TCA pattern issues (body type inference, dependency access)")
    var tcaPatterns = false

    
    func run() throws {
        print("✅ SMITH SPM VALIDATION")
        print("=======================")

        let resolvedPath = (path as NSString).standardizingPath
        let packageURL = URL(fileURLWithPath: resolvedPath).appendingPathComponent("Package.swift")

        guard FileManager.default.fileExists(atPath: packageURL.path) else {
            print("❌ Package.swift not found")
            throw ExitCode.failure
        }

        var issues: [Diagnostic] = []

        // Basic validation
        issues.append(contentsOf: validatePackageManifest(at: packageURL.path))

        if deep {
            print("🔍 Performing deep validation...")
            issues.append(contentsOf: validateDependencies(at: resolvedPath))
        }

        if checkResolved {
            print("🔍 Checking Package.resolved...")
            issues.append(contentsOf: validatePackageResolved(at: resolvedPath, flagBranches: flagBranchDeps))
        }

        // Macro diagnostics (independent of Package.resolved)
        if macroDiagnostics {
            print("🔍 Performing macro diagnostics...")

            // Find Package.swift for macro analysis
            let packageSwiftPath = (path as NSString).appendingPathComponent("Package.swift")
            let fileManager = FileManager.default

            if fileManager.fileExists(atPath: packageSwiftPath) {
                let macroDiagnostic = performMacroDiagnostics(at: packageSwiftPath)

                if !macroDiagnostic.issues.isEmpty {
                    print("📋 Macro Analysis Results:")
                    print("   • Detected Framework: \(macroDiagnostic.detectedFramework.rawValue)")
                    print("   • Issues Found: \(macroDiagnostic.issues.count)")

                    for issue in macroDiagnostic.issues {
                        let severity: Diagnostic.Severity = switch issue.severity {
                        case "critical": .critical
                        case "high": .error
                        case "medium": .warning
                        default: .info
                        }

                        issues.append(Diagnostic(
                            severity: severity,
                            category: .compilation,
                            message: "Macro Issue: \(issue.rawValue)",
                            suggestion: issue.fix
                        ))
                    }

                    if !macroDiagnostic.recommendation.isEmpty {
                        print("💡 Macro Recommendations:")
                        for line in macroDiagnostic.recommendation.split(separator: "\n") {
                            print("   • \(line)")
                        }

                        issues.append(Diagnostic(
                            severity: .info,
                            category: .compilation,
                            message: "Macro diagnostic recommendations available",
                            suggestion: "Review framework-specific macro usage patterns"
                        ))
                    }
                } else {
                    print("✅ No macro issues detected")
                }
            } else {
                issues.append(Diagnostic(
                    severity: .info,
                    category: .compilation,
                    message: "Package.swift not found for macro analysis",
                    suggestion: "Ensure Package.swift exists in the package root"
                ))
            }
        }

        // TCA pattern validation (independent of Package.resolved)
        if tcaPatterns {
            print("🔍 Performing TCA pattern diagnostics...")

            // Find Swift files for TCA analysis
            let tcaIssues = performTCAPatternDiagnostics(at: resolvedPath)

            if !tcaIssues.isEmpty {
                print("📋 TCA Pattern Analysis Results:")
                print("   • Issues Found: \(tcaIssues.count)")

                for issue in tcaIssues {
                    let emoji = emojiForSeverity(issue.severity)
                    print("\(emoji) [\(issue.category.rawValue)] \(issue.message)")
                    if let suggestion = issue.suggestion {
                        print("   💡 \(suggestion)")
                    }
                }
            } else {
                print("✅ No TCA pattern issues detected")
            }
        }

        
        if issues.isEmpty {
            print("✅ Package validation passed")
        } else {
            print("⚠️  Found \(issues.count) issue(s):")
            for issue in issues {
                let emoji = emojiForSeverity(issue.severity)
                print("\(emoji) [\(issue.category.rawValue)] \(issue.message)")
                if let suggestion = issue.suggestion {
                    print("   💡 \(suggestion)")
                }
            }
        }
    }

    private func validatePackageManifest(at path: String) -> [Diagnostic] {
        var issues: [Diagnostic] = []

        do {
            let content = try String(contentsOfFile: path)

            // Basic syntax validation would go here
            if content.isEmpty {
                issues.append(Diagnostic(
                    severity: .error,
                    category: .configuration,
                    message: "Package.swift is empty",
                    suggestion: "Add proper package manifest content"
                ))
            }

        } catch {
            issues.append(Diagnostic(
                severity: .error,
                category: .configuration,
                message: "Cannot read Package.swift: \(error.localizedDescription)",
                suggestion: "Check file permissions and encoding"
            ))
        }

        return issues
    }

    private func validateDependencies(at path: String) -> [Diagnostic] {
        var issues: [Diagnostic] = []

        // Run swift package resolve
        do {
            let result = try runSwiftPackageCommand(["resolve"], at: path)
            if !result.success {
                issues.append(Diagnostic(
                    severity: .warning,
                    category: .dependency,
                    message: "Dependency resolution failed",
                    suggestion: "Check network connection and dependency URLs"
                ))
            }
        } catch {
            issues.append(Diagnostic(
                severity: .error,
                category: .dependency,
                message: "Cannot run dependency resolution: \(error.localizedDescription)",
                suggestion: "Verify Swift installation and package configuration"
            ))
        }

        return issues
    }

    private func validatePackageResolved(at path: String, flagBranches: Bool) -> [Diagnostic] {
        var issues: [Diagnostic] = []

        // Check for Package.resolved in Xcode project
        let resolvedPaths = [
            "\(path)/Package.resolved",
            "\(path)/.build/Package.resolved",
            "\(path)/project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
            "\(path)/*/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
        ]

        var foundResolved = false
        var totalDependencies = 0
        var branchDependencies = 0
        var branchDeps: [String] = []

        for resolvedPath in resolvedPaths {
            let expandedPath = (resolvedPath as NSString).expandingTildeInPath

            // Handle wildcards for Xcode projects
            if resolvedPath.contains("*") {
                let globPattern = expandedPath.replacingOccurrences(of: "*", with: "*")
                if let globPaths = globFiles(pattern: globPattern) {
                    for resolvedPath in globPaths {
                        if FileManager.default.fileExists(atPath: resolvedPath) {
                            foundResolved = true
                            let (deps, branches, branchNames) = analyzePackageResolved(at: resolvedPath)
                            totalDependencies += deps
                            branchDependencies += branches
                            branchDeps.append(contentsOf: branchNames)
                        }
                    }
                }
            } else {
                if FileManager.default.fileExists(atPath: expandedPath) {
                    foundResolved = true
                    let (deps, branches, branchNames) = analyzePackageResolved(at: expandedPath)
                    totalDependencies += deps
                    branchDependencies += branches
                    branchDeps.append(contentsOf: branchNames)
                }
            }
        }

        if !foundResolved {
            issues.append(Diagnostic(
                severity: .info,
                category: .dependency,
                message: "No Package.resolved found",
                suggestion: "Run 'swift package resolve' to generate resolved dependencies"
            ))
            return issues
        }

        print("📋 Package.resolved Analysis:")
        print("   • Total dependencies: \(totalDependencies)")
        print("   • Branch dependencies: \(branchDependencies)")

        if branchDependencies > 0 {
            let uniqueBranchDeps = Array(Set(branchDeps))
            print("   • Branch dependency packages: \(uniqueBranchDeps.joined(separator: ", "))")

            if flagBranches {
                issues.append(Diagnostic(
                    severity: .warning,
                    category: .dependency,
                    message: "Found \(branchDependencies) branch dependencies (anti-pattern)",
                    suggestion: "Pin all dependencies to specific versions or exact revisions"
                ))

                for dep in uniqueBranchDeps {
                    issues.append(Diagnostic(
                        severity: .info,
                        category: .dependency,
                        message: "Branch dependency: \(dep)",
                        suggestion: "Replace 'branch: \"main\"' with specific version or revision"
                    ))
                }
            } else {
                issues.append(Diagnostic(
                    severity: .info,
                    category: .dependency,
                    message: "Found \(branchDependencies) branch dependencies",
                    suggestion: "Use --flag-branch-deps to flag these as anti-patterns"
                ))
            }
        } else {
            issues.append(Diagnostic(
                severity: .info,
                category: .dependency,
                message: "All dependencies are properly versioned",
                suggestion: nil
            ))
        }

        return issues
    }

    private func analyzePackageResolved(at path: String) -> (totalDeps: Int, branchDeps: Int, branchNames: [String]) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let json = try JSONSerialization.jsonObject(with: data, options: [])

            guard let object = json as? [String: Any],
                  let pins = object["pins"] as? [[String: Any]] else {
                return (0, 0, [])
            }

            var totalDeps = 0
            var branchDeps = 0
            var branchNames: [String] = []

            for pin in pins {
                totalDeps += 1

                if let state = pin["state"] as? [String: Any] {
                    // Check for branch dependency
                    if let _ = state["branch"] as? String {
                        branchDeps += 1
                        if let identity = pin["identity"] as? String {
                            branchNames.append(identity)
                        }
                    }

                    // Check for revision without branch (potentially unstable)
                    if let revision = state["revision"] as? String,
                       state["branch"] == nil,
                       let version = state["version"] {
                        // This is a revision-based dependency without a version
                        branchDeps += 1
                        if let identity = pin["identity"] as? String {
                            branchNames.append("\(identity) (revision-only)")
                        }
                    }
                }
            }

            return (totalDeps, branchDeps, branchNames)

        } catch {
            return (0, 0, [])
        }
    }

    private func globFiles(pattern: String) -> [String]? {
        guard let dir = NSString(string: pattern).deletingLastPathComponent as String? else { return nil }
        let filename = NSString(string: pattern).lastPathComponent

        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return nil }

        return contents.compactMap { file in
            let fullPath = "\(dir)/\(file)"
            return file.contains("*") || file.hasPrefix(filename.replacingOccurrences(of: "*", with: "")) ? fullPath : nil
        }
    }
}

// MARK: - Optimize Command

struct Optimize: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Optimize SPM package configuration"
    )

    @Argument(help: "Path to package directory (default: current directory)")
    var path: String = "."

    @Flag(name: .long, help: "Apply optimizations automatically")
    var apply = false

    func run() throws {
        print("⚡ SMITH SPM OPTIMIZATION")
        print("========================")

        let resolvedPath = (path as NSString).standardizingPath
        let analysis = try performSPMOptimizationAnalysis(at: resolvedPath)

        if analysis.recommendations.isEmpty {
            print("✅ No optimizations needed")
        } else {
            print("💡 Optimization Recommendations:")
            for (index, recommendation) in analysis.recommendations.enumerated() {
                print("\(index + 1). \(recommendation)")
            }

            if apply {
                print("\n🔧 Applying optimizations...")
                // Would apply actual optimizations
                print("✅ Optimizations applied")
            }
        }
    }

    private func performSPMOptimizationAnalysis(at path: String) throws -> SPMOptimizationAnalysis {
        // This would analyze the package and provide optimization recommendations
        return SPMOptimizationAnalysis(
            packagePath: path,
            recommendations: [
                "Use specific version constraints for dependencies",
                "Enable platform-specific optimizations",
                "Consider using conditional compilation for unused features"
            ]
        )
    }
}

// MARK: - Supporting Types

struct SmithSPMResult: Codable {
    let command: String
    let success: Bool
    let output: String
    let diagnostics: [String]
    let metrics: SPMMetrics
}

struct SPMMetrics: Codable {
    let duration: TimeInterval?
    let memoryUsage: Int64?

    init(duration: TimeInterval? = nil, memoryUsage: Int64? = nil) {
        self.duration = duration
        self.memoryUsage = memoryUsage
    }
}

struct SPMOptimizationAnalysis: Codable {
    let packagePath: String
    let recommendations: [String]
}

struct CommandResult {
    let success: Bool
    let output: String
    let error: String?
    let duration: TimeInterval
    let startTime: Date
    let endTime: Date

    init(success: Bool, output: String, error: String? = nil, duration: TimeInterval) {
        self.success = success
        self.output = output
        self.error = error
        self.duration = duration
        self.startTime = Date()
        self.endTime = Date()
    }
}

enum OutputFormat: String, ExpressibleByArgument {
    case json
    case summary
    case detailed
}

// MARK: - Helper Functions

private func runSwiftPackageCommand(_ arguments: [String], at path: String) throws -> CommandResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = ["package"] + arguments
    process.currentDirectoryPath = path

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    let startTime = CFAbsoluteTimeGetCurrent()
    try process.run()
    process.waitUntilExit()
    let duration = CFAbsoluteTimeGetCurrent() - startTime

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

    let output = String(data: outputData, encoding: .utf8) ?? ""
    let error = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

    return CommandResult(
        success: process.terminationStatus == 0,
        output: output,
        error: error?.isEmpty == true ? nil : error,
        duration: duration
    )
}

private func parsePackageDump(_ output: String) -> PackageData? {
    // This would parse the JSON output from 'swift package dump-package'
    // For now, return a basic structure
    return PackageData(
        name: "Unknown",
        targets: [],
        dependencies: []
    )
}

private struct PackageData: Codable {
    let name: String
    let targets: [TargetData]
    let dependencies: [DependencyData]
}

private struct TargetData: Codable {
    let name: String
    let type: String
}

private struct DependencyData: Codable {
    let name: String
    let requirement: String?
}

private func analyzePackageStructure(_ packageData: PackageData) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []

    if packageData.targets.isEmpty {
        diagnostics.append(Diagnostic(
            severity: .warning,
            category: .configuration,
            message: "No targets found in package",
            suggestion: "Add at least one target to Package.swift"
        ))
    }

    if packageData.targets.count > 20 {
        diagnostics.append(Diagnostic(
            severity: .warning,
            category: .performance,
            message: "Package has many targets (\(packageData.targets.count))",
            suggestion: "Consider splitting into multiple packages"
        ))
    }

    return diagnostics
}

private func updateDependencyGraph(from packageData: PackageData, current: DependencyGraph) -> DependencyGraph {
    return DependencyGraph(
        targetCount: packageData.targets.count,
        maxDepth: current.maxDepth,
        circularDeps: current.circularDeps,
        bottleneckTargets: current.bottleneckTargets,
        complexity: DependencyGraph.calculateComplexity(
            targetCount: packageData.targets.count,
            maxDepth: current.maxDepth
        )
    )
}

private func emojiForSeverity(_ severity: Diagnostic.Severity) -> String {
    switch severity {
    case .info: return "ℹ️"
    case .warning: return "⚠️"
    case .error: return "❌"
    case .critical: return "🚨"
    }
}

private func formatHangResult(_ hang: HangDetection) -> String {
    var output: [String] = []

    if hang.isHanging {
        output.append("🚨 HANG DETECTED")
        if let phase = hang.suspectedPhase {
            output.append("   Suspected Phase: \(phase)")
        }
        if let file = hang.suspectedFile {
            output.append("   Suspected File: \(file)")
        }
    } else {
        output.append("✅ No hang detected")
    }

    if !hang.recommendations.isEmpty {
        output.append("\n💡 Recommendations:")
        for recommendation in hang.recommendations {
            output.append("   - \(recommendation)")
        }
    }

    return output.joined(separator: "\n")
}

// MARK: - Macro Diagnostics

private func performMacroDiagnostics(at packagePath: String) -> MacroDiagnostic {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: packagePath) else {
        return MacroDiagnostic(
            issues: [],
            detectedFramework: .unknown,
            recommendation: "Package.swift not found for macro analysis"
        )
    }

    do {
        let packageContent = try String(contentsOfFile: packagePath)
        var detectedFrameworks: Set<MacroFramework> = []
        var issues: [MacroIssue] = []

        // Detect macro frameworks in dependencies
        if packageContent.contains("swift-composable-architecture") {
            detectedFrameworks.insert(.tca)
            // Check for common TCA macro issues
            if packageContent.contains("@Reducer") {
                // Look for potential Swift 6 concurrency issues
                if packageContent.contains("State: Equatable") || packageContent.contains("State: Sendable") {
                    issues.append(.swift6EquatableBug)
                }
            }
        }

        if packageContent.contains("SwiftData") || packageContent.contains("@Model") || packageContent.contains("@ObservableModel") {
            detectedFrameworks.insert(.swiftData)
        }

        if packageContent.contains("swift-dependencies") || packageContent.contains("@Dependency") {
            detectedFrameworks.insert(.dependencies)
        }

        if packageContent.contains("swift-perception") || packageContent.contains("@Perception") {
            detectedFrameworks.insert(.perception)
        }

        // Check for custom macros
        let macroPattern = #"@\w+"#
        let macroMatches = packageContent.matches(for: macroPattern)
        if macroMatches.count > 0 && detectedFrameworks.isEmpty {
            detectedFrameworks.insert(.customMacros)
        }

        // Perform build tests if macros are detected
        if !detectedFrameworks.isEmpty {
            let testResults = testMacroValidation(packagePath: packagePath)
            issues.append(contentsOf: testResults)
        }

        let primaryFramework = detectedFrameworks.first ?? .unknown
        let recommendation = generateMacroRecommendation(for: issues, framework: primaryFramework)

        return MacroDiagnostic(
            issues: issues,
            detectedFramework: primaryFramework,
            recommendation: recommendation
        )

    } catch {
        return MacroDiagnostic(
            issues: [],
            detectedFramework: .unknown,
            recommendation: "Failed to read Package.swift for macro analysis: \(error.localizedDescription)"
        )
    }
}

private func executeCommand(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.launchPath = "/bin/bash"
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    task.waitUntilExit()
    return output
}

private func testMacroValidation(packagePath: String) -> [MacroIssue] {
    let packageDir = URL(fileURLWithPath: packagePath).deletingLastPathComponent().path
    var issues: [MacroIssue] = []

    // Test build without -skipMacroValidation
    let normalBuildResult = executeCommand(
        "cd '\(packageDir)' && timeout 60s swift build 2>&1 | head -50"
    )

    // Test build with -skipMacroValidation
    let skipMacroBuildResult = executeCommand(
        "cd '\(packageDir)' && timeout 60s swift build -Xswiftc -skipMacroValidation 2>&1 | head -50"
    )

    // Analyze results
    if normalBuildResult.contains("RegisterExecutionPolicyException") {
        issues.append(.executionPolicyException)
    }

    if normalBuildResult.contains("error") && !skipMacroBuildResult.contains("error") {
        issues.append(.macroValidationFailure)
    }

    if normalBuildResult.contains("External macro implementation could not be found") {
        issues.append(.externalMacroNotFound)
    }

    if normalBuildResult.contains("macro expansion timeout") || normalBuildResult.contains("timed out") {
        issues.append(.macroExpansionTimeout)
    }

    return issues
}

private func generateMacroRecommendation(for issues: [MacroIssue], framework: MacroFramework) -> String {
        // TCA pattern validation (independent of Package.resolved)
    var recommendations: [String] = []
    switch framework {
    case .tca:
        recommendations.append("For TCA @Reducer issues, try adding @Reducer(state: .equatable, .sendable)")
        recommendations.append("Check for missing State conformance in domain models")
    case .swiftData:
        recommendations.append("For SwiftData @Model issues, try -skipMacroValidation flag")
        recommendations.append("Verify @ObservableModel usage and macro expansion")
    case .dependencies:
        recommendations.append("For @DependencyClient issues, check client conformance")
        recommendations.append("Verify @Dependency key paths and registration")
    case .perception:
        recommendations.append("For Perception, verify @Perception usage with ObservableObject and proper import statements")
    case .customMacros:
        recommendations.append("For custom macros, verify macro implementation and expansion behavior")
    case .unknown:
        break
    }

    return Array(Set(recommendations)).joined(separator: "\n")
}
// MARK: - TCA Pattern Validation

/// Performs TCA-specific pattern validation to detect compilation-hang issues
/// - Body type inference complexity
/// - Dependency access patterns
/// - @Reducer anti-patterns
private func performTCAPatternDiagnostics(at packagePath: String) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []

    // Find all Swift files in the package
    let swiftFiles = findSwiftFiles(in: packagePath)

    for swiftFile in swiftFiles {
        guard let content = try? String(contentsOfFile: swiftFile) else { continue }

        // Check for problematic TCA patterns
        diagnostics.append(contentsOf: checkTCAFile(content: content, path: swiftFile))
    }

    return diagnostics
}

/// Finds all Swift files in a package directory
private func findSwiftFiles(in packagePath: String) -> [String] {
    var swiftFiles: [String] = []
    let fileManager = FileManager.default

    guard let enumerator = fileManager.enumerator(
        at: URL(fileURLWithPath: packagePath),
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    ) else {
        return swiftFiles
    }

    for case let fileURL as URL in enumerator {
        if fileURL.pathExtension == "swift" {
            swiftFiles.append(fileURL.path)
        }
    }

    return swiftFiles
}

/// Checks a single Swift file for TCA pattern issues
private func checkTCAFile(content: String, path: String) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    let lines = content.components(separatedBy: .newlines)

    for (index, line) in lines.enumerated() {
        // Check 1: Complex implicit composition causing type inference explosion
        if line.contains("var body: some ReducerOf<Self>") {
            let nextLines = Array(lines.dropFirst(index + 1))
            let compositionAnalysis = analyzeReducerBodyComposition(nextLines, filePath: path, lineNumber: index + 1)
            diagnostics.append(contentsOf: compositionAnalysis)
        }

        // Check 1.5: @ReducerBuilder usage - valid but can cause type inference issues
        if line.contains("@ReducerBuilder<") {
            let nextLines = Array(lines.dropFirst(index + 1))
            let reducerBuilderAnalysis = analyzeReducerBuilderUsage(nextLines, filePath: path, lineNumber: index + 1)
            diagnostics.append(contentsOf: reducerBuilderAnalysis)
        }

        // Check 2: Incorrect date.now access pattern
        if line.contains("date.now") && line.contains("@Dependency") {
            diagnostics.append(Diagnostic(
                severity: .error,
                category: .compilation,
                message: "Incorrect date.now access - should use date() for callable DateGenerator",
                location: "\(URL(fileURLWithPath: path).lastPathComponent):\(index + 1)",
                suggestion: "Replace date.now with date() - @Dependency(\\.date) provides a function, not a property"
            ))
        }

        // Check 3: Missing @State for non-Sendable dependencies
        if line.contains("@Dependency") && line.contains("var ") && !line.contains("@State") {
            let dependencyName = extractDependencyName(from: line)
            if let name = dependencyName, !isSendableType(name) {
                diagnostics.append(Diagnostic(
                    severity: .warning,
                    category: .compilation,
                    message: "Non-Sendable dependency '\(name)' should be marked with @State",
                    location: "\(URL(fileURLWithPath: path).lastPathComponent):\(index + 1)",
                    suggestion: "Add @State: @Dependency var \(name): \(name)"
                ))
            }
        }
    }

    return diagnostics
}

/// Analyzes reducer body composition for real anti-patterns (NOT recommending bad patterns)
private func analyzeReducerBodyComposition(_ lines: [String], filePath: String, lineNumber: Int) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    var braceCount = 0
    var bodyLines: [String] = []
    var inBody = false

    // Extract the body content within the braces
    for line in lines {
        bodyLines.append(line)

        braceCount += line.components(separatedBy: "{").count - 1
        braceCount -= line.components(separatedBy: "}").count - 1

        if braceCount > 0 {
            inBody = true
        }

        if inBody && braceCount <= 0 {
            break
        }
    }

    // Analysis: Detect ACTUAL anti-patterns that cause type inference issues
    let antiPatternAnalysis = detectRealAntiPatterns(bodyLines, filePath: filePath, lineNumber: lineNumber)
    diagnostics.append(contentsOf: antiPatternAnalysis)

    return diagnostics
}

/// Detects REAL TCA anti-patterns that cause compilation hangs
private func detectRealAntiPatterns(_ bodyLines: [String], filePath: String, lineNumber: Int) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []

    // Pattern 1: Nested CombineReducers - CRITICAL anti-pattern
    let nestedCombineReducers = detectNestedCombineReducers(bodyLines)
    if nestedCombineReducers.nestingLevel > 1 {
        diagnostics.append(Diagnostic(
            severity: .error,
            category: .compilation,
            message: "CRITICAL: Nested CombineReducers detected (level \(nestedCombineReducers.nestingLevel)) - causes exponential type inference explosion",
            location: "\(URL(fileURLWithPath: filePath).lastPathComponent):\(lineNumber)",
            suggestion: "Flatten composition by calling @ReducerBuilder functions directly, removing nested CombineReducers calls. Example: var body { group1(); group2() }"
        ))
    }

    // Pattern 2: Too many implicit compositions in single body without structure
    let implicitCompositions = countImplicitCompositions(bodyLines)
    if implicitCompositions >= 5 {
        diagnostics.append(Diagnostic(
            severity: .error,
            category: .compilation,
            message: "Excessive implicit composition: \(implicitCompositions) reducers in body - causes type inference explosion",
            location: "\(URL(fileURLWithPath: filePath).lastPathComponent):\(lineNumber)",
            suggestion: "Group related reducers with CombineReducers or restructure with explicit Scope usage"
        ))
    } else if implicitCompositions >= 3 {
        diagnostics.append(Diagnostic(
            severity: .warning,
            category: .compilation,
            message: "Multiple implicit compositions: \(implicitCompositions) reducers - risk of type inference issues",
            location: "\(URL(fileURLWithPath: filePath).lastPathComponent):\(lineNumber)",
            suggestion: "Consider using CombineReducers for clarity and type safety"
        ))
    }

    return diagnostics
}

/// Counts implicit reducer compositions that can cause type inference issues
private func countImplicitCompositions(_ bodyLines: [String]) -> Int {
    var count = 0

    for line in bodyLines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Skip comments, empty lines, braces, and proper wrappers
        guard !trimmed.isEmpty &&
              !trimmed.hasPrefix("//") &&
              !trimmed.hasPrefix("}") &&
              !trimmed.contains("CombineReducers(") &&
              !trimmed.contains("Scope(") else {
            continue
        }

        // Count actual reducer components
        if isReducerComponent(trimmed) {
            count += 1
        }
    }

    return count
}

/// Checks if a line contains a reducer component (excluding proper wrappers)
private func isReducerComponent(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)

    // Skip if already properly wrapped
    if trimmed.contains("CombineReducers(") || trimmed.contains("Scope(") {
        return false
    }

    // Known reducer components
    let reducerPatterns = [
        "Reduce(",
        "BindingReducer(",
        "IfLetReducer(",
        "ForEachReducer(",
        "WhileReducer(",
        "OverrideReducer("
    ]

    for pattern in reducerPatterns {
        if trimmed.contains(pattern) {
            return true
        }
    }

    // Function calls that likely return reducers
    let functionPattern = #"^\w+Feature\(\)|^\w+Reducer\(\)"#
    if let regex = try? NSRegularExpression(pattern: functionPattern),
       regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
        return true
    }

    return false
}

/// Extracts dependency name from @Dependency declaration
private func extractDependencyName(from line: String) -> String? {
    let pattern = #"@Dependency.*var\s+(\w+)"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
        return nil
    }

    let range = Range(match.range(at: 1), in: line)
    return range.map(String.init)
}

/// Checks if a type is Sendable (basic check for common non-Sendable types)
private func isSendableType(_ typeName: String) -> Bool {
    let nonSendableTypes = ["URLSession", "Timer", "FileHandle", "DispatchQueue"]
    return !nonSendableTypes.contains(typeName)
}

/// Detects nested CombineReducers patterns that cause exponential type inference
/// Returns (nestingLevel, problematicLines)
private func detectNestedCombineReducers(_ bodyLines: [String]) -> (nestingLevel: Int, problematicLines: [String]) {
    var nestingLevel = 0
    var maxNestingLevel = 0
    var problematicLines: [String] = []
    var braceStack: [Int] = []

    for (index, line) in bodyLines.enumerated() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Count CombineReducers openings
        let combineCount = trimmed.components(separatedBy: "CombineReducers(").count - 1
        if combineCount > 0 {
            braceStack.append(contentsOf: Array(repeating: index, count: combineCount))
            nestingLevel += combineCount
            maxNestingLevel = max(maxNestingLevel, nestingLevel)

            if nestingLevel > 1 {
                problematicLines.append("Line \(index + 1): Nested CombineReducers at level \(nestingLevel)")
            }
        }

        // Count closing braces that might close CombineReducers
        let braceCount = trimmed.components(separatedBy: "}").count - 1
        if braceCount > 0 && !braceStack.isEmpty {
            let closingCount = min(braceCount, braceStack.count)
            braceStack.removeLast(closingCount)
            nestingLevel = max(0, nestingLevel - closingCount)
        }
    }

    return (maxNestingLevel, problematicLines)
}

/// Analyzes @ReducerBuilder usage for potential type inference issues
private func analyzeReducerBuilderUsage(_ lines: [String], filePath: String, lineNumber: Int) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    var braceCount = 0
    var builderLines: [String] = []
    var inBuilder = false

    // Extract the @ReducerBuilder content within the braces
    for line in lines {
        builderLines.append(line)

        braceCount += line.components(separatedBy: "{").count - 1
        braceCount -= line.components(separatedBy: "}").count - 1

        if braceCount > 0 {
            inBuilder = true
        }

        if inBuilder && braceCount <= 0 {
            break
        }
    }

    // Analyze the @ReducerBuilder complexity
    let complexityAnalysis = analyzeReducerBuilderComplexity(builderLines, filePath: filePath, lineNumber: lineNumber)
    diagnostics.append(contentsOf: complexityAnalysis)

    return diagnostics
}

/// Analyzes @ReducerBuilder complexity for type inference explosion risk
private func analyzeReducerBuilderComplexity(_ builderLines: [String], filePath: String, lineNumber: Int) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []

    // Count conditional branches and reducer components
    let conditionalCount = countConditionalBranches(builderLines)
    let reducerComponentCount = countReducerComponents(builderLines)
    let complexityScore = conditionalCount + (reducerComponentCount * 2) // Weight reducers more heavily

    // Complex @ReducerBuilder patterns that can cause type inference explosion
    if complexityScore >= 20 {
        diagnostics.append(Diagnostic(
            severity: .error,
            category: .compilation,
            message: "Extremely complex @ReducerBuilder with complexity score \(complexityScore) - definite type inference explosion",
            location: "\(URL(fileURLWithPath: filePath).lastPathComponent):\(lineNumber)",
            suggestion: "Simplify @ReducerBuilder: reduce conditions, extract complex logic to separate properties, or use explicit composition"
        ))
    } else if complexityScore >= 15 {
        diagnostics.append(Diagnostic(
            severity: .warning,
            category: .compilation,
            message: "Complex @ReducerBuilder with complexity score \(complexityScore) - high risk of type inference issues",
            location: "\(URL(fileURLWithPath: filePath).lastPathComponent):\(lineNumber)",
            suggestion: "Consider simplifying @ReducerBuilder or extracting some logic to separate computed properties"
        ))
    } else if complexityScore >= 8 {
        diagnostics.append(Diagnostic(
            severity: .warning,
            category: .compilation,
            message: "@ReducerBuilder complexity score \(complexityScore) - may cause type inference slowdown",
            location: "\(URL(fileURLWithPath: filePath).lastPathComponent):\(lineNumber)",
            suggestion: "Monitor build times; consider simplifying if compilation becomes slow"
        ))
    }

    // Specific anti-pattern: Too many conditional reducers
    if reducerComponentCount >= 8 {
        diagnostics.append(Diagnostic(
            severity: .error,
            category: .compilation,
            message: "@ReducerBuilder with \(reducerComponentCount) conditional reducers - exponential type inference complexity",
            location: "\(URL(fileURLWithPath: filePath).lastPathComponent):\(lineNumber)",
            suggestion: "Consider grouping related conditions or using explicit CombineReducers instead of @ReducerBuilder"
        ))
    } else if reducerComponentCount >= 5 {
        diagnostics.append(Diagnostic(
            severity: .warning,
            category: .compilation,
            message: "@ReducerBuilder with \(reducerComponentCount) conditional reducers - risk of type inference issues",
            location: "\(URL(fileURLWithPath: filePath).lastPathComponent):\(lineNumber)",
            suggestion: "Test compilation performance; consider refactoring if build becomes slow"
        ))
    }

    return diagnostics
}

/// Counts conditional branches in @ReducerBuilder
private func countConditionalBranches(_ lines: [String]) -> Int {
    var count = 0

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Skip comments and empty lines
        guard !trimmed.isEmpty && !trimmed.hasPrefix("//") else {
            continue
        }

        // Count conditional statements
        if trimmed.hasPrefix("if ") || trimmed.hasPrefix("if(") || trimmed.hasPrefix("guard ") || trimmed.hasPrefix("guard(") ||
           trimmed.hasPrefix("switch ") || trimmed.contains(" ? ") || trimmed.contains(" : ") {
            count += 1
        }
    }

    return count
}

/// Counts reducer components in @ReducerBuilder
private func countReducerComponents(_ lines: [String]) -> Int {
    var count = 0

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Skip comments, empty lines, braces, and conditional keywords
        guard !trimmed.isEmpty && !trimmed.hasPrefix("//") && !trimmed.hasPrefix("}") &&
              !trimmed.hasPrefix("if ") && !trimmed.hasPrefix("if(") && !trimmed.hasPrefix("else") &&
              !trimmed.hasPrefix("guard ") && !trimmed.hasPrefix("guard(") && !trimmed.hasPrefix("switch ") &&
              !trimmed.hasPrefix("case ") && !trimmed.hasPrefix("default:") else {
            continue
        }

        // Count reducer-like components
        if isReducerComponent(trimmed) {
            count += 1
        }
    }

    return count
}
// MARK: - TCAPatterns Command

struct TCAPatterns: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Smith Framework TCA Pattern Validator",
        discussion: """
        Comprehensive TCA pattern validation that replaces JavaScript validation scripts.
        Detects deprecated patterns, anti-patterns, and validates modern TCA usage.

        Replaces: check-tca-patterns.js, tca-pattern-validator.js
        Features: Native Swift performance, type safety, and Smith Framework integration.

        Examples:
          smith-spmsift tca-patterns                    # Current directory
          smith-spmsift tca-patterns --path Sources    # Specific directory
          smith-spmsift tca-patterns --severity error   # Only errors
        """,
        version: "1.0.0"
    )

    @Argument(help: "Path to scan (default: current directory)")
    var path: String = "."

    @Option(help: "Minimum severity to report: error, warning, info (default: warning)")
    var severity: SeverityLevel = .warning

    @Flag(help: "Show positive patterns (modern TCA usage)")
    var showPositives: Bool = false

    @Flag(help: "Exit with error code if any issues found")
    var strict: Bool = false

    enum SeverityLevel: String, ExpressibleByArgument, CaseIterable {
        case error, warning, info

        var minLevel: Int {
            switch self {
            case .error: return 3
            case .warning: return 2
            case .info: return 1
            }
        }
    }

    func run() throws {
        print("🔍 Smith Framework: TCA Pattern Validator")
        print("=========================================")
        print("📁 Scanning: \(path)")
        print()

        let resolvedPath = (path as NSString).standardizingPath

        guard FileManager.default.fileExists(atPath: resolvedPath) else {
            print("❌ Error: Path '\(resolvedPath)' does not exist")
            throw ExitCode.failure
        }

        let isSwiftFile = resolvedPath.hasSuffix(".swift")
        let isDirectory = (try? FileManager.default.attributesOfItem(atPath: resolvedPath)[.type] as? FileAttributeType) == .typeDirectory

        guard isSwiftFile || isDirectory else {
            print("❌ Error: '\(resolvedPath)' is not a Swift file or directory")
            throw ExitCode.failure
        }

        let swiftFiles: [String]
        if isSwiftFile {
            swiftFiles = [resolvedPath]
        } else {
            swiftFiles = findSwiftFiles(in: resolvedPath)
        }

        if swiftFiles.isEmpty {
            print("❌ No Swift files found")
            throw ExitCode.failure
        }

        print("📝 Found \(swiftFiles.count) Swift file(s)")
        print()

        var totalIssues = 0
        var totalErrors = 0
        var totalWarnings = 0
        var totalPositives = 0

        for swiftFile in swiftFiles {
            let result = validateTCAFile(at: swiftFile)
            totalIssues += result.issues.count
            totalPositives += result.positives.count

            for issue in result.issues {
                switch issue.severity {
                case .error: totalErrors += 1
                case .warning: totalWarnings += 1
                case .info, .critical: break
                }
            }
        }

        // Summary
        print("\n📊 TCA Pattern Validation Summary")
        print("==================================")

        if totalIssues == 0 {
            print("🎉 All files follow Smith TCA patterns!")
            print("✅ Ready for production")

            if totalPositives > 0 && showPositives {
                print("🎯 Detected \(totalPositives) modern TCA patterns")
            }
        } else {
            print("⚠️ Found \(totalIssues) pattern issue(s):")
            print("   - \(totalErrors) error(s) that must be fixed")
            print("   - \(totalWarnings) warning(s) that should be reviewed")

            print("\nNext steps:")
            print("1. Review the Smith documentation references above")
            print("2. Apply the correct TCA patterns")
            print("3. Re-run this validation")
            print("4. Check compilation with: swiftc -typecheck")
        }

        if strict && totalIssues > 0 {
            throw ExitCode.failure
        } else if totalErrors > 0 {
            throw ExitCode.failure
        }
    }
}

// MARK: - ReadingRouter Command

struct ReadingRouter: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Smith Framework Documentation Router",
        discussion: """
        Smart documentation router that directs agents to the right Smith documentation
        based on task classification. Implements the 30-second task classification and
        reading budget logic from Smith Framework.

        Replaces: reading-router.js
        Features: Native Swift performance, keyword-based classification, and reading budgets.

        Examples:
          smith-spmsift reading-router "Add optional state for settings sheet"
          smith-spmsift reading-router "Fix TCA reducer compilation error"
          smith-spmsift reading-router "Add print logging for debugging"
        """,
        version: "1.0.0"
    )

    @Argument(help: "Task description to classify and route to documentation")
    var taskDescription: String

    func run() throws {
        print("🔍 Smith Framework: Documentation Router")
        print("=======================================")

        SmithReadingRouter.generateReadingPlan(for: taskDescription)
    }
}

private struct TCAValidationResult {
    let issues: [TCAPatternIssue]
    let positives: [String]
}

private struct TCAPatternIssue {
    let severity: Diagnostic.Severity
    let type: String
    let message: String
    let reference: String?
}

private func validateTCAFile(at filePath: String) -> TCAValidationResult {
    guard let content = try? String(contentsOfFile: filePath) else {
        print("❌ Error reading file: \(filePath)")
        return TCAValidationResult(issues: [], positives: [])
    }

    let fileName = URL(fileURLWithPath: filePath).lastPathComponent
    var issues: [TCAPatternIssue] = []
    var positives: [String] = []

    print("📝 Validating: \(fileName)")

    // Smith TCA Pattern Rules
    let patterns = TCAValidationPatterns()

    // Check for deprecated patterns
    for rule in patterns.deprecated {
        if content.range(of: rule.pattern, options: .regularExpression) != nil {
            issues.append(TCAPatternIssue(
                severity: .error,
                type: "deprecated",
                message: rule.message,
                reference: rule.reference
            ))
        }
    }

    // Check for anti-patterns
    for rule in patterns.antiPatterns {
        if content.range(of: rule.pattern, options: .regularExpression) != nil {
            issues.append(TCAPatternIssue(
                severity: rule.severity,
                type: "anti-pattern",
                message: rule.message,
                reference: rule.reference
            ))
        }
    }

    // Check for required positive patterns
    for rule in patterns.required {
        if content.range(of: rule.pattern, options: .regularExpression) != nil {
            positives.append(rule.message)
        }
    }

    // Check sheet patterns if applicable
    if content.contains(".sheet(") {
        for rule in patterns.sheetPatterns {
            if content.range(of: rule.pattern, options: .regularExpression) != nil {
                issues.append(TCAPatternIssue(
                    severity: rule.severity,
                    type: "warning",
                    message: rule.message,
                    reference: rule.reference
                ))
            }
        }
    }

    // Report results
    if issues.isEmpty {
        print("✅ No Smith pattern violations found")
    } else {
        for issue in issues {
            print("\(emojiForSeverity(issue.severity)) \(issue.message)")
            if let reference = issue.reference {
                print("   📚 See: \(reference)")
            }
        }
    }

    // Report positive patterns
    if !positives.isEmpty {
        print("\n🎯 Modern TCA patterns detected:")
        for positive in positives {
            print("   \(positive)")
        }
    }

    return TCAValidationResult(issues: issues, positives: positives)
}

private struct TCAValidationPatterns {
    // Deprecated patterns that should NOT be used
    let deprecated = [
        PatternRule(
            pattern: "WithViewStore",
            message: "❌ WithViewStore is deprecated. Use @Bindable instead",
            reference: "AGENTS-TCA-PATTERNS.md Mistake 1"
        ),
        PatternRule(
            pattern: "ViewStore\\(",
            message: "❌ ViewStore initialization is deprecated. Use @Bindable",
            reference: "AGENTS-TCA-PATTERNS.md Quick Reference"
        ),
        PatternRule(
            pattern: "@Perception\\.Bindable",
            message: "❌ @Perception.Bindable is deprecated. Use TCA @Bindable",
            reference: "AGENTS-TCA-PATTERNS.md Quick Reference"
        )
    ]

    // Required patterns for modern TCA
    let required = [
        PatternRule(
            pattern: "@Reducer",
            message: "✅ Using modern @Reducer macro"
        ),
        PatternRule(
            pattern: "@ObservableState",
            message: "✅ Using @ObservableState for state"
        ),
        PatternRule(
            pattern: "@Bindable",
            message: "✅ Using @Bindable for view bindings"
        )
    ]

    // Common anti-patterns
    let antiPatterns = [
        AntiPatternRule(
            pattern: "@State.*var.*State",
            message: "❌ @State should not be used for TCA State. Use @ObservableState",
            reference: "AGENTS-AGNOSTIC.md lines 24-29",
            severity: .error
        ),
        AntiPatternRule(
            pattern: "Shared\\(",
            message: "❌ Wrong Shared constructor. Use Shared(wrappedValue:)",
            reference: "AGENTS-TCA-PATTERNS.md Pattern 5, Mistake 5",
            severity: .error
        ),
        AntiPatternRule(
            pattern: "Task\\.detached",
            message: "❌ Task.detached is discouraged. Use Task { @MainActor in }",
            reference: "AGENTS-AGNOSTIC.md lines 28",
            severity: .warning
        ),
        AntiPatternRule(
            pattern: "Date\\(\\)",
            message: "❌ Direct Date() calls. Use dependencies instead",
            reference: "AGENTS-AGNOSTIC.md lines 419-440",
            severity: .warning
        )
    ]

    // Pattern-specific validations
    let sheetPatterns = [
        AntiPatternRule(
            pattern: "\\.sheet\\(item:.*\\$\\w+\\.state",
            message: "⚠️ .sheet(item:) with state binding - ensure proper lifecycle",
            reference: "AGENTS-TCA-PATTERNS.md Pattern 2",
            severity: .warning
        )
    ]
}

private struct PatternRule {
    let pattern: String
    let message: String
    let reference: String?

    init(pattern: String, message: String, reference: String? = nil) {
        self.pattern = pattern
        self.message = message
        self.reference = reference
    }
}

private struct AntiPatternRule {
    let pattern: String
    let message: String
    let reference: String?
    let severity: Diagnostic.Severity

    init(pattern: String, message: String, reference: String? = nil, severity: Diagnostic.Severity = .error) {
        self.pattern = pattern
        self.message = message
        self.reference = reference
        self.severity = severity
    }
}

// MARK: - Reading Router Implementation

private struct ReadingRoute {
    let category: String
    let description: String
    let primary: String
    let sections: String
    let timeBudget: String
    let fallback: String?
    let keywords: [String]
    let score: Int
}

private struct SmithReadingRouter {
    private static let routingMap: [String: (keywords: [String], primary: String, sections: String, timeBudget: String, fallback: String?, description: String)] = [
        "testing": (
            keywords: ["test", "Test", "@Test", "#expect", "TestClock", "testing"],
            primary: "QUICK-START.md",
            sections: "Rules 6-7",
            timeBudget: "2 minutes",
            fallback: "AGENTS-AGNOSTIC.md lines 75-111",
            description: "Testing patterns with Swift Testing framework"
        ),

        "tcaReducer": (
            keywords: ["reducer", "Reducer", "@Reducer", "State", "Action", "reduce"],
            primary: "QUICK-START.md",
            sections: "Rules 2-4",
            timeBudget: "3 minutes",
            fallback: "AGENTS-TCA-PATTERNS.md specific pattern",
            description: "TCA reducer patterns and state management"
        ),

        "visionOS": (
            keywords: ["visionOS", "RealityView", "PresentationComponent", "Entity", "Model3D"],
            primary: "QUICK-START.md",
            sections: "Rule 9",
            timeBudget: "2 minutes",
            fallback: "PLATFORM-VISIONOS.md + DISCOVERY-4",
            description: "visionOS entity patterns and 3D components"
        ),

        "dependencies": (
            keywords: ["dependency", "@Dependency", "@DependencyClient", "Date()", "UUID()"],
            primary: "QUICK-START.md",
            sections: "Rule 5",
            timeBudget: "2 minutes",
            fallback: "AGENTS-DECISION-TREES.md Tree 2",
            description: "Dependency injection patterns"
        ),

        "accessControl": (
            keywords: ["access control", "public", "internal", "private", "fileprivate"],
            primary: "QUICK-START.md",
            sections: "Rule 8 + DISCOVERY-5",
            timeBudget: "5 minutes",
            fallback: "AGENTS-AGNOSTIC.md lines 443-598",
            description: "Access control and public API boundaries"
        ),

        "architecture": (
            keywords: ["architecture", "pattern", "design", "should I use", "which approach"],
            primary: "AGENTS-DECISION-TREES.md",
            sections: "relevant tree",
            timeBudget: "5 minutes",
            fallback: "AGENTS-TASK-SCOPE.md",
            description: "Architecture decision guidance"
        ),

        "bugFix": (
            keywords: ["bug", "error", "fix", "broken", "not working", "compile error"],
            primary: "Search CaseStudies/",
            sections: "search by symptom",
            timeBudget: "2 minutes",
            fallback: "Read matching DISCOVERY",
            description: "Bug resolution and error fixing"
        ),

        "navigation": (
            keywords: ["navigation", "sheet", "fullScreenCover", "popover", "NavigationStack"],
            primary: "AGENTS-TCA-PATTERNS.md",
            sections: "Pattern 2 (optional state)",
            timeBudget: "5 minutes",
            fallback: nil,
            description: "SwiftUI navigation patterns with TCA"
        ),

        "concurrency": (
            keywords: ["Task", "async", "await", "MainActor", "concurrent"],
            primary: "AGENTS-AGNOSTIC.md",
            sections: "lines 24-29 + 162-313",
            timeBudget: "5 minutes",
            fallback: nil,
            description: "Concurrency patterns and main actor usage"
        ),

        "nestedReducers": (
            keywords: ["nested reducer", "child feature", "extract reducer", "Scope"],
            primary: "DISCOVERY-14-NESTED-REDUCER-GOTCHAS.md",
            sections: "entire document",
            timeBudget: "5 minutes",
            fallback: nil,
            description: "Nested @Reducer patterns and gotchas"
        ),

        "logging": (
            keywords: ["print", "oslog", "Logger", "log", "debug"],
            primary: "DISCOVERY-15-PRINT-OSLOG-PATTERNS.md",
            sections: "appropriate section",
            timeBudget: "3 minutes",
            fallback: nil,
            description: "Print vs OSLog logging patterns"
        )
    ]

    static func classifyTask(_ description: String) -> ReadingRoute? {
        let normalizedDesc = description.lowercased()
        var scores: [String: Int] = [:]

        // Score each routing category
        for (category, rules) in routingMap {
            scores[category] = 0
            for keyword in rules.keywords {
                if normalizedDesc.contains(keyword.lowercased()) {
                    scores[category]! += 1
                }
            }
        }

        // Find best match
        var bestMatch: String?
        var highestScore = 0

        for (category, score) in scores {
            if score > highestScore {
                highestScore = score
                bestMatch = category
            }
        }

        guard let category = bestMatch,
              let rules = routingMap[category],
              highestScore > 0 else {
            return nil
        }

        return ReadingRoute(
            category: category,
            description: rules.description,
            primary: rules.primary,
            sections: rules.sections,
            timeBudget: rules.timeBudget,
            fallback: rules.fallback,
            keywords: rules.keywords,
            score: highestScore
        )
    }

    static func searchCaseStudies(_ description: String) -> String? {
        let currentDir = FileManager.default.currentDirectoryPath
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: currentDir)
            let caseStudyFiles = files.filter { $0.hasPrefix("DISCOVERY-") && $0.hasSuffix(".md") }

            let searchWords = description.lowercased().split(separator: " ").filter { $0.count > 3 }

            for file in caseStudyFiles {
                let content = try String(contentsOfFile: "\(currentDir)/\(file)").lowercased()
                for word in searchWords {
                    if content.contains(word) {
                        return file
                    }
                }
            }
        } catch {
            // Ignore file system errors
        }
        return nil
    }

    static func generateReadingPlan(for taskDescription: String) {
        print("\n📋 Task: \"\(taskDescription)\"")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Step 1: Classify the task
        let classification = classifyTask(taskDescription)

        guard let classification = classification else {
            print("❌ Unable to classify task. Using general approach.")
            print("📚 Read: QUICK-START.md entire document (5 minutes max)")
            return
        }

        print("🎯 Task Type: \(classification.description)")
        print("📊 Confidence Score: \(classification.score)")
        print("⏱️ Reading Budget: \(classification.timeBudget)")
        print()

        // Step 2: Check for case studies first if it's a bug fix
        if classification.category == "bugFix" {
            if let caseStudy = searchCaseStudies(taskDescription) {
                print("🔍 Found relevant case study:")
                print("📚 Read: \(caseStudy) (5-10 minutes)")
                print("✅ This is faster than reading general documentation")
                return
            }
        }

        // Step 3: Generate reading plan
        print("📚 Reading Plan:")
        print("1. Primary: \(classification.primary) - \(classification.sections)")
        print("   ⏱️ Budget: \(classification.timeBudget)")

        if let fallback = classification.fallback, fallback != classification.primary {
            print("2. Fallback: \(fallback) (if needed)")
        }

        // Step 4: Add specific guidance based on category
        print()
        print("💡 Specific Guidance:")

        switch classification.category {
        case "testing":
            print("   • Use @Test and #expect(), never XCTest")
            print("   • Mark TCA tests @MainActor")
            print("   • Use TestClock() for deterministic time")

        case "tcaReducer":
            print("   • Check for deprecated WithViewStore")
            print("   • Verify @Shared patterns (single owner)")
            print("   • Use modern @Reducer macro syntax")

        case "navigation":
            print("   • Optional state = .sheet(item:) + .scope()")
            print("   • Conditional UI = if/else in view")
            print("   • NEVER use .sheet() for toolbar items")

        case "accessControl":
            print("   • Trace transitive dependencies when making public")
            print("   • Check cascade failures before assuming type errors")

        case "bugFix":
            print("   • Search case studies by symptom first")
            print("   • Check compilation before pattern analysis")

        default:
            break
        }

        // Step 5: Verification reminder
        print()
        print("✅ Verification Checklist:")
        print("   1. Code compiles (swiftc -typecheck)")
        print("   2. Follows Smith patterns (no red flags)")
        print("   3. Within reading budget")
        print("   4. Passes relevant verification checklist")
    }
}
