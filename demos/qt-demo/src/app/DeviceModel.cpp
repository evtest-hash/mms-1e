#include "DeviceModel.h"

DeviceModel::DeviceModel(QObject *parent) : QAbstractListModel(parent) {}

int DeviceModel::rowCount(const QModelIndex &) const { return m_devices.size(); }

QVariant DeviceModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_devices.size())
        return QVariant();

    const DeviceInfo &d = m_devices.at(index.row());
    switch (role) {
    case DisplayNameRole:
        return d.displayName();
    case IdentifierRole:
        return d.identifier;
    }
    return QVariant();
}

QHash<int, QByteArray> DeviceModel::roleNames() const
{
    return {{DisplayNameRole, "display"}, {IdentifierRole, "identifier"}};
}

QString DeviceModel::identifierAt(int row) const
{
    return (row >= 0 && row < m_devices.size()) ? m_devices.at(row).identifier : QString();
}

void DeviceModel::setSimulatedDevice(const QString &path, const QString &sizeHuman)
{
    DeviceInfo d;
    d.identifier = path;
    d.mediaName = QStringLiteral("模拟 SD 卡 (Simulated)");
    d.sizeHuman = sizeHuman;
    d.removable = true;
    d.sizeBytes = sizeHuman.left(3).toULongLong() * 1024 * 1024;

    beginResetModel();
    m_devices = {d};
    endResetModel();
}
