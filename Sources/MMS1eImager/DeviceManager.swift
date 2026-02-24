import Foundation

struct DiskDevice: Identifiable {
    let identifier: String
    let name: String
    let size: String
    let sizeBytes: UInt64
    let mediaName: String
    let protocolType: String
    let removable: Bool

    var id: String { identifier }

    var displayName: String {
        var parts = [identifier]
        if !mediaName.isEmpty { parts.append(mediaName) }
        if !size.isEmpty { parts.append("(\(size))") }
        return parts.joined(separator: " — ")
    }

    var shortDescription: String {
        [protocolType, size].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

enum DeviceManager {

    // SD cards for embedded devices are typically 4–128 GB.
    // Reject anything above 256 GB to guard against accidental selection
    // of external backup drives or large storage.
    static let maxSizeBytes: UInt64 = 256 * 1024 * 1024 * 1024

    static func listRemovableDevices() -> [DiskDevice] {
        guard let listOutput = run("/usr/sbin/diskutil", arguments: ["list"]) else {
            return []
        }

        var physicalDisks: [String] = []
        for line in listOutput.components(separatedBy: "\n") {
            guard line.hasPrefix("/dev/disk"), line.contains("physical") else { continue }
            if let path = line.components(separatedBy: " ").first, !path.isEmpty {
                physicalDisks.append(path)
            }
        }

        var devices: [DiskDevice] = []
        for path in physicalDisks {
            // Always exclude disk0 — it is the boot drive on every Mac
            if path == "/dev/disk0" { continue }

            guard let info = detailedInfo(for: path) else { continue }

            // Exclude virtual disks
            if info.virtual { continue }

            // Must be removable media OR externally connected
            if !info.removable && !info.external { continue }

            // Exclude disks with Apple system partitions (APFS / HFS+)
            if hasSystemPartitions(path, listOutput: listOutput) { continue }

            // Exclude Apple-branded internal SSDs that somehow appear removable
            let nameLower = info.mediaName.lowercased()
            if nameLower.contains("apple") { continue }

            // Exclude oversized disks to prevent accidental data loss
            if info.sizeBytes > maxSizeBytes { continue }

            devices.append(DiskDevice(
                identifier: path,
                name: path.replacingOccurrences(of: "/dev/", with: ""),
                size: info.size,
                sizeBytes: info.sizeBytes,
                mediaName: info.mediaName,
                protocolType: info.protocolType,
                removable: info.removable
            ))
        }

        return devices
    }

    static func unmountDisk(_ identifier: String) -> (success: Bool, message: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["unmountDisk", identifier]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (false, error.localizedDescription)
        }

        if process.terminationStatus == 0 {
            return (true, "")
        }

        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
        return (false, errMsg)
    }

    // MARK: - Private

    private struct DiskInfo {
        var size: String = ""
        var sizeBytes: UInt64 = 0
        var mediaName: String = ""
        var protocolType: String = ""
        var removable: Bool = false
        var external: Bool = false
        var virtual: Bool = false
    }

    private static func detailedInfo(for identifier: String) -> DiskInfo? {
        guard let output = run("/usr/sbin/diskutil", arguments: ["info", identifier]) else {
            return nil
        }

        var info = DiskInfo()

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let value = extractValue(trimmed, key: "Disk Size:") {
                info.size = value
                // Extract byte count from "(NNN Bytes)"
                if let open = value.firstIndex(of: "(") {
                    let after = value[value.index(after: open)...]
                    if let space = after.firstIndex(of: " ") {
                        info.sizeBytes = UInt64(after[..<space]) ?? 0
                    }
                }
                if let idx = info.size.firstIndex(of: "(") {
                    info.size = String(info.size[..<idx]).trimmingCharacters(in: .whitespaces)
                }
            } else if let value = extractValue(trimmed, key: "Device / Media Name:") {
                info.mediaName = value
            } else if let value = extractValue(trimmed, key: "Protocol:") {
                info.protocolType = value
            } else if let value = extractValue(trimmed, key: "Removable Media:") {
                info.removable = value.lowercased().contains("removable")
            } else if let value = extractValue(trimmed, key: "Device Location:") {
                info.external = value.lowercased().contains("external")
            } else if let value = extractValue(trimmed, key: "Virtual:") {
                info.virtual = value.lowercased() == "yes"
            }
        }

        return info
    }

    /// Check whether the disk's partition table in `diskutil list` output
    /// contains Apple system partition types.
    private static func hasSystemPartitions(_ identifier: String, listOutput: String) -> Bool {
        let systemTypes = [
            "Apple_APFS_ISC",
            "Apple_APFS_Recovery",
            "Apple_APFS",
            "Apple_HFS",
            "Apple_Boot",
            "Apple_CoreStorage",
            "APFS Container Scheme",
        ]

        // Extract the section for this disk from the full `diskutil list` output
        let lines = listOutput.components(separatedBy: "\n")
        var inSection = false
        for line in lines {
            if line.hasPrefix("/dev/") {
                inSection = line.hasPrefix(identifier + " ")
                continue
            }
            if inSection {
                for sysType in systemTypes {
                    if line.contains(sysType) { return true }
                }
            }
        }
        return false
    }

    private static func extractValue(_ line: String, key: String) -> String? {
        guard line.hasPrefix(key) else { return nil }
        return String(line.dropFirst(key.count)).trimmingCharacters(in: .whitespaces)
    }

    private static func run(_ path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
