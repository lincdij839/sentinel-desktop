import QtQuick

// Minimal line chart for short metric histories. The newest sample is drawn at
// the right edge; an optional second series shares the same scale.
Item {
    id: chart

    property var values: []
    property var secondValues: []
    property real maxValue: 0
    property int capacity: 60
    property string emptyText: "COLLECTING SAMPLES"
    property color lineColor: "#5ee6ff"
    property color secondColor: "#5ee6ff"
    property color gridColor: "#0e2a38"

    function scaleTop() {
        if (maxValue > 0)
            return maxValue
        let top = 1
        for (const value of values)
            top = Math.max(top, value)
        for (const value of secondValues)
            top = Math.max(top, value)
        return top * 1.15
    }

    function drawSeries(ctx, series, color, fill) {
        if (series.length < 2)
            return
        const top = scaleTop()
        const step = width / (capacity - 1)
        const startX = width - (series.length - 1) * step
        const yFor = value => height - 1 - Math.min(1, Math.max(0, value / top)) * (height - 2)

        ctx.beginPath()
        ctx.moveTo(startX, yFor(series[0]))
        for (let i = 1; i < series.length; i++)
            ctx.lineTo(startX + i * step, yFor(series[i]))
        ctx.strokeStyle = color
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.stroke()

        if (!fill)
            return
        ctx.lineTo(width, height)
        ctx.lineTo(startX, height)
        ctx.closePath()
        ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.12)
        ctx.fill()
    }

    onValuesChanged: canvas.requestPaint()
    onSecondValuesChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.lineWidth = 1
            ctx.strokeStyle = chart.gridColor
            for (let i = 1; i < 4; i++) {
                const y = Math.round(height * i / 4) + 0.5
                ctx.beginPath()
                ctx.moveTo(0, y)
                ctx.lineTo(width, y)
                ctx.stroke()
            }
            chart.drawSeries(ctx, chart.values, chart.lineColor, true)
            chart.drawSeries(ctx, chart.secondValues, chart.secondColor, false)
        }
    }

    Text {
        anchors.centerIn: parent
        visible: chart.values.length < 2
        text: chart.emptyText
        color: "#5d8a9a"
        font.family: "monospace"
        font.pixelSize: 9
        font.letterSpacing: 0.8
    }
}
