import Quickshell
import Quickshell.Io
import QtQuick

PopupWindow {
    id: aboutPopup

    property var barWindow
    property var info: ({})

    anchor.window: barWindow
    anchor.rect.x: barWindow ? (barWindow.width - implicitWidth) / 2 : 320
    anchor.rect.y: -implicitHeight - 45

    implicitWidth: 1320
    implicitHeight: 960
    visible: false
    color: "transparent"

    onVisibleChanged: {
        if (visible) {
            infoProc.running = false
            Qt.callLater(function() {
                infoProc.running = true
            })
        }
    }

    Process {
        id: infoProc
        command: ["/home/rick/.local/bin/rick-about-data"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var values = {}
                var lines = this.text.trim().split("\n")

                for (var i = 0; i < lines.length; ++i) {
                    var pos = lines[i].indexOf("=")
                    if (pos > 0) {
                        var key = lines[i].substring(0, pos)
                        var value = lines[i].substring(pos + 1)
                        values[key] = value
                    }
                }

                aboutPopup.info = values
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: "#07111F"
        border.color: "#23D7FF"
        border.width: 2
        clip: true

        Image {
            anchors.fill: parent
            source: "file:///home/rick/Pictures/RicksLinuxWallpaper/wallpaper.png"
            fillMode: Image.PreserveAspectCrop
            opacity: 0.82
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.02, 0.05, 0.10, 0.74)
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 28
            anchors.verticalCenter: parent.verticalCenter

            text: "★"
            color: "#23D7FF"
            opacity: 0.11
            font.pixelSize: 420
            font.bold: true
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 18
            radius: 16
            color: Qt.rgba(0.02, 0.05, 0.10, 0.58)
            border.color: "#7FCFF0"
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 8

                Item {
                    width: parent.width
                    height: 125

                    Text {
                        x: 22
                        y: 0
                        text: "☆"
                        color: "#F5F9FF"
                        font.pixelSize: 92
                        font.bold: true
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 8
                        spacing: 10

                        Text {
                            text: "RICKS"
                            color: "#F7FBFF"
                            font.pixelSize: 46
                            font.bold: true
                        }

                        Text {
                            text: "HYPRLAND"
                            color: "#FF4BD6"
                            font.pixelSize: 46
                            font.bold: true
                        }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 58
                        width: 430
                        height: 48
                        radius: 10
                        color: Qt.rgba(0.01, 0.03, 0.07, 0.74)
                        border.color: "#23D7FF"
                        border.width: 2

                        Text {
                            anchors.centerIn: parent
                            text: "DALLAS COWBOYS EDITION"
                            color: "#FFFFFF"
                            font.pixelSize: 22
                            font.bold: true
                            font.letterSpacing: 1
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 108
                        text: "ARCH LINUX X86_64"
                        color: "#D4DFEA"
                        font.pixelSize: 17
                        font.bold: true
                        font.letterSpacing: 3
                    }
                }

                Row {
                    width: parent.width
                    height: 28
                    spacing: 12

                    Text {
                        text: "HARDWARE"
                        color: "#23D7FF"
                        font.pixelSize: 17
                        font.bold: true
                    }

                    Rectangle {
                        width: parent.width - 145
                        height: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#23D7FF"
                        opacity: 0.80
                    }
                }

                Column {
                    width: parent.width
                    spacing: 5

                    Repeater {
                        model: [
                            { label: "Host:", value: aboutPopup.info.HOST || "Loading..." },
                            { label: "CPU:", value: aboutPopup.info.CPU || "Loading..." },
                            { label: "GPU:", value: aboutPopup.info.GPU || "Loading..." },
                            { label: "Display:", value: aboutPopup.info.DISPLAY || "Loading..." },
                            { label: "Memory:", value: aboutPopup.info.MEMORY || "Loading..." },
                            { label: "Disk (/):", value: aboutPopup.info.DISK || "Loading..." }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: parent.width
                            height: 36
                            radius: 6
                            color: Qt.rgba(0.03, 0.09, 0.16, 0.80)
                            border.color: "#4B7A95"
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "◆"
                                    color: index % 2 === 0 ? "#23D7FF" : "#FF4BD6"
                                    font.pixelSize: 13
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 210
                                    text: modelData.label
                                    color: "#23D7FF"
                                    font.family: "monospace"
                                    font.pixelSize: 17
                                    font.bold: true
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 260
                                    text: modelData.value
                                    color: "#F6FAFF"
                                    font.family: "monospace"
                                    font.pixelSize: 17
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 28
                    spacing: 12

                    Text {
                        text: "SOFTWARE"
                        color: "#FF4BD6"
                        font.pixelSize: 17
                        font.bold: true
                    }

                    Rectangle {
                        width: parent.width - 145
                        height: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#FF4BD6"
                        opacity: 0.80
                    }
                }

                Column {
                    width: parent.width
                    spacing: 5

                    Repeater {
                        model: [
                            { label: "OS:", value: aboutPopup.info.OS || "Loading..." },
                            { label: "Kernel:", value: aboutPopup.info.KERNEL || "Loading..." },
                            { label: "Window Manager:", value: aboutPopup.info.WM || "Loading..." },
                            { label: "Terminal:", value: aboutPopup.info.TERMINAL || "Loading..." },
                            { label: "Packages:", value: aboutPopup.info.PACKAGES || "Loading..." },
                            { label: "Local IP:", value: aboutPopup.info.LOCAL_IP || "Loading..." }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: parent.width
                            height: 36
                            radius: 6
                            color: Qt.rgba(0.03, 0.09, 0.16, 0.80)
                            border.color: "#4B7A95"
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "◆"
                                    color: index % 2 === 0 ? "#FF4BD6" : "#23D7FF"
                                    font.pixelSize: 13
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 210
                                    text: modelData.label
                                    color: "#23D7FF"
                                    font.family: "monospace"
                                    font.pixelSize: 17
                                    font.bold: true
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 260
                                    text: modelData.value
                                    color: "#F6FAFF"
                                    font.family: "monospace"
                                    font.pixelSize: 17
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 28
                    spacing: 12

                    Text {
                        text: "AGE / UPTIME / INSTALL"
                        color: "#23D7FF"
                        font.pixelSize: 17
                        font.bold: true
                    }

                    Rectangle {
                        width: parent.width - 290
                        height: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#23D7FF"
                        opacity: 0.80
                    }
                }

                Column {
                    width: parent.width
                    spacing: 5

                    Repeater {
                        model: [
                            { label: "OS Age:", value: aboutPopup.info.OS_AGE || "Loading..." },
                            { label: "Uptime:", value: aboutPopup.info.UPTIME || "Loading..." },
                            { label: "Installed:", value: aboutPopup.info.INSTALLED || "Loading..." }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: parent.width
                            height: 36
                            radius: 6
                            color: Qt.rgba(0.03, 0.09, 0.16, 0.80)
                            border.color: "#4B7A95"
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "◆"
                                    color: index % 2 === 0 ? "#23D7FF" : "#FF4BD6"
                                    font.pixelSize: 13
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 210
                                    text: modelData.label
                                    color: "#23D7FF"
                                    font.family: "monospace"
                                    font.pixelSize: 17
                                    font.bold: true
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 260
                                    text: modelData.value
                                    color: "#F6FAFF"
                                    font.family: "monospace"
                                    font.pixelSize: 17
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 36

                    Text {
                        anchors.centerIn: parent
                        text: "Ricks Hyprland   •   Dallas Cowboys Edition   •   Arch Linux x86_64"
                        color: "#CFD9E4"
                        font.pixelSize: 15
                        font.bold: true
                    }
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 10
                width: 38
                height: 38
                radius: 19
                color: Qt.rgba(0.04, 0.08, 0.15, 0.92)
                border.color: "#FF4BD6"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: "#FFFFFF"
                    font.pixelSize: 23
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: aboutPopup.visible = false
                }
            }
        }
    }
}
