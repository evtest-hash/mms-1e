import Foundation

let args = CommandLine.arguments

guard args.count >= 4 else {
    fputs("Usage: mms-writer <image> <bmap> <device> [--progress-pipe <path>]\n", stderr)
    exit(1)
}

let imagePath  = args[1]
let bmapPath   = args[2]
let devicePath = args[3]

var progressPipe: String?
if let idx = args.firstIndex(of: "--progress-pipe"), idx + 1 < args.count {
    progressPipe = args[idx + 1]
}

do {
    try BmapCopier.copy(
        imagePath: imagePath,
        bmapPath: bmapPath,
        devicePath: devicePath,
        progressPipePath: progressPipe
    )
} catch {
    fputs("错误: \(error.localizedDescription)\n", stderr)
    exit(1)
}
