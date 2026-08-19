#include "app/DeviceModel.h"
#include "app/WriterController.h"
#include "platform/PlatformQuirks.h"

#include <QDebug>
#include <QGuiApplication>
#include <cstdio>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTimer>
#include <QUrl>

static QQuickWindow *windowOf(QQmlApplicationEngine &engine)
{
    if (engine.rootObjects().isEmpty()) return nullptr;
    return qobject_cast<QQuickWindow *>(engine.rootObjects().first());
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("MMS1e"));
    QCoreApplication::setApplicationName(QStringLiteral("MMS-1e SD Card Imager (Qt Demo)"));

    const QStringList args = app.arguments();
    const int demoIdx = args.indexOf(QStringLiteral("--demo"));
    const QString demoDir = (demoIdx >= 0 && demoIdx + 1 < args.size())
                                ? args.at(demoIdx + 1)
                                : QString();

    WriterController controller;
    DeviceModel deviceModel;

    // 候选设备：demo 使用"模拟 SD 卡"（写普通文件）；真实设备接入后替换这里。
    // 说明：PlatformQuirks::listRemovableDevices() 已按 rpi-imager 模式预留，
    // 真实环境（如 Linux 桌面的 USB 读卡器）会返回可移除设备列表。
    const QString simDevice = demoDir.isEmpty() ? QStringLiteral("/tmp/mms1e_sim_device.img")
                                                : demoDir + QStringLiteral("/sim_device.img");
    deviceModel.setSimulatedDevice(simDevice, QStringLiteral("128 MB"));

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("writer"), &controller);
    engine.rootContext()->setContextProperty(QStringLiteral("deviceModel"), &deviceModel);
    engine.load(QUrl(QStringLiteral("qrc:/qml/Main.qml")));

    if (engine.rootObjects().isEmpty()) {
        qWarning("QML 加载失败");
        return -1;
    }

    // --demo <dir>：自动加载测试镜像 -> 写盘 -> 按阶段截图 -> 退出
    if (!demoDir.isEmpty()) {
        bool writingShotTaken = false;

        QTimer::singleShot(900, [&] {
            controller.demoSetup(demoDir);
            if (auto *win = windowOf(engine))
                win->grabWindow().save(demoDir + QStringLiteral("/shot-1-initial.png"));
            controller.startWrite();
        });

        QObject::connect(&controller, &WriterController::progressChanged, [&] {
            const int p = controller.progress();
            if (!writingShotTaken && p > 0 && p < 100) {
                writingShotTaken = true;
                if (auto *win = windowOf(engine))
                    win->grabWindow().save(demoDir + QStringLiteral("/shot-2-writing.png"));
            }
        });

        QObject::connect(&controller, &WriterController::writingFinished, [&](bool, const QString &) {
            fprintf(stderr, "MAIN: writingFinished received\n");
            QTimer::singleShot(300, [&] {
                fprintf(stderr, "MAIN: timer fired, grabbing shot-3\n");
                if (auto *win = windowOf(engine))
                    win->grabWindow().save(demoDir + QStringLiteral("/shot-3-done.png"));
                fprintf(stderr, "MAIN: quit\n");
                app.quit();
            });
        });
    }

    return app.exec();
}
