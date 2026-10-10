import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property var modelScreen
    property int selected: 0
    property string notice: ""
    readonly property var scales: [1, 1.25, 1.5, 1.75, 2]
    readonly property var monitors: Hyprland.monitors ? Hyprland.monitors.values : []
    readonly property bool onFocusedScreen: !Hyprland.focusedMonitor
        || Hyprland.focusedMonitor.name === modelScreen.name

    function nearest(scale) {
        let best = 0
        for (let i = 0; i < scales.length; i++) {
            if (Math.abs(scales[i] - scale) < Math.abs(scales[best] - scale))
                best = i
        }
        return best
    }

    function apply(delta) {
        if (monitors.length === 0) {
            notice = "NO MONITORS"
            return
        }
        const monitor = monitors[selected]
        const next = scales[(nearest(monitor.scale) + delta + scales.length) % scales.length]
        writer.monitorName = monitor.name
        writer.scale = next
        writer.command = ["python3", Quickshell.shellPath("../scripts/monitors.py"), "set", monitor.name, String(next)]
        writer.running = true
    }

    screen: modelScreen
    visible: ShellState.displayOpen && onFocusedScreen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sentinel-display"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    onVisibleChanged: if (visible) {
        selected = 0
        notice = ""
        focusItem.forceActiveFocus()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.displayOpen = false
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

            Text {
                text: "DISPLAY"
                color: Theme.accent
                font.family: Theme.mono
                font.pixelSize: 12
                font.letterSpacing: 2
            }

            Text {
                visible: root.monitors.length === 0
                text: "NO MONITORS"
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: 11
            }

            Repeater {
                model: root.monitors
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
                            Layout.fillWidth: true
                            text: modelData.name
                            color: Theme.text
                            font.family: Theme.mono
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.width + "x" + modelData.height + "  " + modelData.scale + "x"
                            color: Theme.muted
                            font.family: Theme.mono
                            font.pixelSize: 10
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.selected = index
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
                text: "←/→ SCALE   ↑/↓ MONITOR   ESC CLOSE"
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: 9
                font.letterSpacing: 1
            }
        }
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            ShellState.displayOpen = false
        } else if (event.key === Qt.Key_Down && monitors.length > 0) {
            selected = (selected + 1) % monitors.length
        } else if (event.key === Qt.Key_Up && monitors.length > 0) {
            selected = (selected - 1 + monitors.length) % monitors.length
        } else if (event.key === Qt.Key_Right) {
            apply(1)
        } else if (event.key === Qt.Key_Left) {
            apply(-1)
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

    Process {
        id: writer
        property string monitorName: ""
        property real scale: 1
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.notice = "SCALE FAILED"
                return
            }
            applyMonitor.command = ["hyprctl", "keyword", "monitor",
                writer.monitorName + ",preferred,auto," + writer.scale]
            applyMonitor.running = true
        }
    }

    Process {
        id: applyMonitor
        onExited: (exitCode, exitStatus) => {
            root.notice = exitCode === 0
                ? "SCALE " + writer.monitorName + " " + writer.scale + "x"
                : "SCALE FAILED (" + exitCode + ")"
        }
    }
}
