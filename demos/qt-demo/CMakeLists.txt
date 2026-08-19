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

qt_add_qml_module(mms1e-qt-demo
    URI MMS1eDemo
    VERSION 1.0
    QML_FILES src/qml/Main.qml
)

target_link_libraries(mms1e-qt-demo PRIVATE
    Qt6::Core Qt6::Gui Qt6::Quick Qt6::Qml Qt6::Concurrent
)
