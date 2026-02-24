import Foundation
import CZlib

enum BmapError: LocalizedError {
    case cannotRead(String)
    case parseFailed
    case cannotOpenImage(String)
    case cannotOpenDevice(String)
    case seekFailed(Int64)
    case readFailed(Int64)
    case writeFailed(Int64)

    var errorDescription: String? {
        switch self {
        case .cannotRead(let p):      return "无法读取文件: \(p)"
        case .parseFailed:            return "Bmap 文件解析失败"
        case .cannotOpenImage(let p): return "无法打开镜像: \(p)"
        case .cannotOpenDevice(let p):return "无法打开设备: \(p)"
        case .seekFailed(let o):      return "定位失败，偏移: \(o)"
        case .readFailed(let o):      return "读取失败，偏移: \(o)"
        case .writeFailed(let o):     return "写入失败，偏移: \(o)"
        }
    }
}

enum BmapCopier {

    private static let chunkSize = 1024 * 1024   // 1 MB

    static func copy(imagePath: String, bmapPath: String,
                     devicePath: String, progressPipePath: String?) throws {
        let bmap = try BmapParser().parse(fileAt: bmapPath)
        let blockSize = Int(bmap.blockSize)

        // gzopen transparently handles both plain and gzip files
        guard let source = gzopen(imagePath, "rb") else {
            throw BmapError.cannotOpenImage(imagePath)
        }
        defer { gzclose(source) }

        // Prefer raw device on macOS for faster writes
        let writePath = devicePath.replacingOccurrences(of: "/dev/disk", with: "/dev/rdisk")
        let target = open(writePath, O_WRONLY)
        guard target >= 0 else {
            throw BmapError.cannotOpenDevice(writePath)
        }
        defer { fsync(target); close(target) }

        // Bypass buffer cache for bulk writes
        _ = fcntl(target, F_NOCACHE, 1)

        // Open progress pipe
        var pipeFd: Int32 = -1
        if let path = progressPipePath {
            pipeFd = Darwin.open(path, O_WRONLY)
        }
        defer { if pipeFd >= 0 { Darwin.close(pipeFd) } }

        var buffer = [UInt8](repeating: 0, count: chunkSize)
        var copiedBlocks: UInt64 = 0
        let totalBlocks = max(bmap.mappedBlocksCount, 1)

        log("开始写入: \(bmap.ranges.count) 个区段, \(totalBlocks) 个块 (块大小 \(blockSize))")

        for range in bmap.ranges {
            let rangeOffset = Int(range.start) * blockSize
            let rangeLength = Int(range.blockCount) * blockSize

            // Seek source (forward-only for gzip efficiency)
            if gzseek(source, rangeOffset, SEEK_SET) < 0 {
                throw BmapError.seekFailed(Int64(rangeOffset))
            }

            // Seek target
            lseek(target, off_t(rangeOffset), SEEK_SET)

            // Read and write in chunks
            var remaining = rangeLength
            while remaining > 0 {
                let toRead = min(remaining, chunkSize)
                let nRead = readFromSource(source, into: &buffer, count: toRead)
                guard nRead > 0 else {
                    throw BmapError.readFailed(Int64(rangeOffset) + Int64(rangeLength - remaining))
                }

                try writeAll(fd: target, buffer: &buffer, count: Int(nRead),
                             errorOffset: Int64(rangeOffset) + Int64(rangeLength - remaining))

                remaining -= Int(nRead)
            }

            copiedBlocks += range.blockCount
            let pct = Int(copiedBlocks * 100 / totalBlocks)
            reportProgress(pct, pipeFd: pipeFd)
        }

        log("写入完成: 共写入 \(copiedBlocks) 个块")
    }

    // MARK: - Helpers

    private static func readFromSource(_ gz: gzFile, into buffer: inout [UInt8], count: Int) -> Int32 {
        buffer.withUnsafeMutableBytes { ptr in
            gzread(gz, ptr.baseAddress, UInt32(count))
        }
    }

    private static func writeAll(fd: Int32, buffer: inout [UInt8], count: Int, errorOffset: Int64) throws {
        try buffer.withUnsafeBytes { ptr in
            var written = 0
            while written < count {
                let n = Darwin.write(fd, ptr.baseAddress!.advanced(by: written), count - written)
                guard n > 0 else {
                    throw BmapError.writeFailed(errorOffset + Int64(written))
                }
                written += n
            }
        }
    }

    private static func reportProgress(_ pct: Int, pipeFd: Int32) {
        if pipeFd >= 0 {
            let msg = "PROGRESS \(pct)\n"
            msg.withCString { cstr in
                _ = Darwin.write(pipeFd, cstr, Int(strlen(cstr)))
            }
        }
    }

    private static func log(_ message: String) {
        print(message)
        fflush(stdout)
    }
}
