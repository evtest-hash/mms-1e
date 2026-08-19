#pragma once

#include <QString>
#include <cstdint>

// rpi-imager FileOperations 风格的块设备 I/O 抽象。
// 同一套写入逻辑（ImageWriter）跑在三套平台 API 上，差异被关进各平台实现里：
//   - macOS : /dev/rdiskX  + F_NOCACHE
//   - Linux : /dev/sdX     + (O_DIRECT 可选)
//   - Windows: \\.\PhysicalDriveN + 扇区对齐 + 写前锁卷
// Demo 版实现：BlockDeviceFile —— 把普通文件当作"模拟 SD 卡"，
// 好处是 bmap 引擎逻辑可以不依赖真实硬件直接运行/单测。
class BlockDeviceIO {
public:
    virtual ~BlockDeviceIO() = default;

    virtual bool open(const QString &devicePath) = 0;
    // 在指定偏移写入 count 字节；返回实际写入字节数，失败返回 -1
    virtual qint64 write(const void *buf, qint64 count, qint64 offset) = 0;
    virtual bool flush() = 0;                 // fsync / FlushFileBuffers
    virtual void close() = 0;
    virtual bool truncate(qint64 size) = 0;   // 初始化目标盘大小
    virtual QString lastError() const = 0;
};
