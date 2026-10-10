import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland

Scope {
    id: root

    readonly property string notice: {
        const flow = agent.flow
        if (!flow)
            return ""
        if (flow.supplementaryIsError && flow.supplementaryMessage.length > 0)
            return flow.supplementaryMessage
        if (flow.failed)
            return "AUTHENTICATION FAILED"
        return ""
    }

    PolkitAgent {
        id: agent
        onAuthenticationRequestStarted: ShellState.closeMenus()
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            required property var modelData
            readonly property bool onFocusedScreen: !Hyprland.focusedMonitor
                || Hyprland.focusedMonitor.name === modelData.name
            readonly property bool asking: agent.isActive && agent.flow !== null

            screen: modelData
            visible: asking && onFocusedScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sentinel-polkit"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "#99030810"

            onVisibleChanged: if (visible) secret.forceActiveFocus()

            HudPanel {
                width: 460
                height: column.implicitHeight + 28
                anchors.centerIn: parent
                outline: root.notice.length > 0 ? Theme.danger : Theme.border
                bracketColor: root.notice.length > 0 ? Theme.danger : Theme.accent

                ColumnLayout {
                    id: column
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    Text {
                        text: "AUTHENTICATION"
                        color: Theme.accent
                        font.family: Theme.mono
                        font.pixelSize: 12
                        font.letterSpacing: 2
                    }
                    Text {
                        Layout.fillWidth: true
                        text: agent.flow ? agent.flow.message : ""
                        wrapMode: Text.WordWrap
                        color: Theme.text
                        font.family: Theme.mono
                        font.pixelSize: 12
                    }
                    Text {
                        visible: agent.flow && agent.flow.actionId.length > 0
                        text: agent.flow ? agent.flow.actionId : ""
                        color: Theme.muted
                        font.family: Theme.mono
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    TextInput {
                        id: secret
                        Layout.fillWidth: true
                        echoMode: agent.flow && agent.flow.responseVisible ? TextInput.Normal : TextInput.Password
                        color: Theme.text
                        font.family: Theme.mono
                        font.pixelSize: 16
                        clip: true
                        enabled: agent.flow ? agent.flow.isResponseRequired : true
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                if (agent.flow)
                                    agent.flow.cancelAuthenticationRequest()
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (agent.flow)
                                    agent.flow.submit(secret.text)
                                secret.text = ""
                            } else {
                                return
                            }
                            event.accepted = true
                        }
                    }
                    Text {
                        visible: root.notice.length > 0
                        text: root.notice
                        color: Theme.danger
                        font.family: Theme.mono
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "ENTER CONFIRM   ESC CANCEL"
                        color: Theme.muted
                        font.family: Theme.mono
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }
                }
            }
        }
    }

}
