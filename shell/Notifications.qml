import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland

Scope {
    id: root

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        onNotification: notification => notification.tracked = true
    }

    PanelWindow {
        visible: server.trackedNotifications.values.length > 0
        anchors {
            top: true
            right: true
        }
        margins {
            top: Theme.barHeight + 10
            right: 12
        }
        implicitWidth: 360
        implicitHeight: stack.implicitHeight
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sentinel-notifications"
        color: "transparent"

        ColumnLayout {
            id: stack
            width: parent.width
            spacing: 8

            Repeater {
                model: server.trackedNotifications
                delegate: HudPanel {
                    id: card
                    required property var modelData
                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical

                    Layout.fillWidth: true
                    implicitHeight: content.implicitHeight + 24
                    outline: critical ? Theme.danger : Theme.border
                    bracketColor: critical ? Theme.danger : Theme.accent
                    bracketSize: 9

                    Timer {
                        running: !card.critical
                        interval: card.modelData.expireTimeout > 0 ? card.modelData.expireTimeout * 1000 : 6000
                        onTriggered: card.modelData.expire()
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: card.modelData.dismiss()
                    }

                    ColumnLayout {
                        id: content
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        Text {
                            text: card.modelData.appName.toUpperCase()
                            color: card.critical ? Theme.danger : Theme.accent
                            font.family: Theme.mono
                            font.pixelSize: 9
                            font.letterSpacing: 0.8
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: card.modelData.summary
                            color: Theme.text
                            font.family: Theme.mono
                            font.pixelSize: 13
                            font.bold: true
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: card.modelData.body.length > 0
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            text: card.modelData.body
                            color: Theme.muted
                            font.family: Theme.mono
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
