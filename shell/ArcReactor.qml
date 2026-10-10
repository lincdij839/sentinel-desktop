import QtQuick

// Arc-reactor style emblem: glowing core, tick ring and slowly counter-rotating arcs.
Item {
    id: reactor

    property color color: Theme.accent
    property bool animated: true

    implicitWidth: 64
    implicitHeight: 64

    Canvas {
        id: ring
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d")
            const w = width
            const c = w / 2
            ctx.reset()
            ctx.strokeStyle = reactor.color
            ctx.fillStyle = reactor.color
            ctx.lineWidth = Math.max(1, w / 40)

            ctx.globalAlpha = 0.9
            ctx.beginPath()
            ctx.arc(c, c, c * 0.94, 0, Math.PI * 2)
            ctx.stroke()

            ctx.globalAlpha = 0.5
            for (let i = 0; i < 36; i++) {
                const a = i * Math.PI / 18
                const inner = c * (i % 3 === 0 ? 0.78 : 0.85)
                ctx.beginPath()
                ctx.moveTo(c + Math.cos(a) * inner, c + Math.sin(a) * inner)
                ctx.lineTo(c + Math.cos(a) * c * 0.9, c + Math.sin(a) * c * 0.9)
                ctx.stroke()
            }
        }
        onWidthChanged: requestPaint()
    }

    Canvas {
        id: arcs
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d")
            const c = width / 2
            ctx.reset()
            ctx.strokeStyle = reactor.color
            ctx.lineWidth = Math.max(1.5, width / 22)
            ctx.globalAlpha = 0.95
            for (let i = 0; i < 3; i++) {
                const start = i * Math.PI * 2 / 3 + 0.2
                ctx.beginPath()
                ctx.arc(c, c, c * 0.62, start, start + Math.PI * 2 / 3 - 0.5)
                ctx.stroke()
            }
        }
        onWidthChanged: requestPaint()

        RotationAnimator on rotation {
            running: reactor.animated && reactor.visible
            from: 360
            to: 0
            duration: 14000
            loops: Animation.Infinite
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.3
        height: width
        radius: width / 2
        color: reactor.color
        opacity: 0.95

        SequentialAnimation on opacity {
            running: reactor.animated && reactor.visible
            loops: Animation.Infinite
            NumberAnimation { to: 0.6; duration: 1600; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
        }
    }
}
