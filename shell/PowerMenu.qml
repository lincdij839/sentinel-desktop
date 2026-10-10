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
    property string armed: ""
    property string notice: ""
    readonly property bool dryRun: Quickshell.env("SENTINEL_POWER_DRY_RUN") === "1"
    readonly property var actions: [
        { id: "lock", label: "LOCK" },
        { id: "suspend", label: "SUSPEND" },
        { id: "logout", label: "LOG OUT" },
        { id: "reboot", label: "REBOOT" },
        { id: "poweroff", label: "POWER OFF" }
    ]
    readonly property bool onFocusedScreen: !Hyprland.focusedMonitor
        || Hyprland.focusedMonitor.name === modelScreen.name

    function launch(command, label) {
        if (dryRun) {
            notice = "TEST MODE: " + label
            return
        }
        if (runner.running) {
            notice = "POWER ACTION BUSY"
            return
        }
        runner.actionLabel = label
        runner.command = command
        runner.running = true
    }

    function activate() {
        const action = actions[selected]
        const dangerous = action.id !== "lock"
        if (dangerous && armed !== action.id) {
            armed = action.id
            confirmTimeout.restart()
            return
        }
        confirmTimeout.stop()
        armed = ""
        if (!dryRun)
            ShellState.powerOpen = false
        if (action.id === "lock") {
            ShellState.locked = true
        } else if (action.id === "suspend") {
            if (!dryRun)
                ShellState.locked = true
            launch(["systemctl", "suspend"], "SUSPEND")
        } else if (action.id === "logout") {
            launch([
                "sh", "-c",
                "if command -v uwsm >/dev/null 2>&1 && uwsm check is-active; "
                    + "then exec uwsm stop; "
                    + "else exec hyprctl dispatch 'hl.dsp.exit()'; fi"
            ], "LOG OUT")
        } else if (action.id === "reboot") {
            launch(["systemctl", "reboot"], "REBOOT")
        } else if (action.id === "poweroff") {
            launch(["systemctl", "poweroff"], "POWER OFF")
        }
    }

    screen: modelScreen
    visible: ShellState.powerOpen && onFocusedScreen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sentinel-power"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    onVisibleChanged: {
        if (visible) {
            selected = 0
            armed = ""
            notice = dryRun ? "SAFE TEST MODE" : ""
            focusItem.forceActiveFocus()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.powerOpen = false
    }

    HudPanel {
        width: 360
        height: column.implicitHeight + 28
        anchors.centerIn: parent
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 14
            spacing: 6

            Text {
                text: "POWER"
                color: Theme.accent
                font.family: Theme.mono
                font.pixelSize: 12
                font.letterSpacing: 3
            }

            Repeater {
                model: root.actions
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    height: 32
                    color: index === root.selected ? Theme.accentDim : "transparent"
                    border.color: root.armed === modelData.id ? Theme.warn : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12
                        text: (index + 1) + "  " + modelData.label
                            + (root.armed === modelData.id ? "   CONFIRM" : "")
                        color: root.armed === modelData.id ? Theme.warn : Theme.text
                        font.family: Theme.mono
                        font.pixelSize: 13
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
                text: "ENTER RUN   1-5 JUMP   ESC CLOSE"
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: 9
                font.letterSpacing: 1
            }
            Text {
                visible: root.notice.length > 0
                text: root.notice
                color: root.notice.indexOf("FAILED") >= 0 ? Theme.danger : Theme.warn
                font.family: Theme.mono
                font.pixelSize: 10
            }
        }
    }

    Item {
        id: focusItem
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                ShellState.powerOpen = false
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                root.selected = (root.selected + 1) % root.actions.length
                root.armed = ""
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                root.selected = (root.selected + root.actions.length - 1) % root.actions.length
                root.armed = ""
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_5) {
                root.selected = event.key - Qt.Key_1
                root.activate()
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.activate()
            } else {
                return
            }
            event.accepted = true
        }
    }

    Timer {
        id: confirmTimeout
        interval: 8000
        onTriggered: root.armed = ""
    }

    Process {
        id: runner
        property string actionLabel: ""
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                ShellState.powerOpen = true
                root.notice = actionLabel + " FAILED (" + exitCode + ")"
            } else if (actionLabel === "SUSPEND") {
                root.notice = "RESUMED"
            }
        }
    }
}
