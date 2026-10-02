//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    property var themes: []
    property string statusText: "Loading themes..."

    function refreshThemes() {
        if (!listProc.running)
            listProc.running = true
    }

    Process {
        id: listProc

        command: [
            "/home/rick/.local/bin/rick-theme",
            "list"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var items = []
                var output = this.text.trim()

                if (output.length > 0) {
                    var lines = output.split("\n")

                    for (var i = 0; i < lines.length; ++i) {
                        var parts = lines[i].split("|")

                        if (parts.length >= 5) {
                            items.push({
                                id: parts[0],
                                name: parts[1],
                                edition: parts[2],
                                description: parts[3],
                                active: parts[4] === "yes"
                            })
                        }
                    }
                }

                root.themes = items

                var current = "None"

                for (var j = 0; j < items.length; ++j) {
                    if (items[j].active) {
                        current = items[j].name
                        break
                    }
                }

                root.statusText = "Current Theme: " + current
            }
        }
    }

    Process {
        id: applyProc

        property string themeName: ""

        running: false

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0)
                root.statusText = "Applied: " + themeName
            else
                root.statusText = "Theme apply failed"

            refreshTimer.restart()
        }
    }

    Timer {
        id: refreshTimer
        interval: 800
        repeat: false

        onTriggered: root.refreshThemes()
    }

    FloatingWindow {
        id: window

        visible: true
        title: "Rick Theme Manager"

        implicitWidth: 1040
        implicitHeight: 650

        color: "#090B10"

        onClosed: Qt.quit()

        Rectangle {
            anchors.fill: parent
            color: "#090B10"

            Column {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 18

                Row {
                    width: parent.width
                    height: 72

                    Column {
                        width: parent.width - 120
                        spacing: 4

                        Text {
                            text: "RICK THEME MANAGER"
                            color: "#FFFFFF"
                            font.pixelSize: 30
                            font.bold: true
                        }

                        Text {
                            text: root.statusText
                            color: "#FF8C32"
                            font.pixelSize: 16
                        }
                    }

                    Rectangle {
                        width: 100
                        height: 42
                        radius: 8
                        color: closeMouse.containsMouse
                            ? "#442222"
                            : "#25191A"

                        border.color: "#FF6A32"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "CLOSE"
                            color: "#FFFFFF"
                            font.bold: true
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Qt.quit()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#3C414A"
                }

                Text {
                    text: "Choose a theme"
                    color: "#D7DBE2"
                    font.pixelSize: 18
                    font.bold: true
                }

                Flow {
                    id: themeFlow

                    width: parent.width
                    spacing: 20

                    Repeater {
                        model: root.themes

                        delegate: Rectangle {
                            required property var modelData

                            width: 300
                            height: 390
                            radius: 14

                            color: modelData.active
                                ? "#191C24"
                                : "#11141A"

                            border.color: modelData.active
                                ? "#FF8C32"
                                : "#3C414A"

                            border.width: modelData.active ? 2 : 1

                            clip: true

                            Column {
                                anchors.fill: parent
                                spacing: 0

                                Rectangle {
                                    width: parent.width
                                    height: 180
                                    color: "#050609"

                                    Image {
                                        anchors.fill: parent

                                        source:
                                            "file:///home/rick/.config/ricks-hyprland/themes/"
                                            + modelData.id
                                            + "/wallpaper.png"

                                        fillMode: Image.PreserveAspectCrop
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: "#30343C"
                                        border.width: 1
                                    }

                                    Rectangle {
                                        visible: modelData.active

                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 10

                                        width: 82
                                        height: 28
                                        radius: 14

                                        color: "#FF8C32"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "ACTIVE"
                                            color: "#111111"
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    height: 210

                                    padding: 16
                                    spacing: 8

                                    Text {
                                        width: parent.width - 32
                                        text: modelData.name
                                        color: "#FFFFFF"
                                        font.pixelSize: 22
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width - 32
                                        text: modelData.edition
                                        color: "#FF8C32"
                                        font.pixelSize: 13
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width - 32
                                        height: 48
                                        text: modelData.description
                                        color: "#AEB4BF"
                                        font.pixelSize: 13
                                        wrapMode: Text.WordWrap
                                    }

                                    Item {
                                        width: 1
                                        height: 8
                                    }

                                    Rectangle {
                                        width: parent.width - 32
                                        height: 44
                                        radius: 8

                                        color: modelData.active
                                            ? "#292D35"
                                            : applyMouse.containsMouse
                                                ? "#FF9C4A"
                                                : "#FF7A24"

                                        Text {
                                            anchors.centerIn: parent

                                            text: modelData.active
                                                ? "CURRENT THEME"
                                                : "APPLY"

                                            color: modelData.active
                                                ? "#AEB4BF"
                                                : "#111111"

                                            font.pixelSize: 14
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: applyMouse

                                            anchors.fill: parent
                                            hoverEnabled: !modelData.active
                                            enabled: !modelData.active

                                            onClicked: {
                                                root.statusText =
                                                    "Applying "
                                                    + modelData.name
                                                    + "..."

                                                applyProc.themeName =
                                                    modelData.name

                                                applyProc.command = [
                                                    "/home/rick/.local/bin/rick-theme",
                                                    "apply",
                                                    modelData.id
                                                ]

                                                applyProc.running = true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    width: 1
                    height: 6
                }

                Text {
                    text:
                        "Themes are discovered automatically from ~/.config/ricks-hyprland/themes"

                    color: "#737A86"
                    font.pixelSize: 12
                }
            }
        }
    }
}
