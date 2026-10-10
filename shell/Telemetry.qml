pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Read-only host metrics shared by the bar and other shell components.
Singleton {
    id: root

    property var data: null
    property string status: "STARTING"

    readonly property bool ready: data !== null
    readonly property real cpu: ready ? data.cpu_percent : 0
    readonly property real memory: ready ? data.memory_percent : 0
    readonly property bool hasTemperature: ready && typeof data.cpu_temp_c === "number"
    readonly property real temperature: hasTemperature ? data.cpu_temp_c : 0
    readonly property bool hasBattery: ready && typeof data.battery_percent === "number"
    readonly property int battery: hasBattery ? data.battery_percent : 0
    readonly property string batteryStatus: hasBattery ? String(data.battery_status) : ""

    function accept(output) {
        let parsed
        try {
            parsed = JSON.parse(output)
        } catch (error) {
            status = "INVALID DATA"
            return
        }
        if (!Number.isFinite(parsed.cpu_percent) || !Number.isFinite(parsed.memory_percent)) {
            status = "INVALID DATA"
            return
        }
        data = parsed
        status = "LIVE"
    }

    Process {
        id: sampler
        command: ["python3", Quickshell.shellPath("../scripts/telemetry.py")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.accept(text)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.status = "ERROR"
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            if (!sampler.running)
                sampler.running = true
        }
    }
}
