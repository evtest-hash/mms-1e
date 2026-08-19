#include "BmapParser.h"

#include <QFile>
#include <QXmlStreamReader>
#include <algorithm>

bool BmapParser::parse(const QString &filePath, BmapFile *out, QString *error)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        if (error) *error = QStringLiteral("无法打开 bmap 文件: %1").arg(file.errorString());
        return false;
    }

    QXmlStreamReader xml(&file);
    BmapFile bmap;
    QVector<BmapRange> ranges;
    bool inBlockMap = false;
    QString curText;
    QString curChksum;

    while (!xml.atEnd() && !xml.hasError()) {
        xml.readNext();

        if (xml.isStartElement()) {
            curText.clear();
            const QStringView name = xml.name();
            if (name == QLatin1String("BlockMap")) {
                inBlockMap = true;
            } else if (inBlockMap && name == QLatin1String("Range")) {
                curChksum = xml.attributes().value(QLatin1String("chksum")).toString();
            }
        } else if (xml.isCharacters()) {
            curText += xml.text().toString();
        } else if (xml.isEndElement()) {
            const QStringView name = xml.name();
            const QString text = curText.trimmed();

            if (name == QLatin1String("ImageSize")) {
                bmap.imageSize = text.toULongLong();
            } else if (name == QLatin1String("BlockSize")) {
                bmap.blockSize = text.toULongLong();
            } else if (name == QLatin1String("BlocksCount")) {
                bmap.blocksCount = text.toULongLong();
            } else if (name == QLatin1String("MappedBlocksCount")) {
                bmap.mappedBlocksCount = text.toULongLong();
            } else if (name == QLatin1String("ChecksumType")) {
                bmap.checksumType = text;
            } else if (inBlockMap && name == QLatin1String("Range")) {
                const QStringList parts = text.split(QLatin1Char('-'));
                bool okStart = false;
                bool okEnd = false;
                const quint64 start = parts.value(0).toULongLong(&okStart);
                const quint64 end = parts.value(1).toULongLong(&okEnd);
                if (okStart) {
                    BmapRange r;
                    r.start = start;
                    r.end = okEnd ? end : start;
                    r.checksum = curChksum;
                    ranges.append(r);
                }
            } else if (name == QLatin1String("BlockMap")) {
                inBlockMap = false;
            }
            curText.clear();
        }
    }

    if (xml.hasError()) {
        if (error) *error = QStringLiteral("bmap XML 解析失败: %1").arg(xml.errorString());
        return false;
    }

    std::sort(ranges.begin(), ranges.end(),
              [](const BmapRange &a, const BmapRange &b) { return a.start < b.start; });
    bmap.ranges = ranges;
    *out = bmap;
    return true;
}
