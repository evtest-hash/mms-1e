#pragma once

#include "BmapModel.h"

// bmap XML 解析器 —— 从 Swift 版 BmapParser.swift 移植
// (XMLParser -> QXmlStreamReader，逻辑一致)
class BmapParser {
public:
    bool parse(const QString &filePath, BmapFile *out, QString *error = nullptr);
};
