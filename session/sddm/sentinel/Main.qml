import QtQuick
import QtQuick.Controls as QQC

Item {
    id: root
    width: config.ScreenWidth || Screen.width || 1920
    height: config.ScreenHeight || Screen.height || 1080

    property int selectedUser: userModel.count > 0 ? Math.max(0, userModel.lastIndex) : 0
    property int selectedSession: sessionModel.count > 0 ? Math.max(0, sessionModel.lastIndex) : 0

    function currentUserName() {
        if (userModel.count <= 0)
            return ""
        return String(userModel.data(userModel.index(selectedUser, 0), Qt.UserRole + 1) || "")
    }

    function login() {
        const name = currentUserName()
        notice.text = ""
        if (name.length === 0) {
            notice.text = "NO USER"
            return
        }
        if (password.text.length === 0) {
            notice.text = "需要密码"
            password.forceActiveFocus()
            return
        }
        sddm.login(name, password.text, selectedSession)
    }

    Rectangle {
        anchors.fill: parent
        color: "#03090f"
    }

    Image {
        anchors.fill: parent
        source: config.background || "background.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        color: "#8803090f"
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(root.width * 0.4, 420)
        spacing: 14

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "SENTINEL"
            color: "#5ee6ff"
            font.family: "monospace"
            font.pixelSize: 28
            font.letterSpacing: 6
            font.bold: true
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "选择用户并输入密码"
            color: "#7fb4c6"
            font.family: "monospace"
            font.pixelSize: 12
        }

        QQC.ComboBox {
            id: userBox
            width: parent.width
            height: 40
            model: userModel
            currentIndex: root.selectedUser
            textRole: "name"
            onActivated: root.selectedUser = index
            background: Rectangle {
                color: "#d90a1c2a"
                border.color: "#5ee6ff"
                border.width: 1
                radius: 2
            }
            contentItem: Text {
                leftPadding: 12
                text: userBox.displayText.length ? userBox.displayText : root.currentUserName()
                color: "#d9f7ff"
                font.family: "monospace"
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }

        QQC.TextField {
            id: password
            width: parent.width
            height: 40
            echoMode: TextInput.Password
            placeholderText: "密码"
            color: "#d9f7ff"
            placeholderTextColor: "#7fb4c6"
            font.family: "monospace"
            font.pixelSize: 14
            leftPadding: 12
            rightPadding: 12
            background: Rectangle {
                color: "#d90a1c2a"
                border.color: password.activeFocus ? "#5ee6ff" : "#5530b8dc"
                border.width: 1
                radius: 2
            }
            Keys.onReturnPressed: root.login()
            Keys.onEnterPressed: root.login()
        }

        QQC.ComboBox {
            id: sessionBox
            width: parent.width
            height: 36
            model: sessionModel
            currentIndex: root.selectedSession
            textRole: "name"
            onActivated: root.selectedSession = index
            background: Rectangle {
                color: "#d90a1c2a"
                border.color: "#5530b8dc"
                border.width: 1
                radius: 2
            }
            contentItem: Text {
                leftPadding: 12
                text: sessionBox.displayText
                color: "#d9f7ff"
                font.family: "monospace"
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }

        QQC.Button {
            width: parent.width
            height: 40
            text: "登录"
            onClicked: root.login()
            contentItem: Text {
                text: parent.text
                color: "#03090f"
                font.family: "monospace"
                font.pixelSize: 14
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: parent.down ? "#2fa8c8" : "#5ee6ff"
                radius: 2
            }
        }

        Text {
            id: notice
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: "#ff5a4d"
            font.family: "monospace"
            font.pixelSize: 12
            visible: text.length > 0
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            notice.text = "登录失败"
            password.clear()
            password.forceActiveFocus()
        }
        function onLoginSucceeded() {
            notice.text = ""
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
