#pragma once

#include "DeviceInfo.h"

#include <QAbstractListModel>
#include <QHash>
#include <QList>

// 设备列表模型：给 QML 用。真实设备枚举 + 模拟设备兜底。
class DeviceModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles { DisplayNameRole = Qt::UserRole + 1, IdentifierRole };

    explicit DeviceModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE QString identifierAt(int row) const;

    // demo：用单个"模拟 SD 卡"条目替换列表（容器内没有真实可移除设备）
    void setSimulatedDevice(const QString &path, const QString &sizeHuman);

private:
    QList<DeviceInfo> m_devices;
};
