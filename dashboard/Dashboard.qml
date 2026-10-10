import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: root

    signal closeRequested

    visible: true
    title: "Sentinel Desktop"
    implicitWidth: 1360
    implicitHeight: 860
    minimumSize: Qt.size(1000, 700)
    color: "#f2040d16"

    property string clockText: ""
    property string telemetryStatus: "STARTING"
    property var telemetry: null
    property int activeWorkspace: 0
    property int historyLimit: 60
    property var cpuHistory: []
    property var memoryHistory: []
    property var rxRateHistory: []
    property var txRateHistory: []
    property var temperatureHistory: []
    property real lastSampleMs: 0
    property real lastRxBytes: 0
    property real lastTxBytes: 0
    property real rxRate: 0
    property real txRate: 0
    readonly property string cpuText: telemetry ? telemetry.cpu_percent.toFixed(1) + "%" : "WAITING"
    readonly property string memoryText: telemetry ? telemetry.memory_percent.toFixed(1) + "%" : "WAITING"
    readonly property bool temperatureAvailable: telemetry !== null && hasNumber(telemetry.cpu_temp_c)
    readonly property string temperatureText: temperatureAvailable ? telemetry.cpu_temp_c.toFixed(1) + " °C" : "N/A"
    readonly property string loadText: telemetry && Number.isFinite(telemetry.load_1)
            ? telemetry.load_1.toFixed(2) + " / " + telemetry.load_5.toFixed(2) + " / " + telemetry.load_15.toFixed(2)
            : "Waiting for sample"
    readonly property string diskText: telemetry && Number.isFinite(telemetry.disk_total_gib)
            ? telemetry.disk_used_gib.toFixed(1) + " / " + telemetry.disk_total_gib.toFixed(1)
                + " GiB (" + telemetry.disk_percent.toFixed(1) + "%)"
            : "Waiting for sample"
    readonly property string networkText: telemetry && lastSampleMs > 0
            ? formatBytes(rxRate) + "/s / " + formatBytes(txRate) + "/s"
            : "WAITING"
    property var workspaceTitles: ["OVERVIEW", "SYSTEM", "NETWORK", "ACTIVITY"]
    property var workspaceSubtitles: [
        "LOCAL WORKSTATION // STATUS BOARD",
        "LOCAL RESOURCE MONITOR",
        "INTERFACE COUNTERS // READ-ONLY",
        "HARDWARE SENSORS AND PRIVACY"
    ]
    property color muted: "#6aa0b2"
    property color accent: "#5ee6ff"
    property color panel: "#061620"
    property color border: "#1d5266"

    function acceptTelemetry(output) {
        let data
        try {
            data = JSON.parse(output)
        } catch (error) {
            telemetryStatus = "INVALID DATA"
            console.warn("Sentinel telemetry returned invalid JSON:", error)
            return
        }

        if (!Number.isFinite(data.cpu_percent)
                || !Number.isFinite(data.memory_percent)
                || !Number.isFinite(data.rx_bytes)
                || !Number.isFinite(data.tx_bytes)
                || !Number.isFinite(data.uptime_seconds)) {
            telemetryStatus = "INVALID DATA"
            console.warn("Sentinel telemetry response is missing required metrics")
            return
        }

        recordHistory(data)
        telemetry = data
        telemetryStatus = "LIVE"
    }

    function hasNumber(value) {
        return typeof value === "number" && Number.isFinite(value)
    }

    function selectWorkspace(index) {
        const count = workspaceTitles.length
        activeWorkspace = ((index % count) + count) % count
    }

    function sensorCards() {
        const data = telemetry
        const reported = key => data !== null && hasNumber(data[key])
        return [
            {
                label: "CPU TEMP",
                value: reported("cpu_temp_c") ? data.cpu_temp_c.toFixed(1) + " °C" : "N/A",
                note: reported("cpu_temp_c") ? "Package or hottest core sensor" : "Not reported by this hardware"
            },
            {
                label: "STORAGE TEMP",
                value: reported("storage_temp_c") ? data.storage_temp_c.toFixed(1) + " °C" : "N/A",
                note: reported("storage_temp_c") ? "NVMe composite sensor" : "Not reported by this hardware"
            },
            {
                label: "BATTERY",
                value: reported("battery_percent") ? data.battery_percent + "%" : "N/A",
                note: reported("battery_percent") ? String(data.battery_status) : "No battery detected"
            },
            {
                label: "DISK /",
                value: reported("disk_percent") ? data.disk_percent.toFixed(1) + "%" : "N/A",
                note: reported("disk_total_gib")
                        ? data.disk_used_gib.toFixed(1) + " / " + data.disk_total_gib.toFixed(1) + " GiB"
                        : "Root filesystem"
            }
        ]
    }

    function appendSample(list, value) {
        const next = list.concat([value])
        return next.length > historyLimit ? next.slice(next.length - historyLimit) : next
    }

    function recordHistory(data) {
        const now = Date.now()
        const elapsed = (now - lastSampleMs) / 1000
        // Counters can reset (interface removed, reboot); treat that as zero traffic.
        if (lastSampleMs > 0 && elapsed > 0) {
            rxRate = Math.max(0, (data.rx_bytes - lastRxBytes) / elapsed)
            txRate = Math.max(0, (data.tx_bytes - lastTxBytes) / elapsed)
            rxRateHistory = appendSample(rxRateHistory, rxRate)
            txRateHistory = appendSample(txRateHistory, txRate)
        }
        lastSampleMs = now
        lastRxBytes = data.rx_bytes
        lastTxBytes = data.tx_bytes
        cpuHistory = appendSample(cpuHistory, data.cpu_percent)
        if (hasNumber(data.cpu_temp_c))
            temperatureHistory = appendSample(temperatureHistory, data.cpu_temp_c)
        memoryHistory = appendSample(memoryHistory, data.memory_percent)
    }

    function updateClock() {
        clockText = Qt.formatDateTime(new Date(), "yyyy-MM-dd  hh:mm:ss")
    }

    function formatBytes(value) {
        if (value < 1024)
            return value + " B"
        if (value < 1024 * 1024)
            return (value / 1024).toFixed(1) + " KiB"
        if (value < 1024 * 1024 * 1024)
            return (value / (1024 * 1024)).toFixed(1) + " MiB"
        return (value / (1024 * 1024 * 1024)).toFixed(1) + " GiB"
    }

    function formatUptime(value) {
        const days = Math.floor(value / 86400)
        const hours = Math.floor((value % 86400) / 3600)
        const minutes = Math.floor((value % 3600) / 60)
        return days + "d " + hours + "h " + minutes + "m"
    }

    function currentPageCards() {
        if (activeWorkspace === 1) {
            return [
                {
                    label: "CPU LOAD",
                    value: telemetry ? telemetry.cpu_percent.toFixed(1) + "%" : "WAITING",
                    note: telemetry && Number.isFinite(telemetry.load_1)
                            ? "Load avg " + telemetry.load_1.toFixed(2) + " / "
                                + telemetry.load_5.toFixed(2) + " / " + telemetry.load_15.toFixed(2)
                            : "Sampled over a short local interval"
                },
                {
                    label: "MEMORY",
                    value: telemetry
                            ? telemetry.memory_used_mib + " / " + telemetry.memory_total_mib + " MiB"
                            : "WAITING",
                    note: telemetry ? telemetry.memory_percent.toFixed(1) + "% used" : "Awaiting sample"
                },
                {
                    label: "DISK /",
                    value: telemetry && Number.isFinite(telemetry.disk_total_gib)
                            ? telemetry.disk_used_gib.toFixed(1) + " / "
                                + telemetry.disk_total_gib.toFixed(1) + " GiB"
                            : "WAITING",
                    note: telemetry && Number.isFinite(telemetry.disk_percent)
                            ? telemetry.disk_percent.toFixed(1) + "% used"
                            : "Root filesystem capacity"
                },
                {
                    label: "UPTIME",
                    value: telemetry ? formatUptime(telemetry.uptime_seconds) : "WAITING",
                    note: "Time since this system booted"
                }
            ]
        }
        if (activeWorkspace === 2) {
            return [
                {
                    label: "RECEIVED",
                    value: telemetry ? formatBytes(telemetry.rx_bytes) : "WAITING",
                    note: "Aggregate interface counter"
                },
                {
                    label: "TRANSMITTED",
                    value: telemetry ? formatBytes(telemetry.tx_bytes) : "WAITING",
                    note: "Aggregate interface counter"
                },
                {
                    label: "DATA SOURCE",
                    value: "/proc/net/dev",
                    note: "Loopback excluded; no packet contents read"
                }
            ]
        }
        return [
            {
                label: "INPUT HISTORY",
                value: "NOT COLLECTED",
                note: "No keystrokes or application usage recorded"
            },
            {
                label: "NETWORK EXPORT",
                value: "NONE",
                note: "The telemetry script makes no network requests"
            },
            {
                label: "PRIVILEGES",
                value: "USER ONLY",
                note: "No elevated access required"
            }
        ]
    }

    Shortcut { sequence: "1"; onActivated: root.selectWorkspace(0) }
    Shortcut { sequence: "2"; onActivated: root.selectWorkspace(1) }
    Shortcut { sequence: "3"; onActivated: root.selectWorkspace(2) }
    Shortcut { sequence: "4"; onActivated: root.selectWorkspace(3) }
    Shortcut { sequences: ["J", "Right", "Tab"]; onActivated: root.selectWorkspace(root.activeWorkspace + 1) }
    Shortcut { sequences: ["K", "Left", "Backtab"]; onActivated: root.selectWorkspace(root.activeWorkspace - 1) }
    Shortcut { sequences: ["Q", "Ctrl+Q", "Escape"]; onActivated: root.closeRequested() }
    onVisibleChanged: if (!visible) closeRequested()

    Component.onCompleted: {
        updateClock()
        telemetryProcess.running = true
    }

    Process {
        id: telemetryProcess
        command: ["python3", Quickshell.shellDir + "/../scripts/telemetry.py"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.acceptTelemetry(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) {
                    root.telemetryStatus = "ERROR"
                    console.warn("Sentinel telemetry:", text.trim())
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.telemetryStatus = "ERROR"
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.updateClock()
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            if (!telemetryProcess.running)
                telemetryProcess.running = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 62
            color: "#051420"
            border.color: root.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 16

                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 6
                    color: "#0f3a4a"
                    Text {
                        anchors.centerIn: parent
                        text: "S"
                        color: root.accent
                        font.pixelSize: 18
                        font.bold: true
                    }
                }

                Column {
                    spacing: 2
                    Text {
                        text: "SENTINEL"
                        color: "#d9f7ff"
                        font.family: "monospace"
                        font.pixelSize: 15
                        font.bold: true
                    }
                    Text {
                        text: "PERSONAL DESKTOP CONSOLE"
                        color: root.muted
                        font.family: "monospace"
                        font.pixelSize: 9
                        font.letterSpacing: 1.2
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "●  " + root.telemetryStatus
                    color: root.telemetryStatus === "LIVE" ? root.accent : "#ffb347"
                    font.family: "monospace"
                    font.pixelSize: 10
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 24
                    color: root.border
                }

                Text {
                    text: root.clockText
                    color: "#b0dbe6"
                    font.family: "monospace"
                    font.pixelSize: 12
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 214
                Layout.fillHeight: true
                color: "#04111b"
                border.color: root.border
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Text {
                        text: "WORKSPACE"
                        color: root.muted
                        font.family: "monospace"
                        font.pixelSize: 10
                        font.letterSpacing: 1.4
                    }

                    Repeater {
                        model: ["01  OVERVIEW", "02  SYSTEM", "03  NETWORK", "04  ACTIVITY"]
                        delegate: Rectangle {
                            id: workspaceItem
                            required property string modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: 4
                            color: index === root.activeWorkspace ? "#0c2a38" : "transparent"
                            border.color: index === root.activeWorkspace ? "#145a70" : "transparent"

                            TapHandler {
                                onTapped: root.activeWorkspace = workspaceItem.index
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                text: modelData
                                color: workspaceItem.index === root.activeWorkspace
                                        ? root.accent : "#7fb4c6"
                                font.family: "monospace"
                                font.pixelSize: 11
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        text: "SESSION"
                        color: root.muted
                        font.family: "monospace"
                        font.pixelSize: 10
                        font.letterSpacing: 1.4
                    }
                    Text {
                        text: "Fedora desktop prototype\nLocal system metrics enabled"
                        color: "#7fb4c6"
                        font.family: "monospace"
                        font.pixelSize: 10
                        lineHeight: 1.35
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 24
                spacing: 20

                RowLayout {
                    Layout.fillWidth: true
                    Column {
                        spacing: 5
                        Text {
                            text: root.workspaceTitles[root.activeWorkspace]
                            color: "#d9f7ff"
                            font.family: "monospace"
                            font.pixelSize: 22
                            font.bold: true
                        }
                        Text {
                            text: root.workspaceSubtitles[root.activeWorkspace]
                            color: root.muted
                            font.family: "monospace"
                            font.pixelSize: 10
                            font.letterSpacing: 1.1
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "●  " + root.telemetryStatus
                        color: root.telemetryStatus === "LIVE" ? root.accent : "#ffb347"
                        font.family: "monospace"
                        font.pixelSize: 10
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    visible: root.activeWorkspace === 0

                    Repeater {
                        model: [
                            { label: "CPU LOAD", key: "cpu" },
                            { label: "MEMORY", key: "memory" },
                            { label: "NETWORK RX / TX", key: "network" },
                            { label: "UPTIME", key: "uptime" }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 98
                            color: root.panel
                            border.color: root.border
                            radius: 5

                            Column {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12

                                Text {
                                    text: modelData.label
                                    color: root.muted
                                    font.family: "monospace"
                                    font.pixelSize: 10
                                    font.letterSpacing: 0.8
                                }
                                Text {
                                    text: {
                                        if (!root.telemetry)
                                            return "WAITING FOR SAMPLE"
                                        if (modelData.key === "cpu")
                                            return root.telemetry.cpu_percent.toFixed(1) + "%"
                                        if (modelData.key === "memory")
                                            return root.telemetry.memory_used_mib + " / "
                                                    + root.telemetry.memory_total_mib + " MiB ("
                                                    + root.telemetry.memory_percent.toFixed(1) + "%)"
                                        if (modelData.key === "network")
                                            return root.formatBytes(root.telemetry.rx_bytes) + " / "
                                                    + root.formatBytes(root.telemetry.tx_bytes)
                                        return root.formatUptime(root.telemetry.uptime_seconds)
                                    }
                                    width: parent.width
                                    elide: Text.ElideRight
                                    color: root.telemetryStatus === "LIVE" ? "#8cefff" : "#8dbfce"
                                    font.family: "monospace"
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12
                    visible: root.activeWorkspace === 0

                    HistoryCharts {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        cpuHistory: root.cpuHistory
                        memoryHistory: root.memoryHistory
                        rxHistory: root.rxRateHistory
                        txHistory: root.txRateHistory
                        cpuText: root.cpuText
                        memoryText: root.memoryText
                        networkText: root.networkText
                        capacity: root.historyLimit
                    }

                    Rectangle {
                        Layout.preferredWidth: 310
                        Layout.fillHeight: true
                        color: root.panel
                        border.color: root.border
                        radius: 5

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 14

                            Text {
                                text: "HOST STATUS"
                                color: "#c2e9f2"
                                font.family: "monospace"
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Repeater {
                                model: [
                                    { time: "LOAD AVERAGE", message: root.loadText },
                                    { time: "DISK /", message: root.diskText },
                                    { time: "TELEMETRY", message: "Local metrics " + root.telemetryStatus.toLowerCase()
                                            + " (every 5 s)" }
                                ]
                                delegate: ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 5
                                    Text {
                                        text: modelData.time
                                        color: root.accent
                                        font.family: "monospace"
                                        font.pixelSize: 9
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.message
                                        color: "#8dbfce"
                                        font.family: "monospace"
                                        font.pixelSize: 10
                                        wrapMode: Text.Wrap
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: root.border
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }

                            Text {
                                text: "Metrics are read locally from /proc.\nNo network requests or elevated privileges."
                                color: root.muted
                                font.family: "monospace"
                                font.pixelSize: 9
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                Rectangle {
                    visible: root.activeWorkspace !== 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.panel
                    border.color: root.border
                    radius: 5

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 18

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: root.workspaceTitles[root.activeWorkspace] + " // DETAILS"
                                color: "#c2e9f2"
                                font.family: "monospace"
                                font.pixelSize: 12
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "●  " + root.telemetryStatus
                                color: root.telemetryStatus === "LIVE" ? root.accent : "#ffb347"
                                font.family: "monospace"
                                font.pixelSize: 10
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Repeater {
                                model: root.currentPageCards()
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 126
                                    color: "#040e18"
                                    border.color: root.border
                                    radius: 4

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 10

                                        Text {
                                            text: modelData.label
                                            color: root.muted
                                            font.family: "monospace"
                                            font.pixelSize: 10
                                            font.letterSpacing: 0.8
                                        }
                                        Text {
                                            text: modelData.value
                                            color: "#8cefff"
                                            font.family: "monospace"
                                            font.pixelSize: 16
                                            font.bold: true
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.note
                                            color: "#7fb4c6"
                                            font.family: "monospace"
                                            font.pixelSize: 9
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "#040e18"
                            border.color: root.border
                            radius: 4

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 10

                                Text {
                                    text: root.activeWorkspace === 1
                                            ? "RESOURCE MONITOR"
                                            : root.activeWorkspace === 2
                                                ? "NETWORK COUNTERS"
                                                : "PRIVACY BY DESIGN"
                                    color: root.accent
                                    font.family: "monospace"
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.activeWorkspace === 1
                                            ? "CPU, load, memory and uptime are read locally from Linux procfs; disk usage comes from the root filesystem. Values refresh every five seconds and the charts keep the last five minutes."
                                            : root.activeWorkspace === 2
                                                ? "Byte totals come from Linux interface counters and are cumulative for the lifetime of each interface. The chart shows the average rate between five-second samples."
                                                : "This prototype does not record keystrokes, commands, application history or network traffic contents. It only reads aggregate system counters needed for the overview."
                                    color: "#8dbfce"
                                    font.family: "monospace"
                                    font.pixelSize: 10
                                    wrapMode: Text.Wrap
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: root.activeWorkspace === 3
                                    spacing: 12

                                    Repeater {
                                        model: root.sensorCards()
                                        delegate: Rectangle {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 86
                                            color: root.panel
                                            border.color: root.border
                                            radius: 4

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 6

                                                Text {
                                                    text: modelData.label
                                                    color: root.muted
                                                    font.family: "monospace"
                                                    font.pixelSize: 10
                                                    font.letterSpacing: 0.8
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.value
                                                    elide: Text.ElideRight
                                                    color: modelData.value === "N/A" ? "#7fb4c6" : "#8cefff"
                                                    font.family: "monospace"
                                                    font.pixelSize: 15
                                                    font.bold: true
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.note
                                                    elide: Text.ElideRight
                                                    color: "#7fb4c6"
                                                    font.family: "monospace"
                                                    font.pixelSize: 9
                                                }
                                            }
                                        }
                                    }
                                }
                                HistoryCharts {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    showCpu: root.activeWorkspace === 1
                                    showMemory: root.activeWorkspace === 1
                                    showNetwork: root.activeWorkspace === 2
                                    showTemperature: root.activeWorkspace === 3
                                    cpuHistory: root.cpuHistory
                                    memoryHistory: root.memoryHistory
                                    rxHistory: root.rxRateHistory
                                    txHistory: root.txRateHistory
                                    temperatureHistory: root.temperatureHistory
                                    temperatureAvailable: root.temperatureAvailable
                                    cpuText: root.cpuText
                                    memoryText: root.memoryText
                                    networkText: root.networkText
                                    temperatureText: root.temperatureText
                                    capacity: root.historyLimit
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "SENTINEL // PERSONAL FEDORA DESKTOP"
                        color: "#5d8a9a"
                        font.family: "monospace"
                        font.pixelSize: 9
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "1-4 PAGE   J/K  \u2190/\u2192  SWITCH   Q QUIT"
                        color: "#5d8a9a"
                        font.family: "monospace"
                        font.pixelSize: 9
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "PROTOTYPE 0.1"
                        color: "#5d8a9a"
                        font.family: "monospace"
                        font.pixelSize: 9
                    }
                }
            }
        }
    }
}
