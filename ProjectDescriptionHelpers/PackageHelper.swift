import ProjectDescription
import Foundation

/// Package Helper for Rabitabank projects
/// Provides utilities for managing local/remote package dependencies
public enum RBPackageMode {
    case local
    case remote
    case auto
}

public extension Package {
    /// Create a Rabitabank package with mode control
    ///
    /// - Parameters:
    ///   - repoName: Repository name
    ///   - localRepoRoot: Relative local repository root from the current manifest
    ///   - mode: Package mode (.auto checks environment variable)
    /// - Returns: Package dependency
    static func rbPackage(
        _ repoName: String,
        localRepoRoot: String,
        mode: RBPackageMode = .auto
    ) -> Package {
        let prefersLocal: Bool = {
            switch mode {
            case .local:
                return true
            case .remote:
                return false
            case .auto:
                return Environment.USE_LOCAL_PACKAGES.getString(default: "0") == "1"
            }
        }()

        let localPath = "\(localRepoRoot)/\(repoName)"

        if prefersLocal {
            let localExists = FileManager.default.fileExists(atPath: localPath)

            if localExists {
                return .package(path: "\(localPath)")
            }

            if case .local = mode {
                cloneRabitaRepoIfNeeded(repoName: repoName, destinationPath: localPath)
                return .package(path: "\(localPath)")
            }
        }

        return .package(
            url: "https://github.com/RabitaBank/\(repoName).git",
            .branch("master")
        )
    }
}

private func cloneRabitaRepoIfNeeded(repoName: String, destinationPath: String) {
    let fileManager = FileManager.default

    if fileManager.fileExists(atPath: destinationPath) {
        return
    }

    let parentPath = (destinationPath as NSString).deletingLastPathComponent
    try? fileManager.createDirectory(
        atPath: parentPath,
        withIntermediateDirectories: true,
        attributes: nil
    )

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
        "git",
        "clone",
        "--branch",
        "master",
        "--single-branch",
        "https://github.com/RabitaBank/\(repoName).git",
        destinationPath,
    ]

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        fatalError("Failed to start git clone for \(repoName): \(error)")
    }

    guard process.terminationStatus == 0 else {
        let errorOutput = String(
            data: stderr.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? "Unknown git clone error"
        fatalError("git clone failed for \(repoName): \(errorOutput)")
    }
}
