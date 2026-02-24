import Foundation

struct BmapRange {
    let start: UInt64
    let end: UInt64
    let checksum: String?

    var blockCount: UInt64 { end - start + 1 }
}

struct BmapFile {
    let imageSize: UInt64
    let blockSize: UInt64
    let blocksCount: UInt64
    let mappedBlocksCount: UInt64
    let checksumType: String
    let ranges: [BmapRange]
}

final class BmapParser: NSObject, XMLParserDelegate {
    private var imageSize: UInt64 = 0
    private var blockSize: UInt64 = 4096
    private var blocksCount: UInt64 = 0
    private var mappedBlocksCount: UInt64 = 0
    private var checksumType = "sha256"
    private var ranges: [BmapRange] = []

    private var currentElement = ""
    private var currentText = ""
    private var currentChecksum: String?
    private var inBlockMap = false
    private var parseError: Error?

    func parse(fileAt path: String) throws -> BmapFile {
        let url = URL(fileURLWithPath: path)
        guard let parser = XMLParser(contentsOf: url) else {
            throw BmapError.cannotRead(path)
        }
        parser.delegate = self
        guard parser.parse() else {
            throw parseError ?? parser.parserError ?? BmapError.parseFailed
        }

        let sorted = ranges.sorted { $0.start < $1.start }
        return BmapFile(
            imageSize: imageSize,
            blockSize: blockSize,
            blocksCount: blocksCount,
            mappedBlocksCount: mappedBlocksCount,
            checksumType: checksumType,
            ranges: sorted
        )
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement name: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        currentElement = name
        currentText = ""
        if name == "BlockMap" {
            inBlockMap = true
        } else if name == "Range" {
            currentChecksum = attributes["chksum"]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement name: String,
                namespaceURI: String?, qualifiedName: String?) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "ImageSize":
            imageSize = UInt64(text) ?? 0
        case "BlockSize":
            blockSize = UInt64(text) ?? 4096
        case "BlocksCount":
            blocksCount = UInt64(text) ?? 0
        case "MappedBlocksCount":
            mappedBlocksCount = UInt64(text) ?? 0
        case "ChecksumType":
            checksumType = text
        case "Range" where inBlockMap:
            let parts = text.split(separator: "-").compactMap { UInt64($0) }
            guard let start = parts.first else { break }
            let end = parts.count > 1 ? parts[1] : start
            ranges.append(BmapRange(start: start, end: end, checksum: currentChecksum))
        case "BlockMap":
            inBlockMap = false
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred error: Error) {
        parseError = error
    }
}
