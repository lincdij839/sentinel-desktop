import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    property bool showing: false

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "keybinds"
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: showing ? scrim : null }

    readonly property var sections: [
        { title: "打开", rows: [
            ["Super + T", "终端"],
            ["Super + Enter", "终端"],
            ["Super + D", "应用启动器"],
            ["Super + S", "应用启动器"],
            ["Super + E", "文件"],
            ["Super + B", "浏览器"]
        ]},
        { title: "桌面", rows: [
            ["Super + K", "快捷键列表"],
            ["Super + Shift + S", "环形菜单"],
            ["Super + I", "设置"],
            ["Super + `", "电源"],
            ["Super + N", "通知"],
            ["Super + C", "待办"],
            ["Super + W", "壁纸"],
            ["Super + Y", "黑白主题"],
            ["Super + O", "透明度"],
            ["Super + Shift + W", "显示或隐藏顶栏"]
        ]},
        { title: "窗口", rows: [
            ["Super + Q", "关闭"],
            ["Super + F", "全屏"],
            ["Super + Space", "浮动并居中"],
            ["Super + Tab", "锁屏"],
            ["Super + V", "剪贴板"],
            ["Super + 左键", "拖动窗口"],
            ["Super + 右键", "缩放窗口"]
        ]},
        { title: "焦点", rows: [
            ["Super + H / J / L", "左 / 下 / 右"],
            ["Super + ↑", "上"],
            ["Super + Shift + H/J/K/L", "移动窗口"],
            ["Super + Ctrl + H/J/K/L", "调整大小"],
            ["Super + 1–0", "切换工作区"],
            ["Super + Shift + 1–0", "窗口送到工作区"]
        ]},
        { title: "其他", rows: [
            ["Delete", "全屏截图"],
            ["Shift + Delete", "区域截图"],
            ["Super + X", "切换输入法"],
            ["Ctrl + Space", "切换输入法"],
            ["Super + R", "开始或停止录屏"],
            ["Super + Shift + E", "退出桌面"]
        ]}
    ]

    function close() { showing = false }

    onShowingChanged: {
        if (showing)
            Qt.callLater(function () { if (root.showing) flick.forceActiveFocus() })
    }

    Item {
        id: scrim
        anchors.fill: parent
        visible: root.showing

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 860)
            height: Math.min(parent.height - 48, 640)
            radius: 16
            color: Theme.bgPanel
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.16)

            MouseArea { anchors.fill: parent }

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                Row {
                    width: parent.width
                    height: title.implicitHeight
                    Text {
                        id: title
                        text: "快捷键"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Esc 关闭"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                Flickable {
                    id: flick
                    width: parent.width
                    height: parent.height - title.implicitHeight - 12
                    contentHeight: grid.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    focus: root.showing

                    Keys.onEscapePressed: root.close()
                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_K && (event.modifiers & Qt.MetaModifier))
                            root.close()
                    }

                    Grid {
                        id: grid
                        width: flick.width
                        columns: width < 640 ? 1 : 2
                        columnSpacing: 28
                        rowSpacing: 16

                        Repeater {
                            model: root.sections
                            delegate: Column {
                                required property var modelData
                                width: grid.columns === 1 ? grid.width : (grid.width - grid.columnSpacing) / 2
                                spacing: 6

                                Text {
                                    text: modelData.title
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                Repeater {
                                    model: modelData.rows
                                    delegate: Row {
                                        required property var modelData
                                        width: parent.width
                                        spacing: 12
                                        Text {
                                            width: 168
                                            text: parent.modelData[0]
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: parent.width - 180
                                            text: parent.modelData[1]
                                            color: Theme.textDim
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
