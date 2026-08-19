#pragma once

#include "BlockDeviceIO.h"

#include <QFile>

// BlockDeviceIO 的文件实现：demo 里用它把镜像写入普通文件，模拟"写 SD 卡"。
// 真实设备接入时新增 BlockDeviceRawPosix / BlockDeviceRawWin 即可，ImageWriter 不变。
class BlockDeviceFile : public BlockDeviceIO {
public:
    bool open(const QString &devicePath) override;
    qint64 write(const void *buf, qint64 count, qint64 offset) override;
    bool flush() override;
    void close() override;
    bool truncate(qint64 size) override;
    QString lastError() const override;

private:
    QFile m_file;
    QString m_error;
};
