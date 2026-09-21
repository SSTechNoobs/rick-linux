//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Hyprland
import QtQuick

ShellRoot {
    id: root

    HyprlandFocusGrab {
        id: appMenuGrab
        windows: [appMenu]

        onCleared: {
            appMenu.visible = false
        }
    }

    IpcHandler {
        target: "rickmenu"

        function toggle(): void {
            appMenu.visible = !appMenu.visible
        }

        function open(): void {
            appMenu.visible = true
        }

        function close(): void {
            appMenu.visible = false
        }
    }

    property string netStatus: "Checking..."
    property string btStatus: "..."
    property string volumeStatus: "..."
    property string weatherStatus: "Weather..."
    property string forecastStatus: "Loading forecast..."

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE device | awk -F: '$2==\"connected\" { if ($1==\"ethernet\") {print \"Ethernet\"; exit} if ($1==\"wifi\") {print \"Wi-Fi\"; exit} }'"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var value = this.text.trim()
                root.netStatus = value.length ? value : "Offline"
            }
        }
    }

    Process {
        id: btProc
        command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo On || echo Off"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.btStatus = this.text.trim()
        }
    }

    Process {
        id: volumeProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf \"%.0f%%\", $2*100; if (index($0,\"MUTED\")) printf \" muted\"}'"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.volumeStatus = this.text.trim()
        }
    }



    Process {
        id: forecastProc
        command: ["/home/rick/.local/bin/rick-weather-detail"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var value = this.text.trim()
                if (value.length)
                    root.forecastStatus = value
            }
        }
    }

    Timer {
        id: weatherCloseTimer
        interval: 500
        repeat: false

        onTriggered: {
            if (!weatherPopup.pinned)
                weatherPopup.visible = false
        }
    }

    Process {
        id: weatherProc
        command: ["sh", "-c", "curl -fsS --max-time 8 'https://wttr.in/Cedar+Falls,Iowa?format=%c%20%t&u'"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var value = this.text.trim()
                if (value.length)
                    root.weatherStatus = value
            }
        }
    }

    Timer {
        interval: 900000
        running: true
        repeat: true

        onTriggered: {
            if (!weatherProc.running)
                weatherProc.running = true
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true

        onTriggered: {
            if (!netProc.running)
                netProc.running = true
            if (!btProc.running)
                btProc.running = true
            if (!volumeProc.running)
                volumeProc.running = true
        }
    }

    PanelWindow {
        id: bar
        property bool solidBar: false

        anchors {
            bottom: true
            left: true
            right: true
        }

        implicitHeight: 44
        color: solidBar ? "#111827" : "#330C2340"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onDoubleClicked: bar.solidBar = !bar.solidBar
        }

        Rectangle {
            id: powerButton
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 32
            radius: 8
            color: "transparent"

            Text {
                anchors.centerIn: parent
                text: "⏻"
                color: "#ffffff"
                font.pixelSize: 19
            }

            MouseArea {
                anchors.fill: parent
                onClicked: powerMenu.visible = !powerMenu.visible
            }
        }

        PopupWindow {
            id: powerMenu

            anchor.window: bar
            anchor.rect.x: powerButton.x
            anchor.rect.y: -height

            width: 170
            height: 132
            visible: false
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: "#0C2340"
                border.color: "#7F9695"
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    Rectangle {
                        width: 154
                        height: 35
                        radius: 6
                        color: poweroffMouse.containsMouse ? "#1f3d63" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "Power Off"
                            color: "white"
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: poweroffMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                powerMenu.visible = false
                                Quickshell.execDetached(["systemctl", "poweroff"])
                            }
                        }
                    }

                    Rectangle {
                        width: 154
                        height: 35
                        radius: 6
                        color: rebootMouse.containsMouse ? "#1f3d63" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "Reboot"
                            color: "white"
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: rebootMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                powerMenu.visible = false
                                Quickshell.execDetached(["systemctl", "reboot"])
                            }
                        }
                    }

                    Rectangle {
                        width: 154
                        height: 35
                        radius: 6
                        color: logoutMouse.containsMouse ? "#1f3d63" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "Log Out"
                            color: "white"
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: logoutMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                powerMenu.visible = false
                                Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
                            }
                        }
                    }
                }
            }
        }

        Text {
            id: ricksLabel
            anchors.left: powerButton.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            text: "Ricks Linux"
            color: "#ffffff"
            font.pixelSize: 17
            font.bold: true
        

            MouseArea {
                anchors.fill: parent
                onClicked: appMenu.visible = !appMenu.visible
            }
}

        Rectangle {
            id: pcmanfmButton
            anchors.left: ricksLabel.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 32
            radius: 8
            color: "transparent"

            Image {
                anchors.centerIn: parent
                width: 24
                height: 24
                source: "file:///home/rick/.config/quickshell/rick/icons/pcmanfm.svg"
                fillMode: Image.PreserveAspectFit
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Quickshell.execDetached(["/home/rick/.local/bin/rick-files"])
            }
        }

                Rectangle {
            id: terminalButton
            anchors.left: pcmanfmButton.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 32
            radius: 8
            color: "transparent"

            Image {
                anchors.centerIn: parent
                width: 24
                height: 24
                source: "file:///home/rick/.config/quickshell/rick/icons/ghostty.png"
                fillMode: Image.PreserveAspectFit
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Quickshell.execDetached(["ghostty"])
            }
        }

Rectangle {
            id: chatgptButton
            anchors.left: chromeButton.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 32
            radius: 8
            color: "transparent"

            Image {
                anchors.centerIn: parent
                width: 22
                height: 22
                source: "file:///home/rick/.config/quickshell/rick/icons/chatgpt.png"
                    fillMode: Image.PreserveAspectFit
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["/home/rick/.local/bin/rick-chatgpt"])
                }
            }

        Rectangle {
            id: chromeButton
            anchors.left: terminalButton.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 32
            radius: 8
            color: "transparent"

            Image {
                anchors.centerIn: parent
                width: 24
                height: 24
                source: "file:///home/rick/.config/quickshell/rick/icons/chrome.png"
                fillMode: Image.PreserveAspectFit
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Quickshell.execDetached(["/home/rick/.local/bin/rick-chrome"])
            }
        }

        Rectangle {
            anchors.left: chatgptButton.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 32
            radius: 8
            color: "transparent"

            Image {
                anchors.centerIn: parent
                width: 24
                height: 24
                source: "file:///home/rick/.config/quickshell/rick/icons/steam.png"
                fillMode: Image.PreserveAspectFit
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Quickshell.execDetached(["/home/rick/.local/bin/rick-steam"])
            }
        }

        Text {
            id: hyprLabel
            anchors.centerIn: parent
            text: "Hyprland"
            color: "#9ca3af"
            font.pixelSize: 14
        }

        Text {
            id: weatherLabel
            anchors.left: hyprLabel.right
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.weatherStatus
            color: "#ffffff"
            font.pixelSize: 14

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true

                onEntered: {
                    weatherCloseTimer.stop()
                    weatherPopup.visible = true

                    if (!forecastProc.running)
                        forecastProc.running = true
                }

                onExited: {
                    if (!weatherPopup.pinned)
                        weatherCloseTimer.restart()
                }

                onClicked: {
                    weatherCloseTimer.stop()

                    if (weatherPopup.pinned) {
                        weatherPopup.pinned = false
                        weatherPopup.visible = false
                    } else {
                        weatherPopup.pinned = true
                        weatherPopup.visible = true

                        if (!forecastProc.running)
                            forecastProc.running = true
                    }
                }
            }
        }

        PopupWindow {
            id: weatherPopup
            property bool pinned: false

            anchor.window: bar
            anchor.rect.x: Math.max(
                10,
                Math.min(
                    bar.width - width - 10,
                    weatherLabel.x + weatherLabel.width / 2 - width / 2
                )
            )
            anchor.rect.y: -height

            width: 650
            height: 780
            visible: false
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "#E60C2340"
                border.color: "#7F9695"
                border.width: 1

                Text {
                    anchors.fill: parent
                    anchors.margins: 16

                    text: root.forecastStatus
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.family: "monospace"
                    verticalAlignment: Text.AlignTop
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton

                    onEntered: weatherCloseTimer.stop()

                    onExited: {
                        if (!weatherPopup.pinned)
                            weatherCloseTimer.restart()
                    }
                }
            }
        }

        Row {
            id: tray
            anchors.right: controls.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: SystemTray.items

                delegate: Item {
                    required property var modelData
                    width: 28
                    height: 32

                    Image {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: modelData.icon
                        fillMode: Image.PreserveAspectFit
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: mouse => {
                            if (modelData.hasMenu) {
                                var p = bar.mapFromItem(parent, Qt.point(mouse.x, mouse.y))
                                modelData.display(bar, p.x, p.y)
                            } else {
                                modelData.activate()
                            }
                        }
                    }
                }
            }
        }

        Row {
            id: controls
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7


            

            Rectangle {
                width: 42
                height: 32
                radius: 8
                color: "transparent"

                Image {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: "file:///home/rick/.config/quickshell/rick/icons/bluetooth.svg"
                    fillMode: Image.PreserveAspectFit
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["/home/rick/.local/bin/rick-bluetooth"])
                }
            }

            Rectangle {
                width: 42
                height: 32
                radius: 8
                color: "transparent"

                Image {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    source: "file:///home/rick/.config/quickshell/rick/icons/volume.svg"
                    fillMode: Image.PreserveAspectFit
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["/home/rick/.local/bin/rick-volume"])
                }
            }

            

            Text {
                id: dateText
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 5

                text: Qt.formatDateTime(clock.date, "ddd MMM d   h:mm AP")
                color: "#ffffff"
                font.pixelSize: 14
            
                MouseArea {
                    id: dateHover
                    anchors.fill: parent
                    hoverEnabled: true

                    onEntered: dateCalendar.visible = true
                    onExited: calendarHideTimer.restart()
                }
}

            Timer {
                id: calendarHideTimer
                interval: 250
                repeat: false

                onTriggered: {
                    if (!dateHover.containsMouse && !calendarHover.containsMouse)
                        dateCalendar.visible = false
                }
            }

            PopupWindow {
                id: dateCalendar

                property int year: clock.date.getFullYear()
                property int month: clock.date.getMonth()
                property int today: clock.date.getDate()
                property int firstDay: new Date(year, month, 1).getDay()
                property int daysInMonth: new Date(year, month + 1, 0).getDate()

                anchor.window: bar
                anchor.rect.x: bar.width - width - 10
                anchor.rect.y: -height

                width: 300
                height: 300
                visible: false
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: "#0C2340"
                    border.color: "#869397"
                    border.width: 2

                    MouseArea {
                        id: calendarHover
                        anchors.fill: parent
                        hoverEnabled: true

                        onEntered: calendarHideTimer.stop()
                        onExited: calendarHideTimer.restart()
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(clock.date, "MMMM yyyy")
                            color: "#FFFFFF"
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: "#869397"
                        }

                        Grid {
                            columns: 7
                            spacing: 4

                            Repeater {
                                model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

                                delegate: Text {
                                    required property var modelData
                                    width: 34
                                    height: 26
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData
                                    color: "#869397"
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }

                            Repeater {
                                model: 42

                                delegate: Rectangle {
                                    property int dayNumber:
                                        index - dateCalendar.firstDay + 1

                                    width: 34
                                    height: 30
                                    radius: 6

                                    color:
                                        dayNumber === dateCalendar.today
                                        && dayNumber > 0
                                        && dayNumber <= dateCalendar.daysInMonth
                                        ? "#003594"
                                        : "transparent"

                                    Text {
                                        anchors.centerIn: parent

                                        text:
                                            parent.dayNumber > 0
                                            && parent.dayNumber <= dateCalendar.daysInMonth
                                            ? parent.dayNumber
                                            : ""

                                        color: "#FFFFFF"
                                        font.pixelSize: 13
                                        font.bold:
                                            parent.dayNumber === dateCalendar.today
                                    }
                                }
                            }
                        }
                    }
                }
            }

        }
    

        PopupWindow {
            id: appMenu


            anchor.window: bar
            anchor.rect.x: 10
            anchor.rect.y: -height

            width: 520
            height: 560
            visible: false

            onVisibleChanged: {
                if (visible) {
                    Qt.callLater(function() {
                        appMenuGrab.active = true
                    })
                } else {
                    appMenuGrab.active = false
                }
            }

            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "#0C2340"

                border.color: "#869397"
                border.width: 2

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Text {
                        text: "★  RICKS LINUX"
                        color: "#FFFFFF"
                        font.pixelSize: 20
                        font.bold: true
                    }

                    Text {
                        text: "Dallas Cowboys Edition"
                        color: "#869397"
                        font.pixelSize: 12
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#869397"
                    }

                    Row {
                        spacing: 12

                        Column {
                            width: 236
                            spacing: 5

                            Text {
                                text: "APPS"
                                color: "#869397"
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Repeater {
                                model: [
                                    {
                                        name: "Aether",
                                        cmd: ["aether"]
                                    },
                                    {
                                        name: "Calculator",
                                        cmd: ["gnome-calculator"]
                                    },
                                    {
                                        name: "ChatGPT",
                                        cmd: ["/home/rick/.local/bin/rick-chatgpt"]
                                    },
                                    {
                                        name: "Google Chrome",
                                        cmd: ["/home/rick/.local/bin/rick-chrome"]
                                    },
                                    {
                                        name: "Ghostty Terminal",
                                        cmd: ["ghostty"]
                                    },
                                    {
                                        name: "Xed",
                                        cmd: ["xed"]
                                    },
                                    {
                                        name: "PCManFM Files",
                                        cmd: ["/home/rick/.local/bin/rick-files"]
                                    },
                                    {
                                        name: "Steam",
                                        cmd: ["/home/rick/.local/bin/rick-steam"]
                                    }
                                ]

                                delegate: Rectangle {
                                    required property var modelData

                                    width: 236
                                    height: 42
                                    radius: 7

                                    color: appMouse.containsMouse
                                        ? "#003594"
                                        : "#111827"

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 14
                                        anchors.verticalCenter: parent.verticalCenter

                                        text: modelData.name
                                        color: "#FFFFFF"
                                        font.pixelSize: 14
                                    }

                                    MouseArea {
                                        id: appMouse
                                        anchors.fill: parent
                                        hoverEnabled: true

                                        onClicked: {
                                            appMenu.visible = false
                                            Quickshell.execDetached(modelData.cmd)
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            width: 236
                            spacing: 5

                            Text {
                                text: "SYSTEM"
                                color: "#869397"
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Repeater {
                                model: [
                                    {
                                        name: "About Ricks Linux",
                                        cmd: [
                                            "ghostty",
                                            "-e",
                                            "/home/rick/.local/bin/rick-about"
                                        ]
                                    },
                                    {
                                        name: "Bluetooth",
                                        cmd: [
                                            "/home/rick/.local/bin/rick-bluetooth"
                                        ]
                                    },
                                    {
                                        name: "Network",
                                        cmd: ["nm-connection-editor"]
                                    },
                                    {
                                        name: "Printer Settings",
                                        cmd: ["system-config-printer"]
                                    },
                                    {
                                        name: "Volume",
                                        cmd: [
                                            "/home/rick/.local/bin/rick-volume"
                                        ]
                                    },
                                    {
                                        name: "Power",
                                        action: "power"
                                    }
                                ]

                                delegate: Rectangle {
                                    required property var modelData

                                    width: 236
                                    height: 42
                                    radius: 7

                                    color: sysMouse.containsMouse
                                        ? "#003594"
                                        : "#111827"

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 14
                                        anchors.verticalCenter: parent.verticalCenter

                                        text: modelData.name
                                        color: "#FFFFFF"
                                        font.pixelSize: 14
                                    }

                                    MouseArea {
                                        id: sysMouse
                                        anchors.fill: parent
                                        hoverEnabled: true

                                        onClicked: {
                                            appMenu.visible = false

                                            if (modelData.action === "power") {
                                                powerMenu.visible = true
                                            } else {
                                                Quickshell.execDetached(modelData.cmd)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

}
}
