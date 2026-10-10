import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
// shell/dashboard is a symlink: Quickshell cannot import QML from outside its shell directory.
import "dashboard"

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Wallpaper {
            required property var modelData
            modelScreen: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Bar {
            required property var modelData
            modelScreen: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Launcher {
            required property var modelData
            modelScreen: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Network {
            required property var modelData
            modelScreen: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Files {
            required property var modelData
            modelScreen: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PowerMenu {
            required property var modelData
            modelScreen: modelData
        }
    }

    Notifications {}
    Lock {}
    PolkitDialog {}
    Osd {}

    Variants {
        model: Quickshell.screens
        delegate: Audio {
            required property var modelData
            modelScreen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: Bluetooth {
            required property var modelData
            modelScreen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: Display {
            required property var modelData
            modelScreen: modelData
        }
    }

    IdleMonitor {
        enabled: !ShellState.locked
        respectInhibitors: true
        // IdleMonitor.timeout is seconds. Keep test overrides safe but predictable.
        timeout: {
            const raw = Number(Quickshell.env("SENTINEL_IDLE_LOCK_SEC") || "300")
            return Number.isFinite(raw) ? Math.max(5, raw) : 300
        }
        onIsIdleChanged: {
            if (!isIdle)
                return
            if (!ShellState.locked)
                ShellState.locked = true
            dpmsOff.running = true
        }
    }

    Process {
        id: dpmsOff
        command: ["hyprctl", "dispatch", "dpms", "off"]
    }
    Process {
        id: dpmsOn
        command: ["hyprctl", "dispatch", "dpms", "on"]
    }
    Connections {
        target: ShellState
        function onLockedChanged() {
            if (!ShellState.locked)
                dpmsOn.running = true
        }
    }

    LazyLoader {
        active: ShellState.dashboardOpen
        Dashboard {
            onCloseRequested: ShellState.dashboardOpen = false
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { ShellState.toggle("launcher") }
        function open(): void { ShellState.show("launcher") }
        function close(): void { ShellState.launcherOpen = false }
    }

    IpcHandler {
        target: "network"
        function toggle(): void { ShellState.toggle("network") }
    }

    IpcHandler {
        target: "files"
        function toggle(): void { ShellState.toggle("files") }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { ShellState.toggle("power") }
    }

    IpcHandler {
        target: "dashboard"
        function toggle(): void { ShellState.dashboardOpen = !ShellState.dashboardOpen }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { ShellState.locked = true }
    }

    IpcHandler {
        target: "audio"
        function toggle(): void { ShellState.toggle("audio") }
    }

    IpcHandler {
        target: "bluetooth"
        function toggle(): void { ShellState.toggle("bluetooth") }
    }

    IpcHandler {
        target: "display"
        function toggle(): void { ShellState.toggle("display") }
    }

    function applyWallpaper(text) {
        try {
            const parsed = JSON.parse(text)
            if (parsed.path)
                ShellState.wallpaperPath = parsed.path
        } catch (error) {
        }
    }

    Process {
        id: wallpaperCurrent
        command: ["python3", Quickshell.shellPath("../scripts/wallpaper.py"), "current"]
        stdout: StdioCollector {
            onStreamFinished: applyWallpaper(text)
        }
    }
    Process {
        id: wallpaperNext
        command: ["python3", Quickshell.shellPath("../scripts/wallpaper.py"), "next"]
        stdout: StdioCollector {
            onStreamFinished: applyWallpaper(text)
        }
    }
    Component.onCompleted: wallpaperCurrent.running = true

    IpcHandler {
        target: "wallpaper"
        function next(): void { wallpaperNext.running = true }
    }
}
