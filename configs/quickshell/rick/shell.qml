//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Hyprland
import QtQuick

ShellRoot {
    id: root

    HyprlandFocusGrab {
        id: powerMenuGrab
        windows: [appMenu, powerMenu]

        onCleared: {
            powerMenu.visible = false
        }
    }

    HyprlandFocusGrab {
        id: appMenuGrab
        windows: [appMenu, powerMenu]

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

    HyprlandFocusGrab {
        id: aboutGrab
        windows: [aboutPopup]

        onCleared: {
            aboutPopup.visible = false
        }
    }

    IpcHandler {
        target: "rickabout"

        function toggle(): void {
            aboutPopup.visible = !aboutPopup.visible
        }

        function open(): void {
            aboutPopup.visible = true
        }

        function close(): void {
            aboutPopup.visible = false
        }
    }

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

        running: false

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

    property var installedApps: []

    function isPinned(key) {
        for (var i = 0; i < taskbarPins.length; ++i) {
            if (taskbarPins[i].key === key)
                return true
        }

        return false
    }

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

        running: false

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
                                icon: parts[3]
                            })
                        }
                    }
                }

                root.installedApps = apps
            }
        }
    }

    property string netStatus: "Checking..."
    property string btStatus: "..."
    property string volumeStatus: "..."
    property string weatherStatus: "Weather..."
    property string forecastStatus: "Loading forecast..."
    property var weatherData: ({})
    property var aboutData: ({})

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Process {
        id: aboutProc
        command: ["/home/rick/.local/bin/rick-about-data"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.aboutData = JSON.parse(this.text)
                } catch (e) {
                    console.log("Could not parse About data: " + e)
                }
            }
        }
    }

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE device | awk -F: '$2==\"connected\" { if ($1==\"ethernet\") {print \"Ethernet\"; exit} if ($1==\"wifi\") {print \"Wi-Fi\"; exit} }'"]
        running: false

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
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.btStatus = this.text.trim()
        }
    }

    Process {
        id: volumeProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf \"%.0f%%\", $2*100; if (index($0,\"MUTED\")) printf \" muted\"}'"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.volumeStatus = this.text.trim()
        }
    }



    Process {
        id: forecastProc
        command: ["/home/rick/.local/bin/rick-weather-detail"]
        running: false

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

    // Draw the bar first, then start background data.
    Timer {
        id: taskbarStartupTimer
        interval: 50
        running: true
        repeat: false

        onTriggered: {
            if (!taskbarPinsProc.running)
                taskbarPinsProc.running = true
        }
    }

    Timer {
        id: desktopStatusStartupTimer
        interval: 500
        running: true
        repeat: false

        onTriggered: {
            if (!netProc.running)
                netProc.running = true
            if (!btProc.running)
                btProc.running = true
            if (!volumeProc.running)
                volumeProc.running = true
        }
    }

    Timer {
        id: weatherStartupTimer
        interval: 1500
        running: true
        repeat: false

        onTriggered: {
            if (!forecastProc.running)
                forecastProc.running = true
            if (!weatherProc.running)
                weatherProc.running = true
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
        running: false

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

            // Place submenu just to the right of the main menu.
            anchor.rect.x: appMenu.anchor.rect.x + appMenu.width + 8
            anchor.rect.y: -260

            width: 170
            height: 132
            visible: false
            color: "transparent"

            onVisibleChanged: {
                if (visible) {
                    Qt.callLater(function() {
                        powerMenuGrab.active = true
                    })
                } else {
                    powerMenuGrab.active = false
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 10

                color: "#071426"
                border.color: "#A855F7"
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    Rectangle {
                        width: 154
                        height: 35
                        radius: 6

                        color: rebootMouse.containsMouse
                            ? "#003594"
                            : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "Reboot"
                            color: "#35D9FF"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        MouseArea {
                            id: rebootMouse
                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: {
                                powerMenu.visible = false
                                appMenu.visible = false
                                Quickshell.execDetached([
                                    "systemctl",
                                    "reboot"
                                ])
                            }
                        }
                    }

                    Rectangle {
                        width: 154
                        height: 35
                        radius: 6

                        color: poweroffMouse.containsMouse
                            ? "#003594"
                            : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "Power Off"
                            color: "#FF4FA3"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        MouseArea {
                            id: poweroffMouse
                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: {
                                powerMenu.visible = false
                                appMenu.visible = false
                                Quickshell.execDetached([
                                    "systemctl",
                                    "poweroff"
                                ])
                            }
                        }
                    }

                    Rectangle {
                        width: 154
                        height: 35
                        radius: 6

                        color: logoutMouse.containsMouse
                            ? "#003594"
                            : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "Log Out"
                            color: "#FFFFFF"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        MouseArea {
                            id: logoutMouse
                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: {
                                powerMenu.visible = false
                                appMenu.visible = false
                                Quickshell.execDetached([
                                    "/home/rick/.local/bin/rick-logout"
                                ])
                            }
                        }
                    }
                }
            }
        }

        Image {
            id: ricksLabel
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            width: 30
            height: 30
            source: "file:///home/rick/.config/quickshell/rick/icons/arch-bar.svg"
            fillMode: Image.PreserveAspectFit
            smooth: true

            MouseArea {
                anchors.fill: parent
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
                        ? "#25364d"
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
                        smooth: true
                    }

                    Process {
                        id: taskbarRemoveProc
                        running: false

                        onExited: {
                            root.refreshTaskbarPins()
                        }
                    }

                    MouseArea {
                        id: pinMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        acceptedButtons:
                            Qt.LeftButton |
                            Qt.RightButton

                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton) {
                                taskbarContextMenu.visible =
                                    !taskbarContextMenu.visible
                            } else {
                                taskbarContextMenu.visible = false

                                Quickshell.execDetached([
                                    "/home/rick/.local/bin/rick-taskbar-pins",
                                    "run",
                                    modelData.key
                                ])
                            }
                        }
                    }

                    PopupWindow {
                        id: taskbarContextMenu

                        anchor.window: bar
                        anchor.rect.x:
                            pinnedAppsRow.x + parent.x - 54
                        anchor.rect.y: -implicitHeight - 4

                        implicitWidth: 150
                        implicitHeight: 34

                        visible: false
                        color: "transparent"

                        Rectangle {
                            anchors.fill: parent
                            radius: 8

                            color: "#041E42"
                            border.color: "#869397"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent

                                text: "Remove from Taskbar"
                                color: "#FFFFFF"
                                font.pixelSize: 10
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent

                                onClicked: {
                                    taskbarRemoveProc.command = [
                                        "/home/rick/.local/bin/rick-taskbar-pins",
                                        "remove",
                                        modelData.key
                                    ]

                                    taskbarContextMenu.visible = false
                                    taskbarRemoveProc.running = true
                                }
                            }
                        }
                    }
                }
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
                    weatherPopup.pinned = false
                    weatherPopup.visible = false

                    Quickshell.execDetached([
                        "/home/rick/.local/bin/rick-weather-app"
                    ])
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

            implicitWidth: 960
            implicitHeight: 650
            visible: false
            color: "transparent"

            Rectangle {
                id: weatherCard
                anchors.fill: parent
                radius: 30
                clip: true

                function skyTop(condition) {
                    if (condition === "Clear" || condition === "Mostly Clear")
                        return "#4C8FD9"

                    if (condition === "Rain" ||
                        condition === "Drizzle" ||
                        condition === "Showers")
                        return "#526B84"

                    if (condition === "Storm")
                        return "#3E506B"

                    if (condition === "Snow")
                        return "#8DAABD"

                    if (condition === "Fog")
                        return "#6F8291"

                    return "#6689B7"
                }

                function skyBottom(condition) {
                    if (condition === "Clear" || condition === "Mostly Clear")
                        return "#7CB7EA"

                    if (condition === "Rain" ||
                        condition === "Drizzle" ||
                        condition === "Showers")
                        return "#71879A"

                    if (condition === "Storm")
                        return "#5B6880"

                    if (condition === "Snow")
                        return "#B7CBD8"

                    if (condition === "Fog")
                        return "#95A5B1"

                    return "#8AA7C8"
                }

                function iconFile(condition) {
                    if (condition === "Clear" ||
                        condition === "Mostly Clear" ||
                        condition === "Partly Cloudy")
                        return "file:///home/rick/.config/quickshell/rick/weather-icons/sunny.svg"

                    if (condition === "Rain" ||
                        condition === "Drizzle" ||
                        condition === "Showers" ||
                        condition === "Storm")
                        return "file:///home/rick/.config/quickshell/rick/weather-icons/rain.svg"

                    return "file:///home/rick/.config/quickshell/rick/weather-icons/cloudy.svg"
                }

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: weatherCard.skyTop(
                            root.weatherData.current
                                ? root.weatherData.current.condition
                                : ""
                        )
                    }

                    GradientStop {
                        position: 1.0
                        color: weatherCard.skyBottom(
                            root.weatherData.current
                                ? root.weatherData.current.condition
                                : ""
                        )
                    }
                }

                border.color: "#55FFFFFF"
                border.width: 1

                Rectangle {
                    anchors.fill: parent
                    radius: 30
                    color: "#16000000"
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    Column {
                        width: 620
                        spacing: 12

                        Rectangle {
                            width: 620
                            height: 176
                            radius: 28
                            color: "#20FFFFFF"
                            border.color: "#35FFFFFF"
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 18

                                Column {
                                    width: 250
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 5

                                    Text {
                                        text: root.weatherData.location
                                            || "Cedar Falls, Iowa"
                                        color: "#FFFFFF"
                                        font.pixelSize: 25
                                        font.bold: true
                                    }

                                    Text {
                                        text: Qt.formatDateTime(
                                            new Date(),
                                            "dddd, MMMM d"
                                        )
                                        color: "#E8F4FF"
                                        font.pixelSize: 14
                                    }

                                    Item {
                                        width: 1
                                        height: 6
                                    }

                                    Text {
                                        text: root.weatherData.current
                                            ? root.weatherData.current.condition
                                            : "Loading..."
                                        color: "#FFFFFF"
                                        font.pixelSize: 21
                                        font.bold: true
                                    }

                                    Text {
                                        text: root.weatherData.daily
                                            && root.weatherData.daily.length
                                            ? "H "
                                              + root.weatherData.daily[0].high
                                              + "°   L "
                                              + root.weatherData.daily[0].low
                                              + "°"
                                            : ""
                                        color: "#E7F3FC"
                                        font.pixelSize: 15
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.weatherData.current
                                        ? root.weatherData.current.temperature + "°"
                                        : "--°"
                                    color: "#FFFFFF"
                                    font.pixelSize: 78
                                    font.bold: true
                                }

                                Image {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 100
                                    height: 100
                                    source: weatherCard.iconFile(
                                        root.weatherData.current
                                            ? root.weatherData.current.condition
                                            : ""
                                    )
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }
                            }
                        }

                        Text {
                            text: "Hourly forecast"
                            color: "#FFFFFF"
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Rectangle {
                            width: 620
                            height: 150
                            radius: 24
                            color: "#1CFFFFFF"
                            border.color: "#30FFFFFF"
                            border.width: 1

                            Row {
                                anchors.centerIn: parent
                                spacing: 8

                                Repeater {
                                    model: root.weatherData.hourly
                                        ? root.weatherData.hourly.slice(0, 6)
                                        : []

                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index

                                        width: 92
                                        height: 126
                                        radius: 22
                                        color: index === 0
                                            ? "#30FFFFFF"
                                            : "#16FFFFFF"

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 5

                                            Text {
                                                anchors.horizontalCenter:
                                                    parent.horizontalCenter
                                                text: index === 0
                                                    ? "Now"
                                                    : Qt.formatDateTime(
                                                        new Date(modelData.time),
                                                        "h AP"
                                                      )
                                                color: "#F4FAFF"
                                                font.pixelSize: 12
                                                font.bold: index === 0
                                            }

                                            Image {
                                                anchors.horizontalCenter:
                                                    parent.horizontalCenter
                                                width: 36
                                                height: 36
                                                source: weatherCard.iconFile(
                                                    modelData.condition
                                                )
                                                fillMode: Image.PreserveAspectFit
                                            }

                                            Text {
                                                anchors.horizontalCenter:
                                                    parent.horizontalCenter
                                                text: modelData.temp + "°"
                                                color: "#FFFFFF"
                                                font.pixelSize: 21
                                                font.bold: true
                                            }

                                            Text {
                                                anchors.horizontalCenter:
                                                    parent.horizontalCenter
                                                text: modelData.rain + "%"
                                                color: "#D8F2FF"
                                                font.pixelSize: 10
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            text: "Current conditions"
                            color: "#FFFFFF"
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Row {
                            spacing: 10

                            Repeater {
                                model: [
                                    {
                                        label: "Feels like",
                                        value: root.weatherData.current
                                            ? root.weatherData.current.feels + "°"
                                            : "--"
                                    },
                                    {
                                        label: "Humidity",
                                        value: root.weatherData.current
                                            ? root.weatherData.current.humidity + "%"
                                            : "--"
                                    },
                                    {
                                        label: "Wind",
                                        value: root.weatherData.current
                                            ? root.weatherData.current.wind + " mph"
                                            : "--"
                                    },
                                    {
                                        label: "Rain",
                                        value: root.weatherData.daily
                                            && root.weatherData.daily.length
                                            ? root.weatherData.daily[0].rain + "%"
                                            : "--"
                                    }
                                ]

                                delegate: Rectangle {
                                    required property var modelData

                                    width: 147
                                    height: 94
                                    radius: 22
                                    color: "#1CFFFFFF"
                                    border.color: "#2FFFFFFF"

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            anchors.horizontalCenter:
                                                parent.horizontalCenter
                                            text: modelData.label
                                            color: "#E3F1FA"
                                            font.pixelSize: 12
                                        }

                                        Text {
                                            anchors.horizontalCenter:
                                                parent.horizontalCenter
                                            text: modelData.value
                                            color: "#FFFFFF"
                                            font.pixelSize: 22
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 620
                            height: 72
                            radius: 22
                            color: "#1AFFFFFF"
                            border.color: "#2FFFFFFF"

                            Row {
                                anchors.centerIn: parent
                                spacing: 72

                                Column {
                                    spacing: 3

                                    Text {
                                        text: "Sunrise"
                                        color: "#E3F1FA"
                                        font.pixelSize: 12
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
                                        color: "#FFFFFF"
                                        font.pixelSize: 17
                                        font.bold: true
                                    }
                                }

                                Column {
                                    spacing: 3

                                    Text {
                                        text: "Sunset"
                                        color: "#E3F1FA"
                                        font.pixelSize: 12
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
                                        color: "#FFFFFF"
                                        font.pixelSize: 17
                                        font.bold: true
                                    }
                                }

                                Column {
                                    spacing: 3

                                    Text {
                                        text: "Today"
                                        color: "#E3F1FA"
                                        font.pixelSize: 12
                                    }

                                    Text {
                                        text: root.weatherData.daily
                                            && root.weatherData.daily.length
                                            ? root.weatherData.daily[0].high
                                              + "° / "
                                              + root.weatherData.daily[0].low
                                              + "°"
                                            : "--"
                                        color: "#FFFFFF"
                                        font.pixelSize: 17
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: 284
                        spacing: 12

                        Text {
                            text: "10-day forecast"
                            color: "#FFFFFF"
                            font.pixelSize: 20
                            font.bold: true
                        }

                        Rectangle {
                            width: 284
                            height: 574
                            radius: 26
                            color: "#1CFFFFFF"
                            border.color: "#30FFFFFF"
                            border.width: 1

                            Column {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                Repeater {
                                    model: root.weatherData.daily
                                        ? root.weatherData.daily.slice(0, 10)
                                        : []

                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index

                                        width: 264
                                        height: 50
                                        radius: 15
                                        color: index === 0
                                            ? "#2AFFFFFF"
                                            : "transparent"

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 7

                                            Text {
                                                width: 74
                                                anchors.verticalCenter:
                                                    parent.verticalCenter
                                                text: index === 0
                                                    ? "Today"
                                                    : Qt.formatDateTime(
                                                        new Date(
                                                            modelData.date
                                                            + "T12:00:00"
                                                        ),
                                                        "ddd"
                                                      )
                                                color: "#FFFFFF"
                                                font.pixelSize: 13
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
                                                width: 38
                                                anchors.verticalCenter:
                                                    parent.verticalCenter
                                                text: modelData.rain + "%"
                                                color: "#D9F3FF"
                                                font.pixelSize: 11
                                            }

                                            Text {
                                                width: 42
                                                anchors.verticalCenter:
                                                    parent.verticalCenter
                                                horizontalAlignment:
                                                    Text.AlignRight
                                                text: modelData.low + "°"
                                                color: "#D9E6EF"
                                                font.pixelSize: 14
                                            }

                                            Text {
                                                anchors.verticalCenter:
                                                    parent.verticalCenter
                                                text: modelData.high + "°"
                                                color: "#FFFFFF"
                                                font.pixelSize: 15
                                                font.bold: true
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

            Process {
                id: updateCountProc

                command: [
                    "bash",
                    "-lc",
                    "$HOME/.local/bin/rick-update-count"
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
                    color: updateButton.updateCount > 0 ? "#ffffff" : "#869397"
                    font.pixelSize: 14
                    font.bold: updateButton.updateCount > 0
                }

                MouseArea {
                    id: updateMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        Quickshell.execDetached([
                            "xfce4-terminal",
                            "--hide-scrollbar",
                            "-x",
                            "bash",
                            "-lc",
                            "$HOME/.local/bin/rick-update-install; rc=$?; echo; if [ $rc -eq 0 ]; then echo 'Updates finished.'; else echo 'Update returned an error.'; fi; echo; echo 'This window will close in 5 seconds...'; sleep 5; exit $rc"
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
                    color: "#0C2340"
                    border.color: "#869397"
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
                    root.refreshInstalledApps()

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
                clip: true
                color: "#0C2340"

                border.color: "#869397"
                border.width: 1

                Image {
                    anchors.fill: parent

                    source: "file:///home/rick/.config/quickshell/rick/wallpapers/menu-wallpaper.png"

                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    opacity: 0.72
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0.01, 0.05, 0.12, 0.42)
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Text {
                        width: parent.width
                        text: "RASPBERRY PI HYPRLAND ARM64"
                        color: "#35D9FF"
                        font.pixelSize: 20
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        width: parent.width
                        text: "Raspberry Pi 5 Edition"
                        color: "#FF4FA3"
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Rectangle {
                        width: parent.width
                        height: 2
                        radius: 1
                        color: "#A855F7"
                    }

                    Row {
                        spacing: 12

                        Column {
                            width: 236
                            spacing: 5

                            Text {
                                text: "APPS"
                                color: "#35D9FF"
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Flickable {
                                width: 236
                                height: 430

                                clip: true
                                contentWidth: width
                                contentHeight: appsColumn.height

                                boundsBehavior: Flickable.StopAtBounds

                                Column {
                                    id: appsColumn

                                    width: 236
                                    spacing: 5

                                    Repeater {
                                        model: root.installedApps

                                        delegate: Rectangle {
                                            required property var modelData

                                            width: 236
                                            height: 42
                                            radius: 7

                                            color: appMouse.containsMouse
                                                ? "#003594"
                                                : "#111827"

                                            Row {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                spacing: 8

                                                Item {
                                                    width: 26
                                                    height: 42

                                                    Image {
                                                        anchors.centerIn: parent

                                                        width: 22
                                                        height: 22

                                                        visible:
                                                            modelData.icon.length > 0

                                                        source:
                                                            modelData.icon.length > 0
                                                            ? (modelData.icon.startsWith("/")
                                                                ? "file://" + modelData.icon
                                                                : modelData.icon)
                                                            : ""

                                                        fillMode:
                                                            Image.PreserveAspectFit

                                                        smooth: true
                                                    }

                                                    Text {
                                                        anchors.centerIn: parent

                                                        visible:
                                                            modelData.icon.length === 0

                                                        text:
                                                            modelData.name.length > 0
                                                            ? modelData.name.charAt(0)
                                                            : "•"

                                                        color: "#869397"
                                                        font.pixelSize: 16
                                                        font.bold: true
                                                    }
                                                }

                                                Text {
                                                    anchors.verticalCenter:
                                                        parent.verticalCenter

                                                    width: 175

                                                    text: modelData.name
                                                    color: "#FFFFFF"
                                                    font.pixelSize: 13

                                                    elide:
                                                        Text.ElideRight
                                                }
                                            }

                                            Process {
                                                id: pinToggleProc
                                                running: false

                                                onExited: {
                                                    root.refreshTaskbarPins()
                                                }
                                            }

                                            MouseArea {
                                                id: appMouse

                                                anchors.fill: parent
                                                hoverEnabled: true

                                                acceptedButtons:
                                                    Qt.LeftButton |
                                                    Qt.RightButton

                                                onClicked: function(mouse) {
                                                    if (mouse.button ===
                                                        Qt.RightButton) {
                                                        pinContextMenu.visible =
                                                            !pinContextMenu.visible
                                                    } else {
                                                        pinContextMenu.visible = false
                                                        appMenu.visible = false

                                                        Quickshell.execDetached([
                                                            "/home/rick/.local/bin/rick-apps",
                                                            "launch",
                                                            modelData.key
                                                        ])
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                id: pinContextMenu

                                                anchors.right: parent.right
                                                anchors.rightMargin: 5
                                                anchors.verticalCenter:
                                                    parent.verticalCenter

                                                width: 145
                                                height: 34
                                                radius: 8
                                                z: 100

                                                visible: false

                                                color: "#041E42"
                                                border.color: "#869397"
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent

                                                    text:
                                                        root.isPinned(modelData.key)
                                                        ? "Remove from Taskbar"
                                                        : "Pin to Taskbar"

                                                    color: "#FFFFFF"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }

                                                MouseArea {
                                                    anchors.fill: parent

                                                    onClicked: {
                                                        pinToggleProc.command = [
                                                            "/home/rick/.local/bin/rick-taskbar-pins",
                                                            root.isPinned(modelData.key)
                                                                ? "remove"
                                                                : "add",
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
                            }
                        }

                        Column {
                            width: 236
                            spacing: 5

                            Text {
                                text: "SYSTEM"
                                color: "#FF4FA3"
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Repeater {
                                model: [
                                    {
                                        icon: "file:///home/rick/.config/quickshell/rick/icons/system/about.svg",
                                        name: "About Ricks Linux",
                                        cmd: [
                                            "/home/rick/.local/bin/rick-about"
                                        ]
                                    },
                                    {
                                        icon: "file:///home/rick/.config/quickshell/rick/icons/system/bluetooth.svg",
                                        name: "Bluetooth",
                                        cmd: [
                                            "/home/rick/.local/bin/rick-bluetooth"
                                        ]
                                    },
                                    {
                                        icon: "file:///home/rick/.config/quickshell/rick/icons/system/network.svg",
                                        name: "Network",
                                        cmd: ["nm-connection-editor"]
                                    },
                                    {
                                        icon: "file:///home/rick/.config/quickshell/rick/icons/system/printer.svg",
                                        name: "Printer Settings",
                                        cmd: ["system-config-printer"]
                                    },
                                    {
                                        icon: "file:///home/rick/.config/quickshell/rick/icons/system/volume.svg",
                                        name: "Volume",
                                        cmd: [
                                            "/home/rick/.local/bin/rick-volume"
                                        ]
                                    },
                                    {
                                        icon: "file:///home/rick/.config/quickshell/rick/icons/system/power.svg",
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

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10

                                        Image {
                                            width: 22
                                            height: 22
                                            source: modelData.icon
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name
                                            color: "#FFFFFF"
                                            font.pixelSize: 14
                                        }
                                    }

                                    MouseArea {
                                        id: sysMouse
                                        anchors.fill: parent
                                        hoverEnabled: true

                                        onClicked: {
                                            if (modelData.action === "power") {
                                                powerMenu.visible =
                                                    !powerMenu.visible
                                            } else {
                                                powerMenu.visible = false
                                                appMenu.visible = false
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

    PopupWindow {
        id: aboutPopup

        anchor.window: bar
        anchor.rect.x: Math.max(20, (bar.width - width) / 2)
        anchor.rect.y: -height - 18

        width: Math.min(960, bar.width - 80)
        height: 800
        visible: false
        color: "transparent"

        property var hardwareRows: [
            { label: "Host:", key: "host" },
            { label: "CPU:", key: "cpu" },
            { label: "GPU:", key: "gpu" },
            { label: "Display:", key: "display" },
            { label: "Memory:", key: "memory" },
            { label: "Disk (/):", key: "disk" }
        ]

        property var softwareRows: [
            { label: "OS:", key: "os" },
            { label: "Kernel:", key: "kernel" },
            { label: "Window Manager:", key: "wm" },
            { label: "Terminal:", key: "terminal" },
            { label: "Packages:", key: "packages" },
            { label: "Local IP:", key: "ip" }
        ]

        property var ageRows: [
            { label: "OS Age:", key: "daysInstalled" },
            { label: "Uptime:", key: "uptime" },
            { label: "Installed:", key: "installed" }
        ]

        onVisibleChanged: {
            if (visible) {
                aboutGrab.active = true

                if (!aboutProc.running)
                    aboutProc.running = true
            } else {
                aboutGrab.active = false
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: "#FF07111C"
            border.color: "#45E7FF"
            border.width: 2

            Image {
                anchors.fill: parent
                anchors.margins: 3
                source: "file:///home/rick/Pictures/RicksLinuxWallpaper/wallpaper.png"
                fillMode: Image.PreserveAspectCrop
                opacity: 0.16
                smooth: true
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 7
                radius: 15
                color: "transparent"
                border.color: "#55FF2AA1"
                border.width: 1
                opacity: 0.7
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * 0.43
                radius: 18
                opacity: 0.18

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: "#00172A"
                    }

                    GradientStop {
                        position: 1.0
                        color: "#FF167D"
                    }
                }
            }

            Image {
                anchors.right: parent.right
                anchors.rightMargin: 50
                anchors.top: parent.top
                anchors.topMargin: 45
                width: 145
                height: 145
                opacity: 0.22
                source: "file:///home/rick/.config/quickshell/rick/icons/arch-bar.svg"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.top: parent.top
                anchors.topMargin: 13
                text: "×"
                color: "#FF4AB5"
                font.pixelSize: 30
                font.bold: true

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: aboutPopup.visible = false
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 5

                Item {
                    width: parent.width
                    height: titleRow.implicitHeight

                    Row {
                        id: titleRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 0

                        Text {
                            text: "Ricks Hypr"
                            color: "#EAF7FF"
                            font.pixelSize: 40
                            font.bold: true
                        }

                        Text {
                            text: "land"
                            color: "#FF2AA1"
                            font.pixelSize: 40
                            font.bold: true
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 45

                    Rectangle {
                        width: 500
                        height: 45
                        radius: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#260D1B2C"
                        border.color: "#35DFFF"
                        border.width: 2

                        Row {
                            anchors.centerIn: parent
                            spacing: 9

                            Text {
                                text: "RASPBERRY PI"
                                color: "#F5FAFF"
                                font.pixelSize: 22
                                font.bold: true
                                font.letterSpacing: 4
                            }

                            Text {
                                text: "5"
                                color: "#FF2AA1"
                                font.pixelSize: 24
                                font.bold: true
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "A R C H L I N U X   A R M 6 4"
                    color: "#DDEAF3"
                    font.pixelSize: 14
                    font.bold: true
                }

                Item {
                    width: 1
                    height: 4
                }

                Row {
                    width: parent.width
                    spacing: 10

                    Text {
                        text: "HARDWARE"
                        color: "#35E7FF"
                        font.pixelSize: 13
                        font.bold: true
                        font.family: "monospace"
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 105
                        height: 1
                        color: "#35DFFF"
                        opacity: 0.7
                    }
                }

                Column {
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: aboutPopup.hardwareRows

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: parent.width
                            height: 28
                            radius: 5
                            color: index % 2 === 0
                                ? "#CC08131F"
                                : "#A50C1525"
                            border.color: index % 2 === 0
                                ? "#2235E7FF"
                                : "#22FF2AA1"
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 10

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    text: "◆"
                                    color: index % 3 === 0
                                        ? "#FF2AA1"
                                        : "#35DFFF"
                                    font.pixelSize: 10
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 205
                                    text: modelData.label
                                    color: "#35E7FF"
                                    font.pixelSize: 15
                                    font.bold: true
                                    font.family: "monospace"
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 250
                                    text: root.aboutData[modelData.key] || "Loading..."
                                    color: "#F4F8FC"
                                    font.pixelSize: 15
                                    font.family: "monospace"
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Item {
                    width: 1
                    height: 3
                }

                Row {
                    width: parent.width
                    spacing: 10

                    Text {
                        text: "SOFTWARE"
                        color: "#FF69BE"
                        font.pixelSize: 13
                        font.bold: true
                        font.family: "monospace"
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 105
                        height: 1
                        color: "#FF2AA1"
                        opacity: 0.7
                    }
                }

                Column {
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: aboutPopup.softwareRows

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: parent.width
                            height: 28
                            radius: 5
                            color: index % 2 === 0
                                ? "#CC08131F"
                                : "#A50C1525"
                            border.color: index % 2 === 0
                                ? "#22FF2AA1"
                                : "#2235E7FF"
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 10

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    text: "◆"
                                    color: index % 3 === 0
                                        ? "#FF2AA1"
                                        : "#35DFFF"
                                    font.pixelSize: 10
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 205
                                    text: modelData.label
                                    color: "#35E7FF"
                                    font.pixelSize: 15
                                    font.bold: true
                                    font.family: "monospace"
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 250
                                    text: root.aboutData[modelData.key] || "Loading..."
                                    color: "#F4F8FC"
                                    font.pixelSize: 15
                                    font.family: "monospace"
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Item {
                    width: 1
                    height: 3
                }

                Row {
                    width: parent.width
                    spacing: 10

                    Text {
                        text: "AGE / UPTIME / INSTALL"
                        color: "#35E7FF"
                        font.pixelSize: 13
                        font.bold: true
                        font.family: "monospace"
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 205
                        height: 1
                        color: "#35DFFF"
                        opacity: 0.7
                    }
                }

                Column {
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: aboutPopup.ageRows

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: parent.width
                            height: 28
                            radius: 5
                            color: "#A50C1525"
                            border.color: index === 1
                                ? "#22FF2AA1"
                                : "#2235E7FF"
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 10

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    text: "◆"
                                    color: index === 1
                                        ? "#FF2AA1"
                                        : "#35DFFF"
                                    font.pixelSize: 10
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 205
                                    text: modelData.label
                                    color: "#35E7FF"
                                    font.pixelSize: 15
                                    font.bold: true
                                    font.family: "monospace"
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 250
                                    text: root.aboutData[modelData.key] || "Loading..."
                                    color: "#F4F8FC"
                                    font.pixelSize: 15
                                    font.family: "monospace"
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Item {
                    width: 1
                    height: 3
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#FF2AA1"
                    opacity: 0.6
                }

                Text {
                    text: "Ricks Hyprland  •  Raspberry Pi 5  •  Archlinux ARM64"
                    color: "#91AFC2"
                    font.pixelSize: 11
                }
            }
        }
    }

}
