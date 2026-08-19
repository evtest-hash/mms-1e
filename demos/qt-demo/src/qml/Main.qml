import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs

// MMS-1e SD Card Imager —— Qt/C++ Demo 主界面
// 对应 Swift 版 ContentView.swift 的三步流程：
//   ① 选择镜像/bmap → ② 选择设备 → ③ 烧录进度
ApplicationWindow {
    id: root
    visible: true
    width: 700
    height: 640
    minimumWidth: 640
    minimumHeight: 580
    title: qsTr("MMS-1e SD Card Imager (Qt Demo)")

    component StepCard: Rectangle {
        id: card
        property string step
        property string title
        property bool complete: false
        default property alias content: contentCol.data

        Layout.fillWidth: true
        radius: 10
        color: palette.base
        border.color: Qt.rgba(palette.mid.r, palette.mid.g, palette.mid.b, 0.55)
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            RowLayout {
                spacing: 10
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: card.complete ? "#2e8b57" : "#1f5fa8"
                    Text {
                        anchors.centerIn: parent
                        text: card.complete ? "✓" : card.step
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
                Text {
                    text: card.title
                    font.pixelSize: 14
                    font.bold: true
                    color: palette.windowText
                }
            }

            ColumnLayout {
                id: contentCol
                Layout.fillWidth: true
                spacing: 8
            }
        }
    }

    component FileRow: Rectangle {
        id: frow
        property string label
        property string hint
        property string path
        signal browse()

        Layout.fillWidth: true
        Layout.preferredHeight: 48
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: frow.path === "" ? frow.label : frow.path.split("/").pop()
                    font.pixelSize: 13
                    font.bold: frow.path !== ""
                    color: palette.windowText
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
                Text {
                    text: frow.path === ""
                          ? frow.hint
                          : frow.path.substring(0, frow.path.lastIndexOf("/"))
                    font.pixelSize: 11
                    color: palette.mid
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }

            Text {
                text: frow.path === "" ? "" : "✓"
                color: "#2e8b57"
                font.pixelSize: 13
                font.bold: true
                visible: frow.path !== ""
            }

            Button {
                text: "浏览…"
                onClicked: frow.browse()
            }
        }
    }

    FileDialog {
        id: fileDialog
        property string target: ""
        onAccepted: {
            const raw = fileDialog.selectedFile.toString()
            const path = raw.startsWith("file://") ? decodeURIComponent(raw.slice(7)) : raw
            if (target === "image") writer.imagePath = path
            else if (target === "bmap") writer.bmapPath = path
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ──────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 78
            color: palette.window
            RowLayout {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Rectangle {
                    width: 44
                    height: 44
                    radius: 11
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1f5fa8" }
                        GradientStop { position: 1.0; color: "#5b9bd5" }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "SD"
                        color: "#ffffff"
                        font.pixelSize: 16
                        font.bold: true
                    }
                }
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "MMS-1e SD 卡烧录工具"
                        font.pixelSize: 17
                        font.bold: true
                        color: palette.windowText
                    }
                    Text {
                        text: "Qt/C++ Demo · rpi-imager 架构蓝本"
                        font.pixelSize: 12
                        color: palette.mid
                    }
                }
            }
        }

        // ── Body ────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 16
            Layout.bottomMargin: 12
            spacing: 14

            // Step 1：选择文件
            StepCard {
                step: "1"
                title: "选择文件"
                complete: writer.imagePath !== "" && writer.bmapPath !== ""

                FileRow {
                    label: "镜像文件"
                    hint: "(.img)"
                    path: writer.imagePath
                    onBrowse: { fileDialog.target = "image"; fileDialog.open() }
                }
                FileRow {
                    label: "Bmap 文件"
                    hint: "(.bmap)"
                    path: writer.bmapPath
                    onBrowse: { fileDialog.target = "bmap"; fileDialog.open() }
                }
            }

            // Step 2：选择设备
            StepCard {
                step: "2"
                title: "选择设备"
                complete: writer.devicePath !== ""

                ListView {
                    id: devList
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(deviceModel.count, 4) * 36 + 4
                    model: deviceModel
                    clip: true
                    currentIndex: 0
                    delegate: Rectangle {
                        required property string display
                        required property string identifier

                        width: devList.width
                        height: 36
                        radius: 6
                        color: ListView.isCurrentItem ? palette.highlight : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 20
                            text: parent.display
                            color: ListView.isCurrentItem ? palette.highlightedText : palette.windowText
                            font.pixelSize: 13
                            elide: Text.ElideMiddle
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                devList.currentIndex = index
                                writer.devicePath = identifier
                            }
                        }
                    }
                }
            }

            // Step 3：烧录进度
            StepCard {
                step: "3"
                title: "烧录进度"
                complete: writer.progress >= 100 && !writer.isWriting

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        id: progressTrack
                        Layout.fillWidth: true
                        Layout.preferredHeight: 8
                        radius: 4
                        color: palette.midlight
                        Rectangle {
                            width: progressTrack.width * (writer.progress / 100.0)
                            height: parent.height
                            radius: 4
                            color: writer.progress >= 100
                                   ? "#2e8b57"
                                   : (writer.isWriting ? "#1f5fa8" : palette.mid)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: writer.progress + "%"
                            font.pixelSize: 12
                            font.bold: true
                            color: palette.windowText
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: writer.statusMessage
                            font.pixelSize: 12
                            color: palette.mid
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 130
                        radius: 6
                        color: palette.midlight
                        border.color: Qt.rgba(palette.mid.r, palette.mid.g, palette.mid.b, 0.4)
                        border.width: 1
                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 6
                            contentHeight: logText.height
                            clip: true
                            Text {
                                id: logText
                                width: parent.width
                                text: writer.logText === "" ? "等待开始…" : writer.logText
                                font.family: "monospace"
                                font.pixelSize: 11
                                color: writer.logText === "" ? palette.mid : palette.windowText
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }
        }

        // ── Footer ──────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: palette.window

            RowLayout {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text {
                    text: writer.statusMessage
                    font.pixelSize: 12
                    color: palette.mid
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Button {
                    text: writer.isWriting ? "写入中…" : "开始烧录"
                    enabled: writer.canStart
                    onClicked: writer.startWrite()
                }
            }
        }
    }
}
