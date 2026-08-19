#pragma once

#include <QFuture>
#include <QObject>
#include <QString>
#include <atomic>

// 写盘流程的控制器（桥接 QML 与写入引擎）。
// 对应 Swift 版 ImagerViewModel + ImagingService 的职责。
class WriterController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString imagePath READ imagePath WRITE setImagePath NOTIFY imagePathChanged)
    Q_PROPERTY(QString bmapPath READ bmapPath WRITE setBmapPath NOTIFY bmapPathChanged)
    Q_PROPERTY(QString devicePath READ devicePath WRITE setDevicePath NOTIFY devicePathChanged)
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(QString logText READ logText NOTIFY logTextChanged)
    Q_PROPERTY(bool isWriting READ isWriting NOTIFY isWritingChanged)
    Q_PROPERTY(bool canStart READ canStart NOTIFY canStartChanged)

public:
    explicit WriterController(QObject *parent = nullptr);

    QString imagePath() const { return m_imagePath; }
    QString bmapPath() const { return m_bmapPath; }
    QString devicePath() const { return m_devicePath; }
    int progress() const { return m_progress.load(); }
    QString statusMessage() const { return m_status; }
    QString logText() const { return m_log; }
    bool isWriting() const { return m_writing.load(); }
    bool canStart() const;

    void setImagePath(const QString &p);
    void setBmapPath(const QString &p);
    void setDevicePath(const QString &p);

    Q_INVOKABLE void startWrite();
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void demoSetup(const QString &dir);  // 仅供 --demo 模式：预填测试镜像/目标

signals:
    void imagePathChanged();
    void bmapPathChanged();
    void devicePathChanged();
    void progressChanged();
    void statusMessageChanged();
    void logTextChanged();
    void isWritingChanged();
    void canStartChanged();
    void writingFinished(bool ok, const QString &message);

private:
    QFuture<void> m_future;   // 持有后台写盘任务的 future（避免 nodiscard，并保持任务存活）
    QString m_imagePath;
    QString m_bmapPath;
    QString m_devicePath;
    QString m_status = QStringLiteral("就绪");
    QString m_log;
    std::atomic_int m_progress{0};
    std::atomic_bool m_writing{false};
    std::atomic_bool m_cancel{false};
};
