import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland

PanelWindow {
    id: root

    property var modelScreen
    property string page: "sink"
    property int selected: 0
    property string notice: ""
    readonly property bool onFocusedScreen: !Hyprland.focusedMonitor
        || Hyprland.focusedMonitor.name === modelScreen.name
    readonly property var devices: page === "source" ? sources() : sinks()

    function audioNodes(wantSink) {
        const list = Pipewire.nodes ? Pipewire.nodes.values : []
        const found = []
        for (const node of list) {
            if (!node.ready || !node.audio || node.isStream)
                continue
            if (wantSink ? node.isSink : !node.isSink)
                found.push(node)
        }
        found.sort((a, b) => labelOf(a).localeCompare(labelOf(b)))
        return found
    }

    function sinks() { return audioNodes(true) }
    function sources() { return audioNodes(false) }

    function labelOf(node) {
        return node.description || node.nickname || node.name || "AUDIO"
    }

    function isDefault(node) {
        if (page === "source")
            return Pipewire.defaultAudioSource && node.id === Pipewire.defaultAudioSource.id
        return Pipewire.defaultAudioSink && node.id === Pipewire.defaultAudioSink.id
    }

    function choose() {
        if (devices.length === 0)
            return
        const node = devices[selected]
        if (page === "source")
            Pipewire.preferredDefaultAudioSource = node
        else
            Pipewire.preferredDefaultAudioSink = node
        notice = "DEFAULT " + labelOf(node)
    }

    function bump(delta) {
        const node = page === "source" ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink
        if (!node || !node.audio) {
            notice = "NO AUDIO"
            return
        }
        node.audio.muted = false
        node.audio.volume = Math.max(0, Math.min(1, node.audio.volume + delta))
        notice = labelOf(node) + "  " + Math.round(node.audio.volume * 100) + "%"
    }

    function muteDefault() {
        const node = page === "source" ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink
        if (!node || !node.audio) {
            notice = "NO AUDIO"
            return
        }
        node.audio.muted = !node.audio.muted
        notice = node.audio.muted ? "MUTED" : "UNMUTED"
    }

    screen: modelScreen
    visible: ShellState.audioOpen && onFocusedScreen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sentinel-audio"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    onVisibleChanged: {
        if (!visible)
            return
        selected = 0
        notice = ""
        focusItem.forceActiveFocus()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.audioOpen = false
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
                    text: root.page === "source" ? "MICROPHONE" : "AUDIO"
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: 12
                    font.letterSpacing: 2
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.page === "source" ? "INPUT" : "OUTPUT"
                    color: Theme.muted
                    font.family: Theme.mono
                    font.pixelSize: 11
                }
            }

            Text {
                visible: root.devices.length === 0
                text: "NO DEVICES"
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
                            text: root.isDefault(modelData) ? "●" : "○"
                            color: root.isDefault(modelData) ? Theme.accent : Theme.muted
                            font.pixelSize: 10
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.labelOf(modelData)
                            color: Theme.text
                            font.family: Theme.mono
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.audio.muted ? "MUTED" : Math.round(modelData.audio.volume * 100) + "%"
                            color: modelData.audio.muted ? Theme.warn : Theme.muted
                            font.family: Theme.mono
                            font.pixelSize: 10
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.selected = index
                            root.choose()
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
                text: "ENTER DEFAULT   TAB INPUT   M MUTE   ←/→ VOLUME   ESC CLOSE"
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: 9
                font.letterSpacing: 1
            }
        }
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            ShellState.audioOpen = false
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            choose()
        } else if (event.key === Qt.Key_Down) {
            if (devices.length > 0)
                selected = (selected + 1) % devices.length
        } else if (event.key === Qt.Key_Up) {
            if (devices.length > 0)
                selected = (selected - 1 + devices.length) % devices.length
        } else if (event.key === Qt.Key_Tab) {
            page = page === "sink" ? "source" : "sink"
            selected = 0
        } else if (event.key === Qt.Key_M) {
            muteDefault()
        } else if (event.key === Qt.Key_Left) {
            bump(-0.05)
        } else if (event.key === Qt.Key_Right) {
            bump(0.05)
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
