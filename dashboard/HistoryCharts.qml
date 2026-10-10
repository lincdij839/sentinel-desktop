import QtQuick
import QtQuick.Layouts

// Stack of live history charts fed from the dashboard's rolling sample lists.
ColumnLayout {
    id: charts

    property bool showCpu: true
    property bool showMemory: true
    property bool showNetwork: true
    property bool showTemperature: false

    property var cpuHistory: []
    property var memoryHistory: []
    property var rxHistory: []
    property var txHistory: []
    property var temperatureHistory: []
    property bool temperatureAvailable: false
    property string temperatureText: "N/A"
    property string cpuText: "WAITING"
    property string memoryText: "WAITING"
    property string networkText: "WAITING"
    property int capacity: 60

    spacing: 12

    component Panel: Rectangle {
        id: panel

        property string title
        property string valueText
        property string legend: ""
        property var values: []
        property var secondValues: []
        property real maxValue: 0
        property color lineColor: "#5ee6ff"
        property string emptyText: "COLLECTING SAMPLES"

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 56
        color: "#040e18"
        border.color: "#1d5266"
        radius: 4

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: panel.title
                    color: "#6aa0b2"
                    font.family: "monospace"
                    font.pixelSize: 10
                    font.letterSpacing: 0.8
                }
                Text {
                    visible: panel.legend.length > 0
                    text: panel.legend
                    color: "#5d8a9a"
                    font.family: "monospace"
                    font.pixelSize: 9
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: panel.valueText
                    color: "#8cefff"
                    font.family: "monospace"
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            Sparkline {
                Layout.fillWidth: true
                Layout.fillHeight: true
                values: panel.values
                secondValues: panel.secondValues
                maxValue: panel.maxValue
                capacity: charts.capacity
                lineColor: panel.lineColor
                emptyText: panel.emptyText
            }
        }
    }

    Panel {
        visible: charts.showCpu
        title: "CPU LOAD"
        valueText: charts.cpuText
        values: charts.cpuHistory
        maxValue: 100
    }
    Panel {
        visible: charts.showMemory
        title: "MEMORY"
        valueText: charts.memoryText
        values: charts.memoryHistory
        maxValue: 100
        lineColor: "#5ee6ff"
    }
    Panel {
        visible: charts.showNetwork
        title: "NETWORK RATE"
        legend: "RX / TX"
        valueText: charts.networkText
        values: charts.rxHistory
        secondValues: charts.txHistory
    }
    Panel {
        visible: charts.showTemperature
        title: "CPU TEMPERATURE"
        valueText: charts.temperatureText
        values: charts.temperatureHistory
        maxValue: 110
        lineColor: "#ffb347"
        emptyText: charts.temperatureAvailable ? "COLLECTING SAMPLES" : "NO SENSOR REPORTED"
    }
}
