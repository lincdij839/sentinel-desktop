import Quickshell
import Quickshell.Io

ShellRoot {
    VolumeOsd {}
    ScreenshotOsd {}
    SettingsWindow {}
    Notifications { id: notifWin }
    PowerMenu {}
    Bar {}
    Todo {}
    Wheel { id: wheelWin }
    KeybindList { id: keysWin }

    // Register IPC even if an overlay window fails to construct.
    IpcHandler {
        target: "wheel"
        function toggle(): void { if (wheelWin) wheelWin.toggleMenu() }
        function show(): void { if (wheelWin) wheelWin.openMenu() }
        function hide(): void { if (wheelWin) wheelWin.closeMenu() }
        function confirm(): void { if (wheelWin) wheelWin.confirmSelection() }
    }
    IpcHandler {
        target: "keybinds"
        function toggle(): void { if (keysWin) keysWin.showing = !keysWin.showing }
        function show(): void { if (keysWin) keysWin.showing = true }
        function hide(): void { if (keysWin) keysWin.showing = false }
    }
    IpcHandler {
        target: "notifications"
        function toggle(): void { if (notifWin) notifWin.panelOpen = !notifWin.panelOpen }
        function open(): void { if (notifWin) notifWin.panelOpen = true }
        function close(): void { if (notifWin) notifWin.panelOpen = false }
        function clear(): void { if (notifWin) notifWin.clearHistory() }
        function dnd(): void { if (notifWin) notifWin.toggleDnd() }
    }
}