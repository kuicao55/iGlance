import Foundation
import Darwin

class ProcessRunner {
    private let detachedLock = NSLock()
    private var detachedProcesses: [UUID: Process] = [:]

    struct Result {
        let stdout: String
        let stderr: String
        let terminationStatus: Int32
        let timedOut: Bool

        init(stdout: String, stderr: String, terminationStatus: Int32, timedOut: Bool = false) {
            self.stdout = stdout
            self.stderr = stderr
            self.terminationStatus = terminationStatus
            self.timedOut = timedOut
        }
    }

    @discardableResult
    func run(_ command: String, arguments: [String] = [], timeout: TimeInterval? = nil) -> Result {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            let group = DispatchGroup()
            var stdoutData = Data()
            var stderrData = Data()

            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            let timedOut = wait(for: process, timeout: timeout)
            group.wait()

            return Result(
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: String(data: stderrData, encoding: .utf8) ?? "",
                terminationStatus: process.terminationStatus,
                timedOut: timedOut
            )
        } catch {
            return Result(stdout: "", stderr: error.localizedDescription, terminationStatus: -1)
        }
    }

    func runShell(_ command: String, timeout: TimeInterval? = nil) -> Result {
        return run("/bin/zsh", arguments: ["-c", command], timeout: timeout)
    }

    /// Starts a user-approved command without waiting for it to finish.
    ///
    /// Used for `process` / `command` start commands: a daemon commonly stays
    /// in the foreground, and killing it after a timeout would be wrong. The
    /// command gets a short grace period so an immediate failure is still
    /// reported; after that it is left running and retained until it exits.
    @discardableResult
    func launchDetachedShell(_ command: String, grace: TimeInterval = 1.0) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return Result(stdout: "", stderr: error.localizedDescription, terminationStatus: -1)
        }

        let deadline = Date().addingTimeInterval(max(0.1, grace))
        while process.isRunning && Date() < deadline {
            usleep(50_000)
        }

        guard process.isRunning else {
            return Result(stdout: "", stderr: "", terminationStatus: process.terminationStatus)
        }

        let token = UUID()
        process.terminationHandler = { [weak self] _ in
            guard let self else { return }
            self.detachedLock.lock()
            self.detachedProcesses.removeValue(forKey: token)
            self.detachedLock.unlock()
        }

        detachedLock.lock()
        detachedProcesses[token] = process
        let alreadyExited = !process.isRunning
        if alreadyExited {
            detachedProcesses.removeValue(forKey: token)
        }
        detachedLock.unlock()

        return Result(stdout: "", stderr: "", terminationStatus: alreadyExited ? process.terminationStatus : 0)
    }

    /// Waits for the process, terminating it when a timeout is set. Returns
    /// true when the process had to be killed.
    private func wait(for process: Process, timeout: TimeInterval?) -> Bool {
        guard let timeout else {
            process.waitUntilExit()
            return false
        }

        let deadline = Date().addingTimeInterval(max(0.1, timeout))
        while process.isRunning && Date() < deadline {
            usleep(50_000)
        }

        guard process.isRunning else {
            process.waitUntilExit()
            return false
        }

        process.terminate()
        let grace = Date().addingTimeInterval(1)
        while process.isRunning && Date() < grace {
            usleep(50_000)
        }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
        process.waitUntilExit()
        return true
    }
}
