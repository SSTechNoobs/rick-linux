import Quickshell
import Quickshell.Io
import QtQuick

PopupWindow {
    id: launcher

    property var barWindow
    property var aboutPopupWindow
    property var powerMenuWindow
    property var shellRoot

    // Aether global-theme colors.
    property string themeBackground: "#041E42"
    property string themeForeground: "#FFFFFF"
    property string themeAccent: "#003594"
    property string themeMuted: "#869397"
    property string themeSurface: "#0C2340"
    property string themeBright: "#DDF8FF"

    function refreshThemeColors() {
        aetherColorProc.running = false

        Qt.callLater(function() {
            aetherColorProc.running = true
        })
    }

    Process {
        id: aetherColorProc

        command: [
            "/home/rick/.local/bin/rick-aether-colors"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("|")

                if (parts.length >= 6) {
                    launcher.themeBackground = parts[0]
                    launcher.themeForeground = parts[1]
                    launcher.themeAccent = parts[2]
                    launcher.themeMuted = parts[3]
                    launcher.themeSurface = parts[4]
                    launcher.themeBright = parts[5]
                }
            }
        }
    }

    function isPinned(key) {
        if (!shellRoot || !shellRoot.taskbarPins)
            return false

        for (var i = 0; i < shellRoot.taskbarPins.length; ++i) {
            if (shellRoot.taskbarPins[i].key === key)
                return true
        }

        return false
    }


    property var installedApps: []

    function refreshInstalledApps() {
        appListProc.running = false

        Qt.callLater(function() {
            appListProc.running = true
        })
    }

    Process {
        id: appListProc

        command: [
            "/home/rick/.local/bin/rick-apps",
            "list"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var apps = []
                var output = this.text.trim()

                if (output.length > 0) {
                    var lines = output.split("\n")

                    for (var i = 0; i < lines.length; ++i) {
                        var parts = lines[i].split("|")

                        if (parts.length >= 4) {
                            apps.push({
                                key: parts[0],
                                name: parts[1],
                                icon: parts[3],
                                subtitle: "Installed application"
                            })
                        }
                    }
                }

                launcher.installedApps = apps
            }
        }
    }

    Connections {
        target: launcher

        function onVisibleChanged() {
            if (launcher.visible) {
                launcher.refreshThemeColors()
                launcher.refreshInstalledApps()
            }
        }
    }

    anchor.window: barWindow
    anchor.rect.x: 18
    anchor.rect.y: -implicitHeight

    implicitWidth: 820
    implicitHeight: 740

    visible: false
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 24
        clip: true

        color: launcher.themeBackground
        border.color: launcher.themeMuted
        border.width: 2

        /*
         * Cowboys wallpaper behind the glass.
         */
        Image {
            anchors.fill: parent
            source: "file:///home/rick/Pictures/RicksLinuxWallpaper/wallpaper.png"
            fillMode: Image.PreserveAspectCrop
            opacity: 0.46
        }

        /*
         * Dark blue glass layer.
         */
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.015, 0.035, 0.075, 0.76)
        }

        /*
         * Decorative giant star.
         */
        Text {
            anchors.right: parent.right
            anchors.rightMargin: -55
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -70

            text: "☆"
            color: launcher.themeMuted
            opacity: 0.10

            font.pixelSize: 330
            font.bold: true
        }

        /*
         * Thin inner frame.
         */
        Rectangle {
            anchors.fill: parent
            anchors.margins: 10

            radius: 19
            color: "transparent"

            border.color: Qt.rgba(0.45, 0.85, 1.0, 0.40)
            border.width: 1
        }

        Column {
            anchors.fill: parent
            anchors.margins: 24

            spacing: 14

            /*
             * ===========================
             * HEADER
             * ===========================
             */
            Item {
                width: parent.width
                height: 122

                /*
                 * Matching Dallas Cowboys stars.
                 */
                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 5
                    anchors.topMargin: 5

                    text: "★"
                    color: launcher.themeMuted
                    opacity: 0.26

                    font.pixelSize: 76
                }

                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: 5
                    anchors.topMargin: 5

                    text: "★"
                    color: launcher.themeMuted
                    opacity: 0.26

                    font.pixelSize: 76
                }

                /*
                 * Centered Ricks Hyprland title.
                 */
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4
                    spacing: 9

                    Text {
                        text: "RICKS"
                        color: launcher.themeForeground

                        font.pixelSize: 32
                        font.bold: true
                    }

                    Text {
                        text: "HYPRLAND"
                        color: launcher.themeAccent

                        font.pixelSize: 32
                        font.bold: true
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 45

                    text: "Dallas Cowboys Edition"
                    color: launcher.themeBright

                    font.pixelSize: 16
                    font.bold: true
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 72
                    spacing: 8

                    Rectangle {
                        width: 94
                        height: 25
                        radius: 12

                        color: Qt.rgba(0.00, 0.21, 0.58, 0.38)

                        border.color: launcher.themeMuted
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "ARCH LINUX"
                            color: launcher.themeBright

                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    Rectangle {
                        width: 88
                        height: 25
                        radius: 12

                        color: Qt.rgba(0.53, 0.58, 0.59, 0.24)

                        border.color: launcher.themeAccent
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "HYPRLAND"
                            color: "#FFDDF8"

                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    Rectangle {
                        width: 80
                        height: 25
                        radius: 12

                        color: Qt.rgba(0.00, 0.21, 0.58, 0.28)

                        border.color: launcher.themeMuted
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "WAYLAND"
                            color: launcher.themeBright

                            font.pixelSize: 10
                            font.bold: true
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    height: 2
                    radius: 1

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0.0
                            color: launcher.themeMuted
                        }

                        GradientStop {
                            position: 0.55
                            color: launcher.themeMuted
                        }

                        GradientStop {
                            position: 1.0
                            color: launcher.themeAccent
                        }
                    }
                }
            }

            /*
             * ===========================
             * CONTENT COLUMNS
             * ===========================
             */
            Row {
                width: parent.width
                height: 522

                spacing: 18

                /*
                 * APPS
                 */
                Column {
                    width: (parent.width - 18) / 2
                    spacing: 7

                    Row {
                        width: parent.width
                        height: 30
                        spacing: 9

                        Text {
                            text: "◆"
                            color: launcher.themeMuted
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "APPS"
                            color: launcher.themeMuted

                            font.pixelSize: 17
                            font.bold: true

                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: parent.width - 75
                            height: 2

                            anchors.verticalCenter: parent.verticalCenter

                            color: launcher.themeMuted
                            opacity: 0.65
                        }
                    }

                    ListView {
                        id: appsList

                        width: parent.width
                        height: 465
                        spacing: 7
                        clip: true

                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds

                        model: launcher.installedApps

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: parent.width
                            height: 53
                            radius: 13

                            color: appTileMouse.containsMouse
                                ? Qt.rgba(0.08, 0.16, 0.28, 0.92)
                                : Qt.rgba(0.025, 0.075, 0.13, 0.82)

                            border.color: appTileMouse.containsMouse
                                ? launcher.themeMuted
                                : "#284B64"

                            border.width: appTileMouse.containsMouse ? 2 : 1

                            scale: appTileMouse.containsMouse ? 1.018 : 1.0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 110
                                }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                spacing: 11

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter

                                    width: 35
                                    height: 35
                                    radius: 10

                                    color: index % 2 === 0
                                        ? Qt.rgba(0.53, 0.58, 0.59, 0.22)
                                        : Qt.rgba(0.00, 0.21, 0.58, 0.22)

                                    border.color: index % 2 === 0
                                        ? launcher.themeMuted
                                        : launcher.themeAccent

                                    border.width: 1

                                    Image {
                                        id: appIconImage

                                        anchors.centerIn: parent

                                        width: 25
                                        height: 25

                                        source: modelData.icon.length > 0
                                            ? "file://" + modelData.icon
                                            : ""

                                        fillMode: Image.PreserveAspectFit

                                        visible:
                                            status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent

                                        text: "◆"
                                        color: launcher.themeForeground

                                        font.pixelSize: 15
                                        font.bold: true

                                        visible:
                                            appIconImage.status !== Image.Ready
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        text: modelData.name
                                        color: launcher.themeForeground

                                        font.pixelSize: 15
                                        font.bold: true
                                    }

                                    Text {
                                        text: modelData.subtitle
                                        color: launcher.themeMuted

                                        font.pixelSize: 10
                                    }
                                }
                            }

                            Process {
                                id: pinToggleProc

                                running: false

                                onExited: {
                                    if (launcher.shellRoot)
                                        launcher.shellRoot.refreshTaskbarPins()
                                }
                            }

                            MouseArea {
                                id: appTileMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        pinContextMenu.visible =
                                            !pinContextMenu.visible
                                    } else {
                                        pinContextMenu.visible = false
                                        launcher.visible = false
                                        Quickshell.execDetached([
                                            "/home/rick/.local/bin/rick-taskbar-pins",
                                            "run",
                                            modelData.key
                                        ])
                                    }
                                }
                            }

                            Rectangle {
                                id: pinContextMenu

                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter

                                width: 165
                                height: 36
                                radius: 9
                                z: 100
                                visible: false

                                color: launcher.themeBackground
                                border.color: launcher.themeMuted
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent

                                    text: launcher.isPinned(modelData.key)
                                        ? "Remove from Taskbar"
                                        : "Pin to Taskbar"

                                    color: launcher.themeForeground
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true

                                    onClicked: {
                                        pinToggleProc.command = [
                                            "/home/rick/.local/bin/rick-taskbar-pins",
                                            "toggle",
                                            modelData.key
                                        ]

                                        pinContextMenu.visible = false
                                        pinToggleProc.running = true
                                    }
                                }
                            }
                        }
                    }
                }

                /*
                 * SYSTEM
                 */
                Column {
                    width: (parent.width - 18) / 2
                    spacing: 7

                    Row {
                        width: parent.width
                        height: 30
                        spacing: 9

                        Text {
                            text: "◆"
                            color: launcher.themeAccent
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "SYSTEM"
                            color: launcher.themeAccent

                            font.pixelSize: 17
                            font.bold: true

                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: parent.width - 95
                            height: 2

                            anchors.verticalCenter: parent.verticalCenter

                            color: launcher.themeAccent
                            opacity: 0.65
                        }
                    }

                    Repeater {
                        model: [
                            {
                                icon: "file:///home/rick/.config/quickshell/rick/system-icons/about.svg",
                                name: "About Ricks Linux",
                                subtitle: "Hardware & system details",
                                action: "about"
                            },
                            {
                                icon: "file:///home/rick/.config/quickshell/rick/system-icons/bluetooth.svg",
                                name: "Bluetooth",
                                subtitle: "Bluetooth devices",
                                cmd: ["/home/rick/.local/bin/rick-bluetooth"]
                            },
                            {
                                icon: "file:///home/rick/.config/quickshell/rick/system-icons/network.svg",
                                name: "Network",
                                subtitle: "Connections & Wi-Fi",
                                cmd: ["nm-connection-editor"]
                            },
                            {
                                icon: "file:///home/rick/.config/quickshell/rick/system-icons/printer.svg",
                                name: "Printer Settings",
                                subtitle: "Printers & queues",
                                cmd: ["system-config-printer"]
                            },
                            {
                                icon: "file:///home/rick/.config/quickshell/rick/system-icons/volume.svg",
                                name: "Volume",
                                subtitle: "Audio controls",
                                cmd: ["/home/rick/.local/bin/rick-volume"]
                            },
                            {
                                icon: "file:///home/rick/.config/quickshell/rick/system-icons/power.svg",
                                name: "Power",
                                subtitle: "Shutdown & session",
                                action: "power"
                            }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: parent.width
                            height: 53
                            radius: 13

                            color: sysTileMouse.containsMouse
                                ? Qt.rgba(0.00, 0.21, 0.58, 0.34)
                                : Qt.rgba(0.025, 0.075, 0.13, 0.82)

                            border.color: sysTileMouse.containsMouse
                                ? launcher.themeAccent
                                : "#284B64"

                            border.width: sysTileMouse.containsMouse ? 2 : 1

                            scale: sysTileMouse.containsMouse ? 1.018 : 1.0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 110
                                }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                spacing: 11

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter

                                    width: 35
                                    height: 35
                                    radius: 10

                                    color: index % 2 === 0
                                        ? Qt.rgba(0.00, 0.21, 0.58, 0.22)
                                        : Qt.rgba(0.53, 0.58, 0.59, 0.22)

                                    border.color: index % 2 === 0
                                        ? launcher.themeAccent
                                        : launcher.themeMuted

                                    border.width: 1

                                    Image {
                                        anchors.centerIn: parent

                                        width: 23
                                        height: 23

                                        source: modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        mipmap: true

                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        text: modelData.name
                                        color: launcher.themeForeground

                                        font.pixelSize: 15
                                        font.bold: true
                                    }

                                    Text {
                                        text: modelData.subtitle
                                        color: launcher.themeMuted

                                        font.pixelSize: 10
                                    }
                                }
                            }

                            MouseArea {
                                id: sysTileMouse

                                anchors.fill: parent
                                hoverEnabled: true

                                function openPowerSubmenu() {
                                    var globalPoint = parent.mapToGlobal(
                                        Qt.point(55, parent.height / 2)
                                    )

                                    var barPoint = barWindow.contentItem.mapFromGlobal(
                                        globalPoint
                                    )

                                    powerMenuWindow.anchor.rect.x =
                                        barPoint.x + 8

                                    powerMenuWindow.anchor.rect.y =
                                        barPoint.y - (powerMenuWindow.height / 2)

                                    powerMenuWindow.visible = true
                                }

                                onEntered: {
                                    if (modelData.action === "power") {
                                        openPowerSubmenu()
                                    } else if (powerMenuWindow.visible) {
                                        powerMenuWindow.visible = false
                                    }
                                }

                                onClicked: {
                                    if (modelData.action === "power") {
                                        openPowerSubmenu()
                                        return
                                    }

                                    launcher.visible = false

                                    if (modelData.action === "about") {
                                        aboutPopupWindow.visible = true
                                    } else {
                                        Quickshell.execDetached(modelData.cmd)
                                    }
                                }
                            }
                        }
                    }

                    /*
                     * Extra eye-candy status panel.
                     */
                    Rectangle {
                        width: parent.width
                        height: 76
                        radius: 15

                        color: Qt.rgba(0.025, 0.065, 0.12, 0.72)

                        border.color: "#31516A"
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 13

                            spacing: 8

                            Text {
                                text: "RICKS HYPRLAND"
                                color: launcher.themeBright

                                font.pixelSize: 12
                                font.bold: true
                                font.letterSpacing: 1
                            }

                            Text {
                                text: "Custom Built"
                                color: launcher.themeMuted

                                font.pixelSize: 10
                            }

                                                        Rectangle {
                                width: 210
                                height: 1
                                color: launcher.themeMuted
                                opacity: 0.35
                            }
                        }
                    }
                }
            }

            /*
             * FOOTER
             */
            Item {
                width: parent.width
                height: 28

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1

                    color: launcher.themeMuted
                    opacity: 0.40
                }

                Text {
                    anchors.centerIn: parent

                    text: "Ricks Hyprland  •  Dallas Cowboys Edition"
                    color: launcher.themeMuted

                    font.pixelSize: 10
                    font.letterSpacing: 1
                }
            }
        }
    }
}
