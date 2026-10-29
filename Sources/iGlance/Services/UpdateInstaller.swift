import AppKit
import Foundation

enum UpdateInstaller {
    static func extractApp(from zip: URL) throws -> URL {
        let folder = zip.deletingLastPathComponent()
            .appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        try run("/usr/bin/ditto", ["-x", "-k", zip.path, folder.path])

        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw UpdateError.invalidBundle
        }

        for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
            if Bundle(url: url)?.bundleIdentifier == Bundle.main.bundleIdentifier {
                return url
            }
        }
        throw UpdateError.invalidBundle
    }

    static func validate(_ app: URL, expectedVersion: String) throws {
        guard let bundle = Bundle(url: app),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        else {
            throw UpdateError.invalidBundle
        }

        guard AppVersion.compare(version, expectedVersion) != .orderedAscending else {
            throw UpdateError.verification("The downloaded app reports version \(version), not \(expectedVersion).")
        }

        // Reject an unsigned or tampered bundle before it can replace the
        // running app. Ad-hoc and Developer ID signatures both verify.
        try run(
            "/usr/bin/codesign",
            ["--verify", "--deep", "--strict", app.path],
            failure: { message in
                UpdateError.verification(message.isEmpty ? "invalid code signature" : message)
            }
        )
    }

    /// Spawns a detached helper that waits for this process to exit, swaps the
    /// bundle, and relaunches it. The helper keeps a backup so a failed copy
    /// restores the previous app instead of leaving the user with nothing.
    @MainActor
    static func relaunchReplacingCurrentApp(with newApp: URL) async throws {
        let destination = Bundle.main.bundleURL
        guard destination.pathExtension.lowercased() == "app" else {
            throw UpdateError.notWritable
        }
        if destination.path.contains("/AppTranslocation/") {
            throw UpdateError.translocated
        }
        guard FileManager.default.isWritableFile(atPath: destination.deletingLastPathComponent().path) else {
            throw UpdateError.notWritable
        }

        let tempRoot = newApp
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scriptURL = tempRoot.appendingPathComponent("apply-update.sh")

        let script = """
        #!/bin/zsh
        DEST="$1"
        SRC="$2"
        PID="$3"
        TMP="$4"
        BACKUP="${DEST}.update-backup"

        while /bin/kill -0 "$PID" 2>/dev/null; do /bin/sleep 0.2; done

        /bin/rm -rf "$BACKUP"
        if ! /bin/mv "$DEST" "$BACKUP"; then
            exit 1
        fi

        if /usr/bin/ditto "$SRC" "$DEST"; then
            /usr/bin/xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
            /bin/rm -rf "$BACKUP"
        else
            /bin/rm -rf "$DEST"
            /bin/mv "$BACKUP" "$DEST"
        fi

        /usr/bin/open "$DEST"
        /bin/rm -rf "$TMP"
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptURL.path
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [
            scriptURL.path,
            destination.path,
            newApp.path,
            "\(ProcessInfo.processInfo.processIdentifier)",
            tempRoot.path
        ]
        try process.run()

        // Give the helper a moment to attach before this process disappears.
        try? await Task.sleep(for: .milliseconds(350))
        NSApplication.shared.terminate(nil)
    }

    private static func run(
        _ executable: String,
        _ arguments: [String],
        failure: (String) -> UpdateError = { _ in UpdateError.invalidBundle }
    ) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw failure(message)
        }
    }
}
