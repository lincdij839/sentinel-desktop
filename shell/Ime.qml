pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Current fcitx5 input method. Empty until fcitx5-remote answers.
Singleton {
    id: ime

    property string current: ""
    property bool available: false

    readonly property string label: {
        const name = current.toLowerCase()
        if (!available || name.length === 0)
            return ""
        if (name.indexOf("keyboard") >= 0)
            return "EN"
        if (name.indexOf("pinyin") >= 0 || name.indexOf("rime") >= 0 || name.indexOf("chinese") >= 0)
            return "中"
        return current.slice(0, 8).toUpperCase()
    }

    function refresh() {
        if (!probe.running)
            probe.running = true
    }

    function toggle() {
        if (toggler.running)
            toggler.running = false
        toggler.command = ["fcitx5-remote", "-t"]
        toggler.running = true
    }

    Process {
        id: probe
        // Use the shell for the availability check so a missing optional
        // fcitx5 package does not emit a process-start warning every 2 seconds.
        command: ["sh", "-c", "command -v fcitx5-remote >/dev/null 2>&1 && exec fcitx5-remote -n"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                ime.available = true
                ime.current = text.trim()
            }
        }
        onExited: code => {
            if (code !== 0)
                ime.available = false
        }
    }

    Process {
        id: toggler
        onExited: ime.refresh()
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: ime.refresh()
    }
}
