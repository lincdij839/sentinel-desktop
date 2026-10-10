import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland

Scope {
    id: root

    property string pending: ""
    property string notice: ""
    property bool busy: false

    function submit(password) {
        if (busy || password.length === 0)
            return
        pending = password
        notice = ""
        busy = true
        pam.start()
    }

    PamContext {
        id: pam
        config: "sentinel-lock"
        configDirectory: Quickshell.env("SENTINEL_PAM_DIR") || Quickshell.shellPath("pam")

        onPamMessage: {
            if (responseRequired)
                respond(root.pending)
        }
        onCompleted: result => {
            root.pending = ""
            root.busy = false
            if (result === PamResult.Success) {
                ShellState.locked = false
            } else {
                root.notice = "AUTHENTICATION FAILED"
            }
        }
        onError: {
            root.pending = ""
            root.busy = false
            root.notice = "AUTHENTICATION ERROR"
        }
    }

    WlSessionLock {
        locked: ShellState.locked

        WlSessionLockSurface {
            color: "black"

            Image {
                anchors.fill: parent
                source: ShellState.wallpaperPath.length > 0
                    ? "file://" + ShellState.wallpaperPath
                    : Quickshell.shellPath("../assets/wallpaper.png")
                fillMode: Image.PreserveAspectCrop
                opacity: 0.35
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 14

                ArcReactor {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 150
                }

                Text {
                    id: clock
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(new Date(), "HH:mm")
                    color: Theme.text
                    font.family: Theme.mono
                    font.pixelSize: 64
                    font.bold: true
                    Timer {
                        interval: 1000
                        repeat: true
                        running: true
                        onTriggered: clock.text = Qt.formatDateTime(new Date(), "HH:mm")
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "SESSION LOCKED"
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: 12
                    font.letterSpacing: 2
                }

                HudPanel {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 320
                    Layout.preferredHeight: 40
                    outline: root.notice.length > 0 ? Theme.danger : Theme.border
                    bracketColor: root.notice.length > 0 ? Theme.danger : Theme.accent

                    TextInput {
                        id: field
                        anchors.fill: parent
                        anchors.margins: 10
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.text
                        font.family: Theme.mono
                        font.pixelSize: 14
                        enabled: !root.busy
                        focus: true
                        Component.onCompleted: forceActiveFocus()
                        onAccepted: {
                            root.submit(text)
                            text = ""
                        }
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.busy ? "CHECKING..." : (root.notice.length > 0 ? root.notice : "ENTER PASSWORD")
                    color: root.notice.length > 0 ? Theme.danger : Theme.muted
                    font.family: Theme.mono
                    font.pixelSize: 10
                }
            }
        }
    }
}
