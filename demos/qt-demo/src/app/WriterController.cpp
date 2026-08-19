#include "WriterController.h"

#include "../core/BlockDeviceFile.h"
#include "../core/ImageWriter.h"

#include <QtConcurrent>
#include <cstdio>

WriterController::WriterController(QObject *parent) : QObject(parent) {}

bool WriterController::canStart() const
{
    return !m_writing.load() && !m_imagePath.isEmpty() && !m_bmapPath.isEmpty()
           && !m_devicePath.isEmpty();
}

void WriterController::setImagePath(const QString &p)
{
    if (m_imagePath == p) return;
    m_imagePath = p;
    emit imagePathChanged();
    emit canStartChanged();
}

void WriterController::setBmapPath(const QString &p)
{
    if (m_bmapPath == p) return;
    m_bmapPath = p;
    emit bmapPathChanged();
    emit canStartChanged();
}

void WriterController::setDevicePath(const QString &p)
{
    if (m_devicePath == p) return;
    m_devicePath = p;
    emit devicePathChanged();
    emit canStartChanged();
}

void WriterController::demoSetup(const QString &dir)
{
    setImagePath(dir + QStringLiteral("/test.img"));
    setBmapPath(dir + QStringLiteral("/test.bmap"));
    setDevicePath(dir + QStringLiteral("/sim_device.img"));
}

void WriterController::startWrite()
{
    if (m_writing.load()) return;
    if (m_imagePath.isEmpty() || m_bmapPath.isEmpty() || m_devicePath.isEmpty()) {
        m_status = QStringLiteral("请先选择镜像、bmap 与目标设备");
        emit statusMessageChanged();
        return;
    }

    m_writing.store(true);
    m_cancel.store(false);
    m_progress.store(0);
    m_log.clear();
    emit isWritingChanged();
    emit canStartChanged();
    emit progressChanged();
    emit logTextChanged();

    m_status = QStringLiteral("烧录中...");
    emit statusMessageChanged();

    const QString image = m_imagePath;
    const QString bmap = m_bmapPath;
    const QString dev = m_devicePath;

    m_future = QtConcurrent::run([this, image, bmap, dev] {
        ImageWriter writer;
        BlockDeviceFile io;

        // 发送方在后台线程、接收方在主线程 -> 自动排队，UI 更新都发生在主线程
        QObject::connect(&writer, &ImageWriter::progressChanged, this,
                         [this](int p) { m_progress.store(p); emit progressChanged(); });
        QObject::connect(&writer, &ImageWriter::logLine, this,
                         [this](const QString &l) { m_log += l + QLatin1Char('\n'); emit logTextChanged(); });

        ImageWriter::Options opts{image, bmap, dev, &m_cancel, /*demoDelayMs=*/25};
        const bool ok = writer.run(opts, &io);

        m_writing.store(false);
        emit isWritingChanged();
        emit canStartChanged();

        m_status = ok ? QStringLiteral("烧录完成") : QStringLiteral("烧录失败");
        emit statusMessageChanged();
        fprintf(stderr, "WC: emitting writingFinished ok=%d\n", ok ? 1 : 0);
        emit writingFinished(ok, ok ? QStringLiteral("烧录完成！") : QStringLiteral("烧录失败"));
    });
}

void WriterController::cancel()
{
    if (m_writing.load()) m_cancel.store(true);
}
