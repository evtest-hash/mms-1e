#include "BlockDeviceFile.h"

bool BlockDeviceFile::open(const QString &devicePath)
{
    m_file.setFileName(devicePath);
    if (!m_file.open(QIODevice::ReadWrite)) {
        m_error = QStringLiteral("无法打开目标设备: %1 (%2)").arg(devicePath, m_file.errorString());
        return false;
    }
    return true;
}

qint64 BlockDeviceFile::write(const void *buf, qint64 count, qint64 offset)
{
    if (!m_file.seek(offset)) {
        m_error = QStringLiteral("seek 失败 @ %1").arg(offset);
        return -1;
    }
    const qint64 n = m_file.write(static_cast<const char *>(buf), count);
    if (n < 0)
        m_error = QStringLiteral("write 失败 @ %1").arg(offset);
    return n;
}

bool BlockDeviceFile::flush() { return m_file.flush(); }

void BlockDeviceFile::close() { m_file.close(); }

bool BlockDeviceFile::truncate(qint64 size)
{
    if (!m_file.resize(size)) {
        m_error = QStringLiteral("初始化目标大小失败: %1").arg(m_file.errorString());
        return false;
    }
    return true;
}

QString BlockDeviceFile::lastError() const { return m_error; }
