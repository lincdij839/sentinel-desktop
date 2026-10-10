import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Networking

PanelWindow {
    id: bar

    property var modelScreen
    readonly property int workspaceCount: 5

    screen: modelScreen
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.bg

    function workspaceOccupied(id) {
        const list = Hyprland.workspaces.values
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return true
        }
        return false
    }

    function networkLabel() {
        const devices = Networking.devices ? Networking.devices.values : []
        let wifi = ""
        let wired = false
        for (const device of devices) {
            if (device.type === DeviceType.Wifi) {
                const list = device.networks ? device.networks.values : []
                for (const net of list) {
                    if (net.connected)
                        wifi = net.name || wifi
                }
            } else if (device.type === DeviceType.Wired && device.hasLink) {
                wired = true
            }
        }
        if (wifi.length > 0)
            return wifi.length > 14 ? wifi.slice(0, 14) : wifi
        if (wired)
            return "ETH"
        return Networking.wifiEnabled ? "WIFI" : "OFFLINE"
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.accent
        opacity: 0.55
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 14
        spacing: 14

        ArcReactor {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
        }

        Text {
            text: "SENTINEL"
            color: Theme.accent
            font.family: Theme.mono
            font.pixelSize: 11
            font.letterSpacing: 3
            font.bold: true
        }

        Row {
            spacing: 4
            Repeater {
                model: bar.workspaceCount
                delegate: Rectangle {
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property bool focused: Hyprland.focusedWorkspace !== null
                        && Hyprland.focusedWorkspace.id === wsId
                    readonly property bool occupied: bar.workspaceOccupied(wsId)

                    width: 26
                    height: 22
                    radius: Theme.radius
                    color: focused ? Theme.accentDim : "transparent"
                    border.color: focused ? Theme.accent : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: parent.wsId
                        color: parent.focused ? Theme.accent : (parent.occupied ? Theme.text : Theme.muted)
                        font.family: Theme.mono
                        font.pixelSize: 11
                        font.bold: parent.focused
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Hyprland.dispatch("workspace " + parent.wsId)
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
            color: Theme.muted
            font.family: Theme.mono
            font.pixelSize: 11
        }

        Text {
            visible: Telemetry.ready
            text: "CPU " + Telemetry.cpu.toFixed(0) + "%"
            color: Theme.muted
            font.family: Theme.mono
            font.pixelSize: 11
        }
        Text {
            visible: Telemetry.ready
            text: "MEM " + Telemetry.memory.toFixed(0) + "%"
            color: Theme.muted
            font.family: Theme.mono
            font.pixelSize: 11
        }
        Text {
            visible: Telemetry.hasTemperature
            text: Telemetry.temperature.toFixed(0) + "°C"
            color: Telemetry.temperature >= 85 ? Theme.danger : Theme.muted
            font.family: Theme.mono
            font.pixelSize: 11
        }
        Text {
            visible: Telemetry.hasBattery
            text: "BAT " + Telemetry.battery + "%"
            color: Telemetry.battery <= 15 ? Theme.danger : Theme.muted
            font.family: Theme.mono
            font.pixelSize: 11
        }

        Text {
            text: bar.networkLabel()
            color: text === "OFFLINE" ? Theme.warn : Theme.accent
            font.family: Theme.mono
            font.pixelSize: 11
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                onClicked: ShellState.toggle("network")
            }
        }
        Text {
            visible: Ime.label.length > 0
            text: Ime.label
            color: Theme.accent
            font.family: Theme.mono
            font.pixelSize: 11
            font.bold: true
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                onClicked: Ime.toggle()
            }
        }
        Text {
            text: "PWR"
            color: ShellState.powerOpen ? Theme.warn : Theme.muted
            font.family: Theme.mono
            font.pixelSize: 11
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                onClicked: ShellState.toggle("power")
            }
        }

        Text {
            id: clock
            color: Theme.text
            font.family: Theme.mono
            font.pixelSize: 12
            font.bold: true
            text: Qt.formatDateTime(new Date(), "ddd dd MMM  HH:mm")
            Timer {
                interval: 1000
                repeat: true
                running: true
                onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd dd MMM  HH:mm")
            }
        }
    }
}
