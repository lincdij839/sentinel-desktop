import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: wallpaper

    property var modelScreen

    screen: modelScreen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "sentinel-wallpaper"
    color: "black"

    Image {
        anchors.fill: parent
        source: ShellState.wallpaperPath.length > 0
            ? "file://" + ShellState.wallpaperPath
            : Quickshell.shellPath("../assets/wallpaper.png")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
    }

    HudOverlay {
        anchors.fill: parent
    }
}
