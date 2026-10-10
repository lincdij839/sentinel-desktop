import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: launcher

    property var modelScreen
    property string query: ""
    property var results: []
    property int selected: 0
    readonly property int maxResults: 8
    readonly property bool onFocusedScreen: !Hyprland.focusedMonitor
        || Hyprland.focusedMonitor.name === modelScreen.name

    screen: modelScreen
    visible: ShellState.launcherOpen && onFocusedScreen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sentinel-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    function score(entry, needle) {
        const name = (entry.name || "").toLowerCase()
        if (name.startsWith(needle))
            return 0
        if (name.includes(needle))
            return 1
        const extra = ((entry.genericName || "") + " " + (entry.comment || "")).toLowerCase()
        return extra.includes(needle) ? 2 : -1
    }

    function refresh() {
        const needle = query.trim().toLowerCase()
        const apps = DesktopEntries.applications.values.filter(entry => !entry.noDisplay)
        let ranked = []
        for (const entry of apps) {
            const rank = needle.length === 0 ? 0 : score(entry, needle)
            if (rank >= 0)
                ranked.push({ entry: entry, rank: rank })
        }
        ranked.sort((a, b) => a.rank - b.rank || a.entry.name.localeCompare(b.entry.name))
        results = ranked.slice(0, maxResults).map(item => item.entry)
        selected = 0
    }

    function move(delta) {
        if (results.length === 0)
            return
        selected = (selected + delta + results.length) % results.length
    }

    function launch() {
        if (results.length === 0)
            return
        results[selected].execute()
        ShellState.launcherOpen = false
    }

    onQueryChanged: refresh()

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { launcher.refresh() }
    }
    onVisibleChanged: {
        if (visible) {
            input.text = ""
            query = ""
            refresh()
            input.forceActiveFocus()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.launcherOpen = false
    }

    HudPanel {
        id: panel
        width: 620
        height: column.implicitHeight + 28
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.2

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: "RUN"
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: 11
                    font.bold: true
                }
                TextInput {
                    id: input
                    Layout.fillWidth: true
                    color: Theme.text
                    font.family: Theme.mono
                    font.pixelSize: 15
                    selectionColor: Theme.accentDim
                    clip: true
                    onTextChanged: launcher.query = text
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            ShellState.launcherOpen = false
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            launcher.launch()
                        } else if (event.key === Qt.Key_Down
                                || (event.modifiers & Qt.ControlModifier
                                    && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                            launcher.move(1)
                        } else if (event.key === Qt.Key_Up
                                || (event.modifiers & Qt.ControlModifier
                                    && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                            launcher.move(-1)
                        } else {
                            return
                        }
                        event.accepted = true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.border
            }

            Text {
                visible: launcher.results.length === 0
                text: "NO MATCHING APPLICATIONS"
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: 11
                Layout.topMargin: 4
                Layout.bottomMargin: 4
            }

            Repeater {
                model: launcher.results
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    height: 40
                    radius: Theme.radius
                    color: index === launcher.selected ? Theme.accentDim : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12

                        Image {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            sourceSize: Qt.size(24, 24)
                            source: Quickshell.iconPath(modelData.icon, true)
                            visible: status === Image.Ready
                        }
                        Text {
                            text: modelData.name
                            color: Theme.text
                            font.family: Theme.mono
                            font.pixelSize: 13
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: modelData.comment || modelData.genericName || ""
                            color: Theme.muted
                            font.family: Theme.mono
                            font.pixelSize: 10
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: launcher.selected = index
                        onClicked: launcher.launch()
                    }
                }
            }

            Text {
                text: "ENTER RUN   ↑/↓ OR CTRL+J/K SELECT   ESC CLOSE"
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: 9
                Layout.topMargin: 2
            }
        }
    }
}
