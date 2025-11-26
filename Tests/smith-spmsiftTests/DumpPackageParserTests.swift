import Testing
@testable import spmsift

@Suite("Dump Package Parser Tests")
struct DumpPackageParserTests {
    let parser = DumpPackageParser()

    @Test("Parser correctly handles simple package structure")
    func parseSimplePackage() throws {
        let input = """
        {
            "name": "TestPackage",
            "platforms": {
                "iOS": "15.0",
                "macOS": "12.0"
            },
            "targets": [
                {
                    "name": "TestTarget",
                    "type": "executable",
                    "dependencies": []
                }
            ],
            "dependencies": [],
            "products": [
                {
                    "name": "test",
                    "type": "executable"
                }
            ]
        }
        """

        let result = try parser.parse(input)

        #expect(result.command == .dumpPackage)
        #expect(result.success)
        #expect(result.targets?.count == 1)
        #expect(result.targets?.executables.count == 1)
        #expect(result.dependencies?.count == 0)
        #expect(result.issues.count == 0)
    }

    @Test("Parser extracts dependency information correctly")
    func parsePackageWithDependencies() throws {
        let input = """
        {
            "name": "TestPackage",
            "targets": [
                {
                    "name": "TestTarget",
                    "type": "library",
                    "dependencies": ["TCA", "SwiftUI"]
                }
            ],
            "dependencies": [
                {
                    "name": "swift-composable-architecture",
                    "url": "https://github.com/pointfreeco/swift-composable-architecture",
                    "requirement": {
                        "range": [
                            "1.0.0",
                            "2.0.0"
                        ]
                    }
                }
            ]
        }
        """

        let result = try parser.parse(input)

        #expect(result.targets?.count == 1)
        #expect(result.dependencies?.count == 1)
        #expect(result.dependencies?.external.first?.name == "swift-composable-architecture")
        #expect(result.dependencies?.external.first?.version == "1.0.0, 2.0.0")
    }

    @Test("Parser identifies test targets correctly")
    func parsePackageWithTestTargets() throws {
        let input = """
        {
            "name": "TestPackage",
            "targets": [
                {
                    "name": "TestTarget",
                    "type": "executable"
                },
                {
                    "name": "TestTargetTests",
                    "type": "test"
                }
            ]
        }
        """

        let result = try parser.parse(input)

        #expect(result.targets?.count == 2)
        #expect(result.targets?.hasTestTargets == true)
    }

    @Test("Parser gracefully handles invalid JSON input")
    func parseInvalidJSON() throws {
        let input = "invalid json"

        let result = try parser.parse(input)

        #expect(result.command == .dumpPackage)
        #expect(!result.success)
        #expect(result.issues.count > 0)
        #expect(result.issues.first?.type == .syntaxError)
        #expect(result.issues.first?.severity == .error)
    }

    @Test("Parser provides appropriate warnings for minimal packages")
    func parseEmptyPackage() throws {
        let input = """
        {
            "name": "EmptyPackage"
        }
        """

        let result = try parser.parse(input)

        #expect(result.command == .dumpPackage)
        #expect(result.success) // Empty package is still valid
        #expect(result.targets?.count == 0)
        #expect(result.dependencies?.count == 0)
        // Should have a warning about no products
        #expect(result.issues.contains { $0.type == .missingTarget })
    }

    @Test("Target filtering returns single target with correct structure")
    func parsePackageWithTargetFilter() throws {
        let input = """
        {
            "name": "MultiTargetPackage",
            "platforms": {
                "iOS": "15.0"
            },
            "targets": [
                {
                    "name": "AppTarget",
                    "type": "executable",
                    "dependencies": ["SwiftUI", "Combine"]
                },
                {
                    "name": "LibraryTarget",
                    "type": "library",
                    "dependencies": ["Foundation"]
                },
                {
                    "name": "AppTargetTests",
                    "type": "test",
                    "dependencies": ["AppTarget", "XCTest"]
                }
            ],
            "dependencies": [
                {
                    "name": "SwiftUI",
                    "url": "https://github.com/apple/swiftui.git",
                    "requirement": {
                        "range": ["15.0.0"]
                    }
                },
                {
                    "name": "Combine",
                    "url": "https://github.com/apple/combine.git",
                    "requirement": {
                        "range": ["15.0.0"]
                    }
                },
                {
                    "name": "Foundation",
                    "url": "https://github.com/apple/foundation.git",
                    "requirement": {
                        "range": ["15.0.0"]
                    }
                }
            ]
        }
        """

        let result = try parser.parse(input, targetFilter: "AppTarget")

        #expect(result.command == .dumpPackage)
        #expect(result.success)
        #expect(result.targets?.count == 1)
        #expect(result.targets?.filteredTarget == "AppTarget")
        #expect(result.targets?.targets?.count == 1)
        #expect(result.targets?.targets?.first?.name == "AppTarget")
        #expect(result.targets?.targets?.first?.type == "executable")
        #expect(result.targets?.targets?.first?.dependencies.contains("SwiftUI") == true)
        #expect(result.targets?.targets?.first?.dependencies.contains("Combine") == true)
        #expect(result.targets?.executables.count == 1)
        #expect(result.targets?.executables.contains("AppTarget") == true)
        #expect(result.dependencies?.count == 2) // Only SwiftUI and Combine
        #expect(result.dependencies?.external.map { $0.name }.contains("SwiftUI") == true)
        #expect(result.dependencies?.external.map { $0.name }.contains("Combine") == true)
        #expect(result.dependencies?.external.map { $0.name }.contains("Foundation") == false)
    }

    @Test("Target filtering returns empty result for non-existent target")
    func parsePackageWithInvalidTargetFilter() throws {
        let input = """
        {
            "name": "TestPackage",
            "targets": [
                {
                    "name": "ExistingTarget",
                    "type": "executable",
                    "dependencies": []
                }
            ],
            "dependencies": [],
            "products": [
                {
                    "name": "existing",
                    "type": "executable"
                }
            ]
        }
        """

        let result = try parser.parse(input, targetFilter: "NonExistentTarget")

        #expect(result.command == .dumpPackage)
        #expect(result.success)
        #expect(result.targets?.count == 0)
        #expect(result.targets?.filteredTarget == "NonExistentTarget")
        #expect(result.targets?.targets?.count == 0)
        #expect(result.dependencies?.count == 0)
        #expect(result.issues.count == 0) // No issues for empty results
    }

    @Test("Target filtering filters issues correctly")
    func parsePackageWithTargetSpecificIssues() throws {
        let input = """
        {
            "name": "TestPackage",
            "targets": [
                {
                    "name": "TargetA",
                    "type": "executable",
                    "dependencies": []
                },
                {
                    "name": "TargetB",
                    "type": "executable",
                    "dependencies": []
                }
            ],
            "dependencies": []
        }
        """

        let result = try parser.parse(input, targetFilter: "TargetA")

        // Should only include issues related to TargetA or general issues
        let targetSpecificIssues = result.issues.filter { $0.target == "TargetB" }
        #expect(targetSpecificIssues.count == 0)
    }

    @Test("Target filtering with test target")
    func parsePackageWithTestTargetFilter() throws {
        let input = """
        {
            "name": "TestPackage",
            "targets": [
                {
                    "name": "MainTarget",
                    "type": "executable",
                    "dependencies": []
                },
                {
                    "name": "MainTargetTests",
                    "type": "test",
                    "dependencies": ["MainTarget", "XCTest"]
                }
            ],
            "dependencies": [
                {
                    "name": "XCTest",
                    "url": "https://github.com/apple/xctest.git",
                    "requirement": {
                        "range": ["15.0.0"]
                    }
                }
            ]
        }
        """

        let result = try parser.parse(input, targetFilter: "MainTargetTests")

        #expect(result.command == .dumpPackage)
        #expect(result.success)
        #expect(result.targets?.count == 1)
        #expect(result.targets?.filteredTarget == "MainTargetTests")
        #expect(result.targets?.hasTestTargets == true)
        #expect(result.targets?.targets?.first?.type == "test")
        #expect(result.targets?.targets?.first?.dependencies.contains("MainTarget") == true)
        #expect(result.targets?.targets?.first?.dependencies.contains("XCTest") == true)
        #expect(result.dependencies?.count == 1) // Only XCTest
        #expect(result.dependencies?.external.first?.name == "XCTest")
    }
}