import Foundation

public struct DescribeParser {
    public init() {}

    public func parse(_ input: String, targetFilter: String? = nil) throws -> PackageAnalysis {
        // Note: describe command doesn't provide target-specific information
        // If targetFilter is specified, we return empty results but note this limitation
        if targetFilter != nil {
            return PackageAnalysis(
                command: .describe,
                success: true,
                targets: TargetAnalysis(
                    count: 0,
                    filteredTarget: targetFilter,
                    targets: []
                ),
                dependencies: DependencyAnalysis(count: 0, external: [], local: [], circularImports: false),
                issues: [PackageIssue(
                    type: .unknown,
                    severity: .info,
                    target: targetFilter,
                    message: "describe command doesn't support target-specific analysis. Use dump-package for target filtering."
                )]
            )
        }

        let lines = input.components(separatedBy: .newlines)
        var issues: [PackageIssue] = []
        var packageName: String?
        var packageVersion: String?
        var platforms: [String] = []

        // Parse package description output
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.lowercased().hasPrefix("package name:") {
                packageName = trimmed.replacingOccurrences(of: "Package Name:", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
            }

            if trimmed.lowercased().hasPrefix("package version:") {
                packageVersion = trimmed.replacingOccurrences(of: "Package Version:", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
            }

            if trimmed.lowercased().contains("platform:") || trimmed.lowercased().contains("platforms:") {
                platforms.append(trimmed)
            }

            // Check for errors in description
            if trimmed.lowercased().contains("error") {
                issues.append(PackageIssue(
                    type: .syntaxError,
                    severity: .error,
                    message: trimmed
                ))
            }
        }

        return PackageAnalysis(
            command: .describe,
            success: packageName != nil,
            issues: issues,
            metrics: PackageMetrics()
        )
    }
}