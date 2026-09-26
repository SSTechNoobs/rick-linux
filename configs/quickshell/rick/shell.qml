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
        windows: [appMenu, powerMenu]

        onCleared: {
            powerMenu.visible = false
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

    property var taskbarPins: []

    function refreshTaskbarPins() {
        taskbarPinsProc.running = false

        Qt.callLater(function() {
            taskbarPinsProc.running = true
        })
    }

    Process {
        id: taskbarPinsProc

        command: [
            "/home/rick/.local/bin/rick-taskbar-pins",
            "list"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var pins = []
                var output = this.text.trim()

                if (output.length > 0) {
                    var lines = output.split("\n")

                    for (var i = 0; i < lines.length; ++i) {
                        var parts = lines[i].split("|")

                        if (parts.length >= 4) {
                            pins.push({
                                key: parts[0],
                                name: parts[1],
                                icon: parts[2],
                                size: parseInt(parts[3])
                            })
                        }
                    }
                }

                root.taskbarPins = pins
            }
        }
    }

    property string btStatus: "..."
    property string volumeStatus: "..."
    property string weatherStatus: "Weather..."
    property string forecastStatus: "Loading forecast..."
    property var weatherData: ({})

    // Aether global-theme colors.
    property string themeBackground: "#041E42"
    property string themeForeground: "#FFFFFF"
    property string themeAccent: "#003594"
    property string themeMuted: "#869397"
    property string themeSurface: "#0C2340"
    property string themeBright: "#DDF8FF"

    Process {
        id: aetherBarColorProc

        command: [
            "/home/rick/.local/bin/rick-aether-colors"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("|")

                if (parts.length >= 6) {
                    root.themeBackground = parts[0]
                    root.themeForeground = parts[1]
                    root.themeAccent = parts[2]
                    root.themeMuted = parts[3]
                    root.themeSurface = parts[4]
                    root.themeBright = parts[5]
                }
            }
        }
    }

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

                if (value.length) {
                    try {
                        root.weatherData = JSON.parse(value)
                        root.forecastStatus = "Weather updated"
                    } catch (e) {
                        root.forecastStatus = "Weather error"
                        console.log("Weather JSON error:", e)
                    }
                }
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


        PopupWindow {
            id: powerMenu

            anchor.window: bar
            anchor.rect.x: 10
            anchor.rect.y: -height

            width: 170
            height: 132
            visible: false
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: root.themeSurface
                border.color: root.themeMuted
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

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
                                Quickshell.execDetached(["/home/rick/.local/bin/rick-logout"])
                            }
                        }
                    }
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
                }
            }
        }

        Item {
            id: ricksLabel

            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            width: 52
            height: 38

            Image {
                anchors.centerIn: parent

                width: 48
                height: 36

                source: "file:///home/rick/.config/quickshell/rick/icons/cowboys-helmet.png"
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: appMenu.visible = !appMenu.visible
            }
        }

        Row {
            id: pinnedAppsRow

            anchors.left: ricksLabel.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            spacing: 6

            Repeater {
                model: root.taskbarPins

                delegate: Rectangle {
                    required property var modelData

                    width: 42
                    height: 32
                    radius: 8

                    color: pinMouse.containsMouse
                        ? Qt.rgba(0.53, 0.58, 0.59, 0.20)
                        : "transparent"

                    Image {
                        anchors.centerIn: parent

                        width: modelData.size
                        height: modelData.size

                        source: modelData.icon.length > 0
                      ? (modelData.icon.startsWith("/")
                          ? "file://" + modelData.icon
                          : modelData.icon)
                      : ""

                        fillMode: Image.PreserveAspectFit
                    }

                    MouseArea {
                        id: pinMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            Quickshell.execDetached([
                                "/home/rick/.local/bin/rick-taskbar-pins",
                                "run",
                                modelData.key
                            ])
                        }
                    }
                }
            }
        }

        Text {
            id: hyprLabel
            anchors.centerIn: parent
            text: "Hyprland"
            color: root.themeMuted
            font.pixelSize: 14
        }

        Text {
            id: weatherLabel
            anchors.left: hyprLabel.right
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.weatherStatus
            color: root.themeForeground
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

            implicitWidth: 920
            implicitHeight: 620
            visible: false
            color: "transparent"
            Rectangle {
                id: weatherCard
                anchors.fill: parent
                radius: 24
                clip: true

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: "#E82B6F98"
                    }

                    GradientStop {
                        position: 0.55
                        color: "#E818507A"
                    }

                    GradientStop {
                        position: 1.0
                        color: "#E80A2944"
                    }
                }

                border.color: "#D0EFFFFF"
                border.width: 1

                Rectangle {
                    anchors.fill: parent
                    radius: 24
                    color: "transparent"
                    border.color: "#66FFFFFF"
                    border.width: 1
                    opacity: 0.35
                }

                function iconFor(condition) {
                    if (condition === "Clear")
                        return "☀"

                    if (condition === "Mostly Clear" ||
                        condition === "Partly Cloudy")
                        return "☀"

                    if (condition === "Cloudy")
                        return "☁"

                    if (condition === "Fog")
                        return "≋"

                    if (condition === "Drizzle" ||
                        condition === "Rain" ||
                        condition === "Showers")
                        return "☂"

                    if (condition === "Snow")
                        return "❄"

                    if (condition === "Storm")
                        return "⚡"

                    return "☁"
                }

                function iconFile(condition) {
                    if (condition === "Clear" ||
                        condition === "Mostly Clear" ||
                        condition === "Partly Cloudy")
                        return "file:///home/rick/.config/quickshell/rick/weather-icons/sunny.svg"

                    if (condition === "Rain" ||
                        condition === "Drizzle" ||
                        condition === "Showers")
                        return "file:///home/rick/.config/quickshell/rick/weather-icons/rain.svg"

                    return "file:///home/rick/.config/quickshell/rick/weather-icons/cloudy.svg"
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    Column {
                        width: 590
                        spacing: 12

                        Rectangle {
                            width: 590
                            height: 125
                            radius: 19
                            color: "#B8457395"
                            border.color: "#508EB7CE"
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 18

                                Image {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 62
                                    height: 62

                                    source: weatherCard.iconFile(
                                        root.weatherData.current
                                            ? root.weatherData.current.condition
                                            : ""
                                    )

                                    fillMode: Image.PreserveAspectFit
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter

                                    text: root.weatherData.current
                                        ? root.weatherData.current.temperature + "°"
                                        : "--°"

                                    color: root.themeForeground
                                    font.pixelSize: 66
                                    font.bold: true
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Text {
                                        text: root.weatherData.location
                                            || "Cedar Falls, Iowa"

                                        color: root.themeForeground
                                        font.pixelSize: 21
                                        font.bold: true
                                    }

                                    Text {
                                        text: root.weatherData.current
                                            ? root.weatherData.current.condition
                                            : "Loading..."

                                        color: root.themeForeground
                                        font.pixelSize: 18
                                        font.bold: true
                                    }

                                    Text {
                                        text: root.weatherData.current
                                            ? "Feels like "
                                              + root.weatherData.current.feels
                                              + "°"
                                            : ""

                                        color: root.themeBright
                                        font.pixelSize: 14
                                    }
                                }
                            }
                        }

                        Text {
                            text: "Hourly Forecast"
                            color: root.themeForeground
                            font.pixelSize: 17
                            font.bold: true
                        }

                        Rectangle {
                            width: 590
                            height: 160
                            radius: 19
                            color: "#B83A5E7D"
                            border.color: "#457FA8C0"

                            Row {
                                anchors.centerIn: parent
                                spacing: 8

                                Repeater {
                                    model: root.weatherData.hourly
                                        ? root.weatherData.hourly.slice(0, 6)
                                        : []

                                    delegate: Rectangle {
                                        width: 86
                                        height: 132
                                        radius: 16
                                        color: "#587EA4B2"
                                        border.color: "#729DC0D2"

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 5

                                            Text {
                                                anchors.horizontalCenter:
                                                    parent.horizontalCenter

                                                text: Qt.formatDateTime(
                                                    new Date(modelData.time),
                                                    "h AP"
                                                )

                                                color: root.themeBright
                                                font.pixelSize: 12
                                            }

                                            Image {
                                                anchors.horizontalCenter:
                                                    parent.horizontalCenter

                                                width: 32
                                                height: 32

                                                source: weatherCard.iconFile(
                                                    modelData.condition
                                                )

                                                fillMode: Image.PreserveAspectFit
                                            }

                                            Text {
                                                anchors.horizontalCenter:
                                                    parent.horizontalCenter

                                                text: modelData.temp + "°"
                                                color: root.themeForeground
                                                font.pixelSize: 20
                                                font.bold: true
                                            }

                                            Text {
                                                anchors.horizontalCenter:
                                                    parent.horizontalCenter

                                                text: "Rain " + modelData.rain + "%"
                                                color: root.themeBright
                                                font.pixelSize: 10
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            spacing: 10

                            Rectangle {
                                width: 190
                                height: 92
                                radius: 17
                                color: "#B84A7694"
                                border.color: "#497E9EB0"

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        anchors.horizontalCenter:
                                            parent.horizontalCenter
                                        text: "Humidity"
                                        color: root.themeBright
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        anchors.horizontalCenter:
                                            parent.horizontalCenter

                                        text: root.weatherData.current
                                            ? "💧 "
                                              + root.weatherData.current.humidity
                                              + "%"
                                            : "--"

                                        color: root.themeForeground
                                        font.pixelSize: 21
                                        font.bold: true
                                    }
                                }
                            }

                            Rectangle {
                                width: 190
                                height: 92
                                radius: 17
                                color: "#B84A7694"
                                border.color: "#497E9EB0"

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        anchors.horizontalCenter:
                                            parent.horizontalCenter
                                        text: "Wind"
                                        color: root.themeBright
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        anchors.horizontalCenter:
                                            parent.horizontalCenter

                                        text: root.weatherData.current
                                            ? root.weatherData.current.wind
                                              + " mph"
                                            : "--"

                                        color: root.themeForeground
                                        font.pixelSize: 21
                                        font.bold: true
                                    }
                                }
                            }

                            Rectangle {
                                width: 190
                                height: 92
                                radius: 17
                                color: "#B84A7694"
                                border.color: "#497E9EB0"

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        anchors.horizontalCenter:
                                            parent.horizontalCenter
                                        text: "Rain Chance"
                                        color: root.themeBright
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        anchors.horizontalCenter:
                                            parent.horizontalCenter

                                        text: root.weatherData.daily
                                            && root.weatherData.daily.length
                                            ? root.weatherData.daily[0].rain
                                              + "%"
                                            : "--"

                                        color: root.themeForeground
                                        font.pixelSize: 21
                                        font.bold: true
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 590
                            height: 83
                            radius: 17
                            color: "#B84A7694"
                            border.color: "#497E9EB0"

                            Row {
                                anchors.centerIn: parent
                                spacing: 95

                                Column {
                                    spacing: 4

                                    Text {
                                        text: "☀  Sunrise"
                                        color: "#FFD86B"
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        text: root.weatherData.sun
                                            ? Qt.formatDateTime(
                                                new Date(
                                                    root.weatherData.sun.sunrise
                                                ),
                                                "h:mm AP"
                                              )
                                            : "--"

                                        color: root.themeForeground
                                        font.pixelSize: 18
                                        font.bold: true
                                    }
                                }

                                Column {
                                    spacing: 4

                                    Text {
                                        text: "☀  Sunset"
                                        color: "#FFB66B"
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        text: root.weatherData.sun
                                            ? Qt.formatDateTime(
                                                new Date(
                                                    root.weatherData.sun.sunset
                                                ),
                                                "h:mm AP"
                                              )
                                            : "--"

                                        color: root.themeForeground
                                        font.pixelSize: 18
                                        font.bold: true
                                    }
                                }

                                Column {
                                    spacing: 4

                                    Text {
                                        text: "Today"
                                        color: root.themeBright
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        text: root.weatherData.daily
                                            && root.weatherData.daily.length
                                            ? root.weatherData.daily[0].high
                                              + "° / "
                                              + root.weatherData.daily[0].low
                                              + "°"
                                            : "--"

                                        color: root.themeForeground
                                        font.pixelSize: 18
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: 280
                        spacing: 10

                        Rectangle {
                            width: 280
                            height: 52
                            radius: 17
                            color: "#B8457395"
                            border.color: "#508EB7CE"

                            Text {
                                anchors.centerIn: parent
                                text: "10-Day Forecast"
                                color: root.themeForeground
                                font.pixelSize: 18
                                font.bold: true
                            }
                        }

                        Rectangle {
                            width: 280
                            height: 522
                            radius: 19
                            color: "#B83A5E7D"
                            border.color: "#457FA8C0"

                            Column {
                                anchors.fill: parent
                                anchors.margins: 9
                                spacing: 4

                                Repeater {
                                    model: root.weatherData.daily
                                        ? root.weatherData.daily.slice(0, 10)
                                        : []

                                    delegate: Rectangle {
                                        width: 262
                                        height: 46
                                        radius: 12
                                        color: index % 2 === 0
                                            ? "#405F7E82"
                                            : "#304D6A72"

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 9
                                            anchors.rightMargin: 9
                                            spacing: 7

                                            Text {
                                                width: 72
                                                anchors.verticalCenter:
                                                    parent.verticalCenter

                                                text: Qt.formatDateTime(
                                                    new Date(
                                                        modelData.date
                                                        + "T12:00:00"
                                                    ),
                                                    index === 0
                                                        ? "'Today'"
                                                        : "ddd M/d"
                                                )

                                                color: root.themeForeground
                                                font.pixelSize: 12
                                                font.bold: index === 0
                                            }

                                            Image {
                                                width: 30
                                                height: 30
                                                anchors.verticalCenter:
                                                    parent.verticalCenter

                                                source: weatherCard.iconFile(
                                                    modelData.condition
                                                )

                                                fillMode: Image.PreserveAspectFit
                                            }

                                            Text {
                                                width: 54
                                                anchors.verticalCenter:
                                                    parent.verticalCenter

                                                text: modelData.high + "°"
                                                color: root.themeForeground
                                                font.pixelSize: 14
                                                font.bold: true
                                            }

                                            Text {
                                                width: 48
                                                anchors.verticalCenter:
                                                    parent.verticalCenter

                                                text: modelData.low + "°"
                                                color: root.themeMuted
                                                font.pixelSize: 14
                                            }

                                            Text {
                                                anchors.verticalCenter:
                                                    parent.verticalCenter

                                                text: modelData.rain + "%"
                                                color: "#9EE1FF"
                                                font.pixelSize: 11
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
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
                color: root.themeForeground
                font.pixelSize: 14
            
                MouseArea {
                    id: dateHover
                    anchors.fill: parent
                    hoverEnabled: true

                    onEntered: dateCalendar.visible = true
                    onExited: calendarHideTimer.restart()
                }
}

            Process {
                id: updateCountProc

                command: [
                    "bash",
                    "-lc",
                    "{ checkupdates 2>/dev/null || true; yay -Qua 2>/dev/null || true; } | sed '/^$/d' | wc -l"
                ]

                running: true

                stdout: StdioCollector {
                    onStreamFinished: {
                        var n = parseInt(this.text.trim())
                        updateButton.updateCount = isNaN(n) ? 0 : n
                    }
                }
            }

            Timer {
                id: updateCheckTimer
                interval: 60000
                running: true
                repeat: true

                onTriggered: {
                    if (!updateCountProc.running)
                        updateCountProc.running = true
                }
            }

            Timer {
                id: updateAfterClickTimer
                interval: 120000
                repeat: false

                onTriggered: {
                    if (!updateCountProc.running)
                        updateCountProc.running = true
                }
            }

            Rectangle {
                id: updateButton

                property int updateCount: 0

                width: updateCount > 0 ? 48 : 34
                height: 32
                radius: 8
                color: updateMouse.containsMouse ? "#25364d" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: updateButton.updateCount > 0
                          ? "⬆ " + updateButton.updateCount
                          : "⬆"
                    color: updateButton.updateCount > 0 ? root.themeForeground : root.themeMuted
                    font.pixelSize: 14
                    font.bold: updateButton.updateCount > 0
                }

                MouseArea {
                    id: updateMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        Quickshell.execDetached([
                            "ghostty",
                            "-e",
                            "bash",
                            "-lc",
                            "yay -Syu; rc=$?; echo; if [ $rc -eq 0 ]; then echo 'Updates finished.'; else echo 'Update returned an error.'; fi; echo; echo 'This window will close in 5 seconds...'; sleep 5; exit $rc"
                        ])

                        updateAfterClickTimer.restart()
                    }
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
                    color: root.themeSurface
                    border.color: root.themeMuted
                    border.width: 1

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
                            color: root.themeForeground
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.themeMuted
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
                                    color: root.themeMuted
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
                                        ? root.themeAccent
                                        : "transparent"

                                    Text {
                                        anchors.centerIn: parent

                                        text:
                                            parent.dayNumber > 0
                                            && parent.dayNumber <= dateCalendar.daysInMonth
                                            ? parent.dayNumber
                                            : ""

                                        color: root.themeForeground
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
    

        RickAboutPopup {
            id: aboutPopup
            barWindow: bar
        }

        RickLauncherPopup {
            id: appMenu

            barWindow: bar
            aboutPopupWindow: aboutPopup
            powerMenuWindow: powerMenu
            shellRoot: root

            onVisibleChanged: {
                if (visible) {
                    Qt.callLater(function() {
                        appMenuGrab.active = true
                    })
                } else {
                    appMenuGrab.active = false
                }
            }
        }

}
}
