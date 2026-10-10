import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland

Scope {
    id: root

    property bool armed: false
    property bool shown: false
    property string label: ""
    property real level: 0
    property bool muted: false
    property string detail: ""

    function flash(name, value, isMuted, extra) {
        if (!armed)
            return
        label = name
        level = Math.max(0, Math.min(1, value))
        muted = isMuted
        detail = extra || ""
        shown = true
        hide.restart()
    }

    function sinkAudio() {
        const node = Pipewire.defaultAudioSink
        return node && node.audio ? node.audio : null
    }

    function bumpVolume(delta) {
        const audio = sinkAudio()
        if (!audio) {
            flash("VOLUME", 0, false, "NO AUDIO")
            return
        }
        audio.muted = false
        audio.volume = Math.max(0, Math.min(1, audio.volume + delta))
    }

    function toggleMute() {
        const audio = sinkAudio()
        if (!audio) {
            flash("VOLUME", 0, false, "NO AUDIO")
            return
        }
        audio.muted = !audio.muted
    }

    function bumpBrightness(argument) {
        brightnessSet.adjust = argument
        brightnessSet.command = ["brightnessctl", "set", argument]
        brightnessSet.running = true
    }

    Timer {
        interval: 800
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: hide
        interval: 1600
        onTriggered: root.shown = false
    }

    Connections {
        target: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
            ? Pipewire.defaultAudioSink.audio : null
        ignoreUnknownSignals: true
        function onVolumesChanged() {
            const audio = root.sinkAudio()
            if (audio)
                root.flash("VOLUME", audio.volume, audio.muted, "")
        }
        function onMutedChanged() {
            const audio = root.sinkAudio()
            if (audio)
                root.flash("VOLUME", audio.volume, audio.muted, audio.muted ? "MUTED" : "")
        }
    }

    IpcHandler {
        target: "osd"
        function volumeUp(): void { root.bumpVolume(0.05) }
        function volumeDown(): void { root.bumpVolume(-0.05) }
        function volumeMute(): void { root.toggleMute() }
        function brightnessUp(): void { root.bumpBrightness("5%+") }
        function brightnessDown(): void { root.bumpBrightness("5%-") }
    }

    Process {
        id: brightnessSet
        property string adjust: ""
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.flash("BRIGHTNESS", 0, false, "NO BACKLIGHT")
                return
            }
            brightnessRead.running = true
        }
    }

    Process {
        id: brightnessRead
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(",")
                const percent = fields.length ? fields[fields.length - 1] : ""
                const value = Number(percent.replace("%", ""))
                root.flash("BRIGHTNESS", Number.isFinite(value) ? value / 100 : 0, false, "")
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            required property var modelData
            readonly property bool onFocusedScreen: !Hyprland.focusedMonitor
                || Hyprland.focusedMonitor.name === modelData.name

            screen: modelData
            visible: root.shown && onFocusedScreen
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            margins.bottom: 28
            margins.left: Math.max(12, (modelData.width - 280) / 2)
            margins.right: Math.max(12, (modelData.width - 280) / 2)
            implicitHeight: 64
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sentinel-osd"
            color: "transparent"

            HudPanel {
                anchors.fill: parent
                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    Text {
                        text: root.detail.length > 0 ? root.label + "  " + root.detail
                            : root.label + "  " + Math.round(root.level * 100) + "%"
                        color: root.muted ? Theme.warn : Theme.accent
                        font.family: Theme.mono
                        font.pixelSize: 11
                        font.letterSpacing: 1
                    }
                    Rectangle {
                        width: parent.width
                        height: 6
                        color: Theme.accentDim
                        Rectangle {
                            width: parent.width * root.level
                            height: parent.height
                            color: root.muted ? Theme.warn : Theme.accent
                        }
                    }
                }
            }
        }
    }
}
