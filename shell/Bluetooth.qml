import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: root

    property var modelScreen
    property int selected: 0
    property string notice: ""
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property bool onFocusedScreen: !Hyprland.focusedMonitor
        || Hyprland.focusedMonitor.name === modelScreen.name

    function deviceLabel(device) {
        return device.name || device.deviceName || device.address
    }

    function activate() {
        if (!adapter) {
            notice = "NO BLUETOOTH"
            return
        }
        if (devices.length === 0)
            return
        const device = devices[selected]
        if (device.connected)
            device.disconnect()
        else if (device.paired)
            device.connect()
        else
            device.pair()
        notice = deviceLabel(device)
    }

    screen: modelScreen
    visible: ShellState.bluetoothOpen && onFocusedScreen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sentinel-bluetooth"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    onVisibleChanged: {
        if (visible) {
            selected = 0
            notice = ""
            if (adapter) {
                adapter.enabled = true
                adapter.discovering = true
            }
            focusItem.forceActiveFocus()
        } else if (adapter) {
            adapter.discovering = false
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.bluetoothOpen = false
    }

    HudPanel {
        width: 520
        height: column.implicitHeight + 28
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.16
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "BLUETOOTH"
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: 12
                    font.letterSpacing: 2
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: !root.adapter ? "NO ADAPTER" : (root.adapter.enabled ? "ON" : "OFF")
                    color: root.adapter && root.adapter.enabled ? Theme.accent : Theme.warn
                    font.family: Theme.mono
                    font.pixelSize: 11
                }
            }

            Text {
                visible: root.devices.length === 0
                text: !root.adapter ? "NO BLUETOOTH ADAPTER" : "SCANNING"
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: 11
            }

            Repeater {
                model: root.devices
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    height: 28
                    color: index === root.selected ? Theme.accentDim : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        Text {
                            text: modelData.connected ? "●" : "○"
                            color: modelData.connected ? Theme.accent : Theme.muted
                            font.pixelSize: 10
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.deviceLabel(modelData)
                            color: Theme.text
                            font.family: Theme.mono
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.connected ? "CONNECTED" : (modelData.paired ? "PAIRED" : "NEW")
                            color: Theme.muted
                            font.family: Theme.mono
                            font.pixelSize: 10
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.selected = index
                            root.activate()
                        }
                    }
                }
            }

            Text {
                visible: root.notice.length > 0
                text: root.notice
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: 10
            }
            Text {
                text: "ENTER CONNECT   B POWER   S SCAN   F FORGET   ESC CLOSE"
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: 9
                font.letterSpacing: 1
            }
        }
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            ShellState.bluetoothOpen = false
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            activate()
        } else if (event.key === Qt.Key_Down && devices.length > 0) {
            selected = (selected + 1) % devices.length
        } else if (event.key === Qt.Key_Up && devices.length > 0) {
            selected = (selected - 1 + devices.length) % devices.length
        } else if (event.key === Qt.Key_B && adapter) {
            adapter.enabled = !adapter.enabled
            notice = adapter.enabled ? "BLUETOOTH ON" : "BLUETOOTH OFF"
        } else if (event.key === Qt.Key_S && adapter) {
            adapter.discovering = !adapter.discovering
            notice = adapter.discovering ? "SCANNING" : "SCAN STOPPED"
        } else if (event.key === Qt.Key_F && devices.length > 0) {
            devices[selected].forget()
            notice = "FORGET " + deviceLabel(devices[selected])
        } else {
            return
        }
        event.accepted = true
    }

    Item {
        id: focusItem
        focus: true
        Keys.onPressed: event => root.handleKey(event)
    }
}
