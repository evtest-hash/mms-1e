#include "PlatformQuirks.h"

#include <QByteArray>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QStringList>

namespace {
constexpr quint64 kMaxSizeBytes = 256ull * 1024 * 1024 * 1024;  // 256 GB
}  // namespace

QList<DeviceInfo> PlatformQuirks::listRemovableDevices()
{
    // Linux: lsblk 输出 JSON，过滤出可移除/外接的物理盘，排除系统盘与大容量盘。
    // 容器里根盘挂载点含 "/" 会被过滤，因此通常返回空 -> DeviceModel 注入模拟设备。
    QList<DeviceInfo> result;

    QProcess proc;
    proc.start(QStringLiteral("lsblk"),
               {QStringLiteral("-J"), QStringLiteral("-b"),
                QStringLiteral("-o"), QStringLiteral("NAME,SIZE,TRAN,RM,TYPE,MOUNTPOINT")});
    if (!proc.waitForFinished(3000) || proc.exitCode() != 0)
        return result;

    const QJsonDocument doc = QJsonDocument::fromJson(proc.readAllStandardOutput());
    const QJsonObject root = doc.object();
    const QJsonArray blocks = root.value(QLatin1String("blockdevices")).toArray();

    for (const QJsonValue &v : blocks) {
        const QJsonObject o = v.toObject();
        const QString type = o.value(QLatin1String("type")).toString();
        if (type != QLatin1String("disk"))
            continue;

        DeviceInfo d;
        d.identifier = QStringLiteral("/dev/") + o.value(QLatin1String("name")).toString();
        d.sizeBytes = o.value(QLatin1String("size")).toString().toULongLong();
        d.removable = (o.value(QLatin1String("rm")).toString() == QLatin1String("1"));
        const QString mount = o.value(QLatin1String("mountpoint")).toString();

        // 系统盘：挂载点为 / 或 /boot
        d.isSystem = (mount == QLatin1String("/") || mount == QLatin1String("/boot"));

        if (d.isSystem)
            continue;
        if (d.sizeBytes > kMaxSizeBytes)
            continue;
        // 只保留可移除或带传输协议的外接盘
        const QString tran = o.value(QLatin1String("tran")).toString();
        if (!d.removable && tran.isEmpty())
            continue;

        d.mediaName = QStringLiteral("Disk") + o.value(QLatin1String("name")).toString();
        d.sizeHuman = QStringLiteral("%1 MB").arg(d.sizeBytes / (1024 * 1024));
        result.append(d);
    }
    return result;
}

QString PlatformQuirks::unmountDevice(const QString &devicePath)
{
    Q_UNUSED(devicePath);
    // demo 使用文件目标，无需卸载。真实设备按平台实现：
    //   macOS: diskutil unmountDisk <path>
    //   Linux: udisksctl unmount --block-device <path>
    //   Windows: FSCTL_LOCK_VOLUME（在 BlockDeviceIO 实现里做）
    return QString();
}

bool PlatformQuirks::isSystemDevice(const DeviceInfo &d)
{
    return d.isSystem;
}
