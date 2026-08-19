#pragma once

#include "../app/DeviceInfo.h"

#include <QList>
#include <QString>

// rpi-imager PlatformQuirks 职责划分（demo 版）。
// 把「每个 OS 做法不同」的系统动作集中在这一层，业务逻辑只调这里的静态方法。
// 目标：跨平台时新增一个平台 = 新增一个实现文件，而不是在业务代码里堆 #ifdef。
class PlatformQuirks {
public:
    // 枚举候选写入设备（可移除/外接，排除系统盘、大容量盘）。
    // Linux 实现：lsblk -J；macOS：diskutil；Windows：PowerShell/WMI。
    // demo 在容器内无外接设备，会返回空列表，由 DeviceModel 兜底注入"模拟设备"。
    static QList<DeviceInfo> listRemovableDevices();

    // 写盘前卸载/解锁目标设备。
    // 文件目标返回空字符串（无操作）；真实设备：macOS diskutil / Linux udisks / Win 锁卷。
    static QString unmountDevice(const QString &devicePath);

    // 是否系统盘（写入前必须过滤掉）
    static bool isSystemDevice(const DeviceInfo &d);
};
