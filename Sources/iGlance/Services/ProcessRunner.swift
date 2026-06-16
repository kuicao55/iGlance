import Foundation

class ProcessRunner {
    struct Result {
        let stdout: String
        let stderr: String
        let terminationStatus: Int32
    }

    @discardableResult
    func run(_ command: String, arguments: [String] = []) -> Result {
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

            process.waitUntilExit()
            group.wait()

            return Result(
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: String(data: stderrData, encoding: .utf8) ?? "",
                terminationStatus: process.terminationStatus
            )
        } catch {
            return Result(stdout: "", stderr: error.localizedDescription, terminationStatus: -1)
        }
    }

    func runShell(_ command: String) -> Result {
        return run("/bin/zsh", arguments: ["-c", command])
    }
}
