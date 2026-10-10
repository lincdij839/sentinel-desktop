pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // Holographic HUD palette: translucent deep-blue glass, cyan light, amber/red alerts.
    readonly property color bg: "#cc03090f"
    readonly property color panel: "#d90a1c2a"
    readonly property color panelRaised: "#e6102b3d"
    readonly property color border: "#5530b8dc"
    readonly property color borderBright: "#ff5ee6ff"
    readonly property color text: "#d9f7ff"
    readonly property color muted: "#7fb4c6"
    readonly property color accent: "#5ee6ff"
    readonly property color accentDim: "#33143f55"
    readonly property color glow: "#665ee6ff"
    readonly property color warn: "#ffb347"
    readonly property color danger: "#ff5a4d"

    readonly property string mono: "monospace"
    readonly property int barHeight: 34
    readonly property int radius: 2
}
