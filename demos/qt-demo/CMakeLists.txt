cmake_minimum_required(VERSION 3.16)
project(mms1e-qt-demo VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml Concurrent)

qt_add_executable(mms1e-qt-demo
    src/main.cpp
    src/core/BmapParser.cpp
    src/core/BlockDeviceFile.cpp
    src/core/ImageWriter.cpp
    src/platform/PlatformQuirks.cpp
    src/app/DeviceModel.cpp
    src/app/WriterController.cpp
)

# 内嵌 QML 为资源（兼容 Qt 6.4，避免 loadFromModule 的 6.5+ 依赖）
qt_add_resources(mms1e-qt-demo "qml"
    PREFIX "/qml"
    BASE "src/qml"
    FILES src/qml/Main.qml
)

target_link_libraries(mms1e-qt-demo PRIVATE
    Qt6::Core Qt6::Gui Qt6::Quick Qt6::Qml Qt6::Concurrent
)
