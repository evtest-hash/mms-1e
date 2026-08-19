#pragma once

#include <QString>
#include <cstdint>

// 一个候选写入设备（跨平台枚举结果）
struct DeviceInfo {
    QString identifier;    // /dev/sdX 或目标文件路径
    QString mediaName;     // 厂商/介质名
    QString sizeHuman;     // "16 MB"
    quint64 sizeBytes = 0;
    bool removable = false;
    bool isSystem = false; // 系统盘（必须排除）

    QString displayName() const
    {
        QString s = identifier;
        if (!mediaName.isEmpty())
            s += QStringLiteral(" — ") + mediaName;
        if (!sizeHuman.isEmpty())
            s += QStringLiteral(" (%1)").arg(sizeHuman);
        return s;
    }
};
