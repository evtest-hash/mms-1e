import Foundation

final class ImagingService {

    var onProgress: ((Int) -> Void)?
    var onOutput: ((String) -> Void)?
    var onFinished: ((Bool, String) -> Void)?

    private var process: Process?
    private var stopProgressReading = false
    private let progressPipePath = "/tmp/mms1e_progress"

    func start(imagePath: String, bmapPath: String, devicePath: String, password: String) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            performImaging(
                imagePath: imagePath,
                bmapPath: bmapPath,
                devicePath: devicePath,
                password: password
            )
        }
    }

    func cancel() {
        process?.terminate()
        stopProgressReading = true
    }

    // MARK: - Writer lookup

    static func findWriter() -> String? {
        // Look next to the main executable (works in .app bundle and .build/)
        let myURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
            .resolvingSymlinksInPath()
        let sibling = myURL.deletingLastPathComponent()
            .appendingPathComponent("mms-writer").path
        if FileManager.default.isExecutableFile(atPath: sibling) {
            return sibling
        }

        // Fallback: search in .build/debug and .build/release
        let cwd = FileManager.default.currentDirectoryPath
        for config in ["debug", "release"] {
            let p = "\(cwd)/.build/\(config)/mms-writer"
            if FileManager.default.isExecutableFile(atPath: p) {
                return p
            }
        }

        return nil
    }

    // MARK: - Private

    private func performImaging(imagePath: String, bmapPath: String,
                                devicePath: String, password: String) {
        // Unmount disk (no root needed on macOS)
        let unmount = DeviceManager.unmountDisk(devicePath)
        if !unmount.success {
            onFinished?(false, "卸载磁盘失败: \(unmount.message)")
            return
        }
        onOutput?("磁盘已卸载")

        guard let writerPath = Self.findWriter() else {
            onFinished?(false, "找不到 mms-writer 工具，请确保已构建项目")
            return
        }
        onOutput?("使用 mms-writer: \(writerPath)")

        // Prepare progress pipe
        let fm = FileManager.default
        if fm.fileExists(atPath: progressPipePath) {
            try? fm.removeItem(atPath: progressPipePath)
        }
        mkfifo(progressPipePath, 0o644)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        proc.arguments = [
            "-S", writerPath,
            imagePath, bmapPath, devicePath,
            "--progress-pipe", progressPipePath
        ]

        let stdinPipe  = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardInput  = stdinPipe
        proc.standardOutput = stdoutPipe
        proc.standardError  = stderrPipe
        self.process = proc

        do {
            try proc.run()
        } catch {
            cleanup()
            onFinished?(false, "启动写入工具失败: \(error.localizedDescription)")
            return
        }

        // Send sudo password
        if let data = (password + "\n").data(using: .utf8) {
            stdinPipe.fileHandleForWriting.write(data)
            try? stdinPipe.fileHandleForWriting.close()
        }

        // Read stdout
        let stdoutThread = Thread { [weak self] in
            self?.readHandle(stdoutPipe.fileHandleForReading)
        }
        stdoutThread.qualityOfService = .userInitiated
        stdoutThread.start()

        // Read stderr
        let stderrThread = Thread { [weak self] in
            self?.readHandle(stderrPipe.fileHandleForReading)
        }
        stderrThread.qualityOfService = .userInitiated
        stderrThread.start()

        // Read progress
        let progressThread = Thread { [weak self] in
            self?.readProgressPipe()
        }
        progressThread.qualityOfService = .userInitiated
        progressThread.start()

        proc.waitUntilExit()
        stopProgressReading = true

        Thread.sleep(forTimeInterval: 0.5)
        cleanup()

        let code = proc.terminationStatus
        if code == 0 {
            onProgress?(100)
            onFinished?(true, "烧录完成！")
        } else {
            onFinished?(false, "烧录失败，退出码: \(code)")
        }
    }

    private func readHandle(_ handle: FileHandle) {
        while true {
            let data = handle.availableData
            if data.isEmpty { break }
            guard let text = String(data: data, encoding: .utf8) else { continue }
            for line in text.components(separatedBy: "\n") where !line.isEmpty {
                onOutput?(line)
            }
        }
    }

    private func readProgressPipe() {
        let fd = open(progressPipePath, O_RDONLY | O_NONBLOCK)
        guard fd >= 0 else { return }
        defer { close(fd) }

        var buffer = ""
        while !stopProgressReading {
            var readBuf = [UInt8](repeating: 0, count: 1024)
            let n = read(fd, &readBuf, readBuf.count)
            if n > 0 {
                guard let chunk = String(bytes: readBuf[0..<n], encoding: .utf8) else { continue }
                buffer += chunk
                let lines = buffer.components(separatedBy: "\n")
                for line in lines.dropLast() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("PROGRESS ") {
                        let parts = trimmed.components(separatedBy: " ")
                        if parts.count >= 2, let pct = Int(parts[1]) {
                            onProgress?(pct)
                        }
                    }
                }
                buffer = lines.last ?? ""
            } else {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }

    private func cleanup() {
        let fm = FileManager.default
        if fm.fileExists(atPath: progressPipePath) {
            try? fm.removeItem(atPath: progressPipePath)
        }
    }
}
