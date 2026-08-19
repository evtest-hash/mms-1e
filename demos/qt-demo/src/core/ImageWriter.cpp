#include "ImageWriter.h"

#include "BmapParser.h"

#include <QFile>
#include <QtGlobal>
#include <QThread>
#include <cstdio>

ImageWriter::ImageWriter(QObject *parent) : QObject(parent) {}

bool ImageWriter::run(const Options &opts, BlockDeviceIO *io)
{
    fprintf(stderr, "IW: start run\n");
    BmapFile bmap;
    BmapParser parser;
    QString parseError;
    if (!parser.parse(opts.bmapPath, &bmap, &parseError)) {
        emit logLine(QStringLiteral("✗ %1").arg(parseError));
        emit finished(false, parseError);
        return false;
    }
    fprintf(stderr, "IW: parsed ok, ranges=%lld\n", long long(bmap.ranges.size()));
    emit logLine(QStringLiteral("bmap 解析完成: %1 个区段, %2 个 mapped 块, 块大小 %3 字节")
                     .arg(bmap.ranges.size())
                     .arg(bmap.mappedBlocksCount)
                     .arg(bmap.blockSize));

    QFile source(opts.imagePath);
    if (!source.open(QIODevice::ReadOnly)) {
        const QString msg = QStringLiteral("无法打开镜像: %1").arg(source.errorString());
        emit finished(false, msg);
        return false;
    }

    if (!io->open(opts.devicePath)) {
        const QString msg = io->lastError();
        emit finished(false, msg);
        return false;
    }
    if (!io->truncate(qint64(bmap.imageSize))) {
        const QString msg = io->lastError();
        emit finished(false, msg);
        return false;
    }
    fprintf(stderr, "IW: device opened+truncated, entering range loop\n");

    const quint64 chunkSize = 1024 * 1024;  // 1 MB
    QByteArray buffer;
    buffer.resize(int(chunkSize));

    quint64 copiedBlocks = 0;
    const quint64 totalBlocks = qMax<quint64>(bmap.mappedBlocksCount, 1);

    for (const BmapRange &range : bmap.ranges) {
        const qint64 rangeOffset = qint64(range.start) * qint64(bmap.blockSize);
        const qint64 rangeLength = qint64(range.blockCount()) * qint64(bmap.blockSize);

        if (!source.seek(rangeOffset)) {
            emit finished(false, QStringLiteral("源镜像 seek 失败 @ %1").arg(rangeOffset));
            return false;
        }

        qint64 remaining = rangeLength;
        while (remaining > 0) {
            if (opts.cancelFlag && opts.cancelFlag->load()) {
                emit logLine(QStringLiteral("已取消（写入中断在偏移 %1）")
                                 .arg(rangeOffset + rangeLength - remaining));
                emit finished(false, QStringLiteral("已取消"));
                return false;
            }
            if (opts.demoDelayMs > 0)
                QThread::msleep(unsigned(opts.demoDelayMs));

            const qint64 toRead = qMin(remaining, qint64(chunkSize));
            const qint64 nRead = source.read(buffer.data(), toRead);
            if (nRead <= 0) {
                emit finished(false, QStringLiteral("源镜像读取失败 @ %1")
                                         .arg(rangeOffset + rangeLength - remaining));
                return false;
            }

            const qint64 written =
                io->write(buffer.constData(), nRead, rangeOffset + (rangeLength - remaining));
            if (written != nRead) {
                emit finished(false, QStringLiteral("目标写入失败: %1").arg(io->lastError()));
                return false;
            }
            remaining -= nRead;
        }

        copiedBlocks += range.blockCount();
        emit progressChanged(int(copiedBlocks * 100 / totalBlocks));
        fprintf(stderr, "IW: range done, copied=%lld\n", long long(copiedBlocks));
    }

    fprintf(stderr, "IW: all ranges done, flushing\n");
    io->flush();
    const quint64 writtenMiB = copiedBlocks * bmap.blockSize / (1024 * 1024);
    emit logLine(QStringLiteral("✓ 写入完成：共写入 %1 个块 (%2 MB)").arg(copiedBlocks).arg(writtenMiB));
    emit finished(true, QStringLiteral("烧录完成！"));
    return true;
}
