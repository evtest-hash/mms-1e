# MMS-1e SD Card Imager

macOS 原生应用，使用 bmap 快速将镜像写入 SD 卡。专为 MMS-1e 设备设计。

## 系统要求

- **macOS 10.15 Catalina** 及以上
- **架构**: Universal Binary (Intel x86_64 + Apple Silicon arm64)

## 安装

从 [Releases](../../releases) 下载最新的 `.dmg` 文件，打开后将应用拖入 Applications 即可。

## 功能

- 原生 Swift + SwiftUI 开发，无外部依赖
- 内置 bmap 解析与写入引擎（替代 bmaptool）
- 支持 `.img` / `.img.gz` 镜像和 `.bmap` 文件
- 自动检测 SD 卡等可移动存储设备
- 实时进度显示与日志输出
- 多层安全防护：排除系统盘、大容量盘、写入前二次确认
- 拖放文件支持

## 从源码构建

```bash
# 开发调试
./build.sh

# Release 构建并启动
./build.sh release

# 打包 Universal DMG
./build.sh dmg
```

需要 Xcode Command Line Tools (`xcode-select --install`)。

## 项目结构

```
Sources/
├── MMS1eImager/        # macOS GUI 应用
│   ├── main.swift      # 入口 (NSApplicationDelegate)
│   ├── ContentView.swift
│   ├── ImagerViewModel.swift
│   ├── ImagingService.swift
│   └── DeviceManager.swift
├── Writer/             # 特权写入工具 (mms-writer)
│   ├── main.swift
│   ├── BmapParser.swift
│   └── BmapCopier.swift
└── CZlib/              # 系统 zlib 模块 (gzip 解压)
```

## 安全机制

设备检测有 5 层过滤，防止误写系统盘：

1. 永远排除 `/dev/disk0`（启动盘）
2. 排除含 Apple 系统分区的磁盘
3. 排除 Apple 品牌存储设备
4. 排除 > 256 GB 的大容量磁盘
5. 仅显示可移动介质或外部设备

写入前需勾选确认 + 输入管理员密码。

## License

MIT
