import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland

PanelWindow {
    id: root

    property var modelScreen
    property var networks: []
    property int selected: 0
    property bool askingPassword: false
    property string notice: ""
    property var pendingNetwork: null
    property string page: "wifi"
    property var saved: []
    property int savedSelected: 0
    property bool confirmForget: false
    readonly property bool wifiAvailable: wifiDevices().length > 0
    readonly property bool onFocusedScreen: !Hyprland.focusedMonitor
        || Hyprland.focusedMonitor.name === modelScreen.name

    function wifiDevices() {
        const devices = Networking.devices ? Networking.devices.values : []
        const found = []
        for (const device of devices) {
            if (device.type === DeviceType.Wifi)
                found.push(device)
        }
        return found
    }

    function refresh() {
        const found = []
        for (const device of wifiDevices()) {
            device.scannerEnabled = true
            const list = device.networks ? device.networks.values : []
            for (const net of list)
                found.push(net)
        }
        found.sort((a, b) => (b.signalStrength || 0) - (a.signalStrength || 0) || a.name.localeCompare(b.name))
        networks = found.slice(0, 10)
        if (selected >= networks.length)
            selected = 0
    }

    function wiredSummary() {
        const devices = Networking.devices ? Networking.devices.values : []
        const parts = []
        for (const device of devices) {
            if (device.type !== DeviceType.Wired)
                continue
            parts.push((device.hasLink ? "LINK" : "DOWN") + " " + device.name)
        }
        return parts.length ? parts.join("   ") : "NO ETHERNET"
    }

    function needsPassword(net) {
        if (!net || net.known)
            return false
        return net.security !== WifiSecurityType.Open && net.security !== WifiSecurityType.Owe
    }

    function connectSelected() {
        if (networks.length === 0)
            return
        const net = networks[selected]
        pendingNetwork = net
        notice = ""
        if (askingPassword) {
            net.connectWithPsk(secret.text)
            askingPassword = false
            secret.text = ""
            notice = "CONNECTING " + net.name
            connectionTimeout.restart()
            return
        }
        if (needsPassword(net)) {
            askingPassword = true
            secret.text = ""
            secret.forceActiveFocus()
            return
        }
        net.connect()
        notice = "CONNECTING " + net.name
        connectionTimeout.restart()
    }

    function loadSaved() {
        savedLister.command = ["python3", Quickshell.shellPath("../scripts/nm-connections.py"), "list"]
        savedLister.running = true
    }

    function savedAction(verb) {
        if (saved.length === 0)
            return
        const item = saved[savedSelected]
        if (verb === "delete" && !confirmForget) {
            confirmForget = true
            notice = "FORGET " + item.name + "?"
            return
        }
        confirmForget = false
        savedRunner.command = ["python3", Quickshell.shellPath("../scripts/nm-connections.py"), verb, item.name]
        savedRunner.running = true
    }

    function move(delta) {
        if (networks.length === 0)
            return
        selected = (selected + delta + networks.length) % networks.length
        askingPassword = false
    }

    screen: modelScreen
    visible: ShellState.networkOpen && onFocusedScreen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sentinel-network"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    onVisibleChanged: {
        if (!visible)
            return
        askingPassword = false
        pendingNetwork = null
        confirmForget = false
        notice = ""
        refresh()
        loadSaved()
        focusItem.forceActiveFocus()
    }

    Timer {
        interval: 4000
        repeat: true
        running: root.visible
        onTriggered: root.refresh()
    }

    Timer {
        id: connectionTimeout
        interval: 20000
        onTriggered: {
            if (root.pendingNetwork && !root.pendingNetwork.connected)
                root.notice = "CONNECTION TIMED OUT"
        }
    }

    Connections {
        target: root.pendingNetwork
        ignoreUnknownSignals: true

        function onConnectedChanged() {
            if (root.pendingNetwork && root.pendingNetwork.connected) {
                connectionTimeout.stop()
                root.notice = "CONNECTED " + root.pendingNetwork.name
                root.askingPassword = false
            }
        }

        function onConnectionFailed(reason) {
            connectionTimeout.stop()
            root.notice = "CONNECTION FAILED (" + reason + ")"
            root.askingPassword = root.pendingNetwork
                && root.pendingNetwork.security !== WifiSecurityType.Open
                && root.pendingNetwork.security !== WifiSecurityType.Owe
            secret.text = ""
            if (root.askingPassword)
                secret.forceActiveFocus()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.networkOpen = false
    }

    HudPanel {
        id: panel
        width: 560
        height: column.implicitHeight + 28
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.16

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "NETWORK"
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: 12
                    font.letterSpacing: 2
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.page === "saved" ? "SAVED" : (!root.wifiAvailable ? "NO WIFI"
                        : (Networking.wifiEnabled ? "WIFI ON" : "WIFI OFF"))
                    color: root.wifiAvailable && Networking.wifiEnabled ? Theme.accent : Theme.warn
                    font.family: Theme.mono
                    font.pixelSize: 11
                }
            }

            Text {
                text: root.wiredSummary()
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: 10
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.border
            }

            Text {
                visible: root.page === "wifi" && root.networks.length === 0
                text: !root.wifiAvailable ? "NO WIFI ADAPTER"
                    : (Networking.wifiEnabled ? "SCANNING" : "WIFI DISABLED")
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: 11
            }

            Repeater {
                model: root.page === "wifi" ? root.networks : []
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    height: 28
                    color: index === root.selected ? Theme.accentDim : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        Text {
                            text: modelData.connected ? "●" : "○"
                            color: modelData.connected ? Theme.accent : Theme.muted
                            font.pixelSize: 10
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: Theme.text
                            font.family: Theme.mono
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Text {
                            text: Math.round(modelData.signalStrength || 0) + "%"
                            color: Theme.muted
                            font.family: Theme.mono
                            font.pixelSize: 10
                        }
                        Text {
                            text: modelData.known ? "SAVED" : (root.needsPassword(modelData) ? "KEY" : "OPEN")
                            color: Theme.muted
                            font.family: Theme.mono
                            font.pixelSize: 10
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.selected = index
                            root.connectSelected()
                        }
                    }
                }
            }

            Text {
                visible: root.page === "saved" && root.saved.length === 0
                text: "NO SAVED CONNECTIONS"
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: 11
            }

            Repeater {
                model: root.page === "saved" ? root.saved : []
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    height: 28
                    color: index === root.savedSelected ? Theme.accentDim : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        Text {
                            text: modelData.active ? "●" : "○"
                            color: modelData.active ? Theme.accent : Theme.muted
                            font.pixelSize: 10
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: Theme.text
                            font.family: Theme.mono
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.vpn ? "VPN" : (modelData.type.indexOf("ethernet") >= 0 ? "ETH" : "WIFI")
                            color: Theme.muted
                            font.family: Theme.mono
                            font.pixelSize: 10
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.savedSelected = index
                            root.savedAction(modelData.active ? "down" : "up")
                        }
                    }
                }
            }

            TextInput {
                id: secret
                visible: root.askingPassword
                Layout.fillWidth: true
                echoMode: TextInput.Password
                color: Theme.text
                font.family: Theme.mono
                font.pixelSize: 14
                clip: true
                Keys.onPressed: event => root.handleKey(event)
                onVisibleChanged: if (visible) forceActiveFocus()
            }

            Text {
                visible: root.notice.length > 0 || root.askingPassword
                text: root.askingPassword ? "ENTER WIFI KEY" : root.notice
                color: root.askingPassword ? Theme.warn : Theme.muted
                font.family: Theme.mono
                font.pixelSize: 10
            }

            Text {
                text: root.page === "saved"
                    ? "ENTER CONNECT   D DISCONNECT   F FORGET   TAB WIFI   ESC CLOSE"
                    : "ENTER CONNECT   W WIFI   TAB SAVED   ↑/↓ SELECT   ESC CLOSE"
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: 9
                font.letterSpacing: 1
            }
        }
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            if (askingPassword)
                askingPassword = false
            else
                ShellState.networkOpen = false
        } else if (event.key === Qt.Key_Tab && !askingPassword) {
            page = page === "wifi" ? "saved" : "wifi"
            confirmForget = false
            if (page === "saved")
                loadSaved()
        } else if (page === "saved" && !askingPassword && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            savedAction("up")
        } else if (page === "saved" && !askingPassword && event.key === Qt.Key_D) {
            savedAction("down")
        } else if (page === "saved" && !askingPassword && event.key === Qt.Key_F) {
            savedAction("delete")
        } else if (page === "saved" && !askingPassword && event.key === Qt.Key_Down && saved.length > 0) {
            savedSelected = (savedSelected + 1) % saved.length
            confirmForget = false
        } else if (page === "saved" && !askingPassword && event.key === Qt.Key_Up && saved.length > 0) {
            savedSelected = (savedSelected - 1 + saved.length) % saved.length
            confirmForget = false
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            connectSelected()
        } else if (page !== "saved" && event.key === Qt.Key_Down) {
            move(1)
        } else if (page !== "saved" && event.key === Qt.Key_Up) {
            move(-1)
        } else if (!askingPassword && (event.key === Qt.Key_W || event.key === Qt.Key_Space)) {
            if (!wifiAvailable) {
                notice = "NO WIFI ADAPTER"
                event.accepted = true
                return
            }
            Networking.wifiEnabled = !Networking.wifiEnabled
            notice = Networking.wifiEnabled ? "WIFI ENABLED" : "WIFI DISABLED"
            refresh()
        } else if (askingPassword) {
            return
        } else {
            return
        }
        event.accepted = true
    }

    Process {
        id: savedLister
        stdout: StdioCollector {
            onStreamFinished: {
                let parsed
                try {
                    parsed = JSON.parse(text)
                } catch (error) {
                    root.notice = "SAVED LIST FAILED"
                    return
                }
                root.saved = parsed.connections || []
                if (root.savedSelected >= root.saved.length)
                    root.savedSelected = 0
                if (parsed.error)
                    root.notice = parsed.error
            }
        }
    }

    Process {
        id: savedRunner
        stdout: StdioCollector {
            onStreamFinished: {
                let parsed
                try {
                    parsed = JSON.parse(text)
                } catch (error) {
                    root.notice = "CONNECTION FAILED"
                    return
                }
                root.notice = parsed.error || parsed.status || "OK"
                root.loadSaved()
            }
        }
    }

    Item {
        id: focusItem
        focus: !root.askingPassword
        Keys.onPressed: event => root.handleKey(event)
    }
}
