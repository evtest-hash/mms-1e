#pragma once

#include "BlockDeviceIO.h"
#include "BmapModel.h"

#include <QObject>
#include <QString>
#include <atomic>

// 写入引擎：解析 bmap -> 按区间从源镜像读取 -> 写入目标设备（只写 mapped 块）。
// 对应 Swift 版 BmapCopier.swift，但底层 I/O 走 BlockDeviceIO 抽象。
class ImageWriter : public QObject {
    Q_OBJECT
public:
    struct Options {
        QString imagePath;
        QString bmapPath;
        QString devicePath;
        std::atomic_bool *cancelFlag = nullptr;   // 可选：置 true 则中断
        int demoDelayMs = 0;                       // 仅 demo：每块模拟延迟，便于看到进度
    };

    explicit ImageWriter(QObject *parent = nullptr);

    // 同步执行；进度/日志经信号回传。返回是否成功。
    bool run(const Options &opts, BlockDeviceIO *io);

signals:
    void progressChanged(int pct);
    void logLine(const QString &line);
    void finished(bool ok, const QString &message);
};
