import QtQuick

// Decorative HUD drawn over the wallpaper: rotating rings around the emblem,
// screen-corner brackets and a small status readout.
Item {
    id: hud

    readonly property real unit: Math.min(width, height)
    readonly property real centerX: width / 2
    readonly property real centerY: height / 2

    Canvas {
        id: staticRing
        anchors.centerIn: parent
        width: hud.unit * 0.72
        height: width
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d")
            const c = width / 2
            ctx.reset()
            ctx.strokeStyle = Theme.accent
            ctx.lineWidth = 1
            ctx.globalAlpha = 0.55
            ctx.beginPath()
            ctx.arc(c, c, c * 0.98, 0, Math.PI * 2)
            ctx.stroke()
            ctx.globalAlpha = 0.35
            for (let i = 0; i < 120; i++) {
                const a = i * Math.PI / 60
                const len = i % 10 === 0 ? 0.08 : (i % 5 === 0 ? 0.05 : 0.025)
                ctx.beginPath()
                ctx.moveTo(c + Math.cos(a) * c * 0.98, c + Math.sin(a) * c * 0.98)
                ctx.lineTo(c + Math.cos(a) * c * (0.98 - len), c + Math.sin(a) * c * (0.98 - len))
                ctx.stroke()
            }
        }
        onWidthChanged: requestPaint()
    }

    Canvas {
        id: spinOuter
        anchors.centerIn: parent
        width: hud.unit * 0.64
        height: width
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d")
            const c = width / 2
            ctx.reset()
            ctx.strokeStyle = Theme.accent
            ctx.lineWidth = 2
            ctx.globalAlpha = 0.8
            const arcs = [[0.1, 1.1], [2.2, 3.0], [3.6, 4.6]]
            for (const a of arcs) {
                ctx.beginPath()
                ctx.arc(c, c, c * 0.98, a[0], a[1])
                ctx.stroke()
            }
        }
        onWidthChanged: requestPaint()
        RotationAnimator on rotation { from: 0; to: 360; duration: 40000; loops: Animation.Infinite }
    }

    Canvas {
        id: spinInner
        anchors.centerIn: parent
        width: hud.unit * 0.58
        height: width
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d")
            const c = width / 2
            ctx.reset()
            ctx.strokeStyle = Theme.accent
            ctx.setLineDash([3, 9])
            ctx.lineWidth = 1.5
            ctx.globalAlpha = 0.6
            ctx.beginPath()
            ctx.arc(c, c, c * 0.98, 0, Math.PI * 2)
            ctx.stroke()
        }
        onWidthChanged: requestPaint()
        RotationAnimator on rotation { from: 360; to: 0; duration: 60000; loops: Animation.Infinite }
    }

    component Corner: Item {
        property bool atRight: false
        property bool atBottom: false
        width: 56
        height: 56
        x: atRight ? hud.width - width - 24 : 24
        y: atBottom ? hud.height - height - 24 : Theme.barHeight + 24

        Rectangle { width: parent.width; height: 2; y: atBottom ? parent.height - 2 : 0; color: Theme.accent; opacity: 0.8 }
        Rectangle { width: 2; height: parent.height; x: atRight ? parent.width - 2 : 0; color: Theme.accent; opacity: 0.8 }
    }

    Corner {}
    Corner { atRight: true }
    Corner { atBottom: true }
    Corner { atRight: true; atBottom: true }

    Column {
        x: 44
        y: hud.height - height - 44
        spacing: 3
        Text {
            text: "SENTINEL // ONLINE"
            color: Theme.accent
            font.family: Theme.mono
            font.pixelSize: 11
            font.letterSpacing: 2
        }
        Text {
            text: Telemetry.ready
                ? "CORE " + Telemetry.cpu.toFixed(0) + "%   MEM " + Telemetry.memory.toFixed(0) + "%"
                : "CORE --   MEM --"
            color: Theme.muted
            font.family: Theme.mono
            font.pixelSize: 10
            font.letterSpacing: 1
        }
    }
}
