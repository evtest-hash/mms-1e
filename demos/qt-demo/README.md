# MMS-1e Qt/C++ Demo

macOS 版 MMS-1e SD Card Imager 的 **Qt 6 跨平台 demo**，演示「选文件 → 选设备 → 写盘」三步流程在 Qt/C++ 下的实际效果。

采用 **rpi-imager 架构蓝本**：
- `src/platform/PlatformQuirks.*` —— 每 OS 不同的系统行为（卸载、设备枚举、系统盘判定）
- `src/core/BlockDeviceIO.*` —— 块设备 I/O 抽象（demo 用文件模拟 SD 卡）
- `src/core/BmapParser.*` —— 从 Swift 版移植的 bmap 解析器
- `src/core/ImageWriter.*` —— 按 bmap 区间只写 mapped 块

## 构建与运行（在 Linux / Codespace）

```bash
python3 tools/make_test_image.py   # 生成 test.img + test.bmap
./build.sh                          # cmake 配置 + 编译

# 交互运行（需要图形环境 / xvfb）
QT_QPA_PLATFORM=offscreen QSG_RHI_BACKEND=software build/mms1e-qt-demo

# demo 脚本模式：自动加载测试镜像、写盘并输出三张截图
QT_QPA_PLATFORM=offscreen QSG_RHI_BACKEND=software \
    build/mms1e-qt-demo --demo "$(pwd)/tools"
```

截图输出到 `tools/shot-1-initial.png` / `shot-2-writing.png` / `shot-3-done.png`。
