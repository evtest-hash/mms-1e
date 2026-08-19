#pragma once

#include <QString>
#include <QVector>
#include <cstdint>

// bmap 文件解析结果（与 Swift 版 BmapParser.swift 的 BmapRange / BmapFile 对应）
struct BmapRange {
    quint64 start = 0;   // 起始块号
    quint64 end = 0;     // 结束块号（含）
    QString checksum;    // Range 的 chksum 属性（可为空）
    quint64 blockCount() const { return end - start + 1; }
};

struct BmapFile {
    quint64 imageSize = 0;
    quint64 blockSize = 4096;
    quint64 blocksCount = 0;
    quint64 mappedBlocksCount = 0;
    QString checksumType = "sha256";
    QVector<BmapRange> ranges;  // 按 start 升序
};
