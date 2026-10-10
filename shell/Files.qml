import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property var modelScreen
    property string path: Quickshell.env("HOME") || "/"
    property string query: ""
    property var entries: []
    property int selected: 0
    property string notice: ""
    property bool showHidden: false
    property bool reloadQueued: false
    property string listingError: ""
    property string clipPath: ""
    property string clipMode: ""
    property bool confirmDelete: false
    property bool placesMode: false
    property var places: []
    readonly property bool onFocusedScreen: !Hyprland.focusedMonitor
        || Hyprland.focusedMonitor.name === modelScreen.name
    readonly property var shown: {
        if (placesMode)
            return places
        const needle = query.trim().toLowerCase()
        return entries.filter(entry => needle.length === 0 || entry.name.toLowerCase().indexOf(needle) >= 0).slice(0, 12)
    }

    function selectedEntry() {
        return shown.length === 0 ? null : shown[selected]
    }

    function selectedPath() {
        const entry = selectedEntry()
        if (!entry)
            return ""
        if (entry.path)
            return entry.path
        return path === "/" ? "/" + entry.name : path + "/" + entry.name
    }

    function loadPlaces() {
        placesMode = true
        query = ""
        confirmDelete = false
        placeLister.command = ["python3", Quickshell.shellPath("../scripts/file-ops.py"), "places"]
        placeLister.running = true
    }

    function mark(mode) {
        const entry = selectedEntry()
        if (!entry || placesMode)
            return
        clipPath = selectedPath()
        clipMode = mode
        confirmDelete = false
        notice = mode.toUpperCase() + " " + entry.name
    }

    function paste() {
        if (clipPath.length === 0 || clipMode.length === 0 || placesMode) {
            notice = "NOTHING TO PASTE"
            return
        }
        runOp([clipMode, clipPath, path])
    }

    function removeSelected() {
        const entry = selectedEntry()
        if (!entry || placesMode)
            return
        if (!confirmDelete) {
            confirmDelete = true
            notice = "DELETE " + entry.name + "?"
            return
        }
        confirmDelete = false
        runOp(["delete", selectedPath()])
    }

    function runOp(args) {
        if (fileOp.running) {
            notice = "BUSY"
            return
        }
        fileOp.command = ["python3", Quickshell.shellPath("../scripts/file-ops.py")].concat(args)
        fileOp.running = true
    }

    function reload() {
        if (lister.running) {
            reloadQueued = true
            lister.running = false
            return
        }
        reloadQueued = false
        listingError = ""
        lister.command = ["python3", Quickshell.shellPath("../scripts/list-dir.py"), path, showHidden ? "--hidden" : "--visible"]
        lister.running = true
    }

    function acceptListing(output) {
        let parsed
        try {
            parsed = JSON.parse(output)
        } catch (error) {
            notice = "UNREADABLE"
            return
        }
        path = parsed.path || path
        notice = parsed.error || ""
        entries = parsed.entries || []
        selected = 0
    }

    function up() {
        if (path === "/")
            return
        const cut = path.lastIndexOf("/")
        path = cut <= 0 ? "/" : path.slice(0, cut)
        query = ""
        reload()
    }

    function openSelected() {
        if (shown.length === 0)
            return
        const entry = shown[selected]
        if (placesMode) {
            path = entry.path
            placesMode = false
            query = ""
            reload()
            return
        }
        const next = path === "/" ? "/" + entry.name : path + "/" + entry.name
        if (entry.dir) {
            path = next
            query = ""
            reload()
            return
        }
        launch(["xdg-open", next], "OPEN")
        ShellState.filesOpen = false
    }

    function openManager() {
        launch(["thunar", path], "THUNAR")
    }

    function launch(command, label) {
        if (opener.running) {
            opener.queued = command
            opener.queuedLabel = label
            return
        }
        opener.actionLabel = label
        opener.command = command
        opener.running = true
    }

    function move(delta) {
        if (shown.length === 0)
            return
        selected = (selected + delta + shown.length) % shown.length
    }

    screen: modelScreen
    visible: ShellState.filesOpen && onFocusedScreen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sentinel-files"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    onVisibleChanged: {
        if (visible) {
            query = ""
            reload()
            filter.forceActiveFocus()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.filesOpen = false
    }

    HudPanel {
        width: 680
        height: Math.min(parent.height * 0.7, column.implicitHeight + 28)
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.14
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "FILES"
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: 12
                    font.letterSpacing: 2
                }
                Text {
                    Layout.fillWidth: true
                    text: root.path
                    color: Theme.muted
                    font.family: Theme.mono
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                }
            }

            TextInput {
                id: filter
                Layout.fillWidth: true
                color: Theme.text
                font.family: Theme.mono
                font.pixelSize: 14
                clip: true
                text: root.query
                onTextChanged: {
                    root.query = text
                    root.selected = 0
                }
                Keys.onShortcutOverride: event => {
                    if ((event.modifiers & Qt.ControlModifier) && (
                        event.key === Qt.Key_C || event.key === Qt.Key_X
                        || event.key === Qt.Key_V || event.key === Qt.Key_G
                        || event.key === Qt.Key_O || event.key === Qt.Key_H))
                        event.accepted = true
                }
                Keys.onPressed: event => root.handleKey(event)
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            Text {
                visible: root.shown.length === 0
                text: root.notice.length > 0 ? root.notice : "EMPTY"
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: 11
            }

            Repeater {
                model: root.shown
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    height: 26
                    color: index === root.selected ? Theme.accentDim : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        Text {
                            text: modelData.kind || (modelData.dir ? "DIR" : "FILE")
                            color: modelData.dir ? Theme.accent : Theme.muted
                            font.family: Theme.mono
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
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.selected = index
                            root.openSelected()
                        }
                    }
                }
            }

            Text {
                text: placesMode
                    ? "ENTER OPEN PLACE   CTRL+G FILES   ESC CLOSE"
                    : "ENTER OPEN   CTRL+C/X/V COPY MOVE PASTE   DEL DELETE   CTRL+G PLACES   CTRL+O MANAGER   ESC CLOSE"
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: 9
                font.letterSpacing: 1
            }
        }
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            ShellState.filesOpen = false
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            openSelected()
        } else if (event.key === Qt.Key_Down) {
            move(1)
        } else if (event.key === Qt.Key_Up) {
            move(-1)
        } else if (event.key === Qt.Key_Backspace && query.length === 0) {
            up()
        } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_O) {
            openManager()
        } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_H) {
            showHidden = !showHidden
            placesMode = false
            reload()
        } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_C) {
            mark("copy")
        } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_X) {
            mark("move")
        } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_V) {
            paste()
        } else if (event.key === Qt.Key_Delete) {
            removeSelected()
        } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_G) {
            if (placesMode) {
                placesMode = false
                reload()
            } else {
                loadPlaces()
            }
        } else {
            return
        }
        event.accepted = true
    }

    Process {
        id: lister
        stdout: StdioCollector {
            onStreamFinished: root.acceptListing(text)
        }
        stderr: StdioCollector {
            onStreamFinished: root.listingError = text.trim()
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.entries = []
                root.notice = root.listingError.length > 0
                    ? root.listingError : "LIST FAILED (" + exitCode + ")"
            }
            if (root.reloadQueued)
                root.reload()
        }
    }

    Process {
        id: placeLister
        stdout: StdioCollector {
            onStreamFinished: {
                let parsed
                try {
                    parsed = JSON.parse(text)
                } catch (error) {
                    root.notice = "PLACES FAILED"
                    return
                }
                root.places = parsed.places || []
                root.selected = 0
                root.notice = parsed.error || ""
            }
        }
    }

    Process {
        id: fileOp
        stdout: StdioCollector {
            onStreamFinished: {
                let parsed
                try {
                    parsed = JSON.parse(text)
                } catch (error) {
                    root.notice = "OPERATION FAILED"
                    return
                }
                root.notice = parsed.error || (parsed.result ? "OK " + parsed.result : "OK")
                if (!parsed.error && parsed.path)
                    root.path = parsed.path
                if (!parsed.error && root.clipMode === "move") {
                    root.clipPath = ""
                    root.clipMode = ""
                }
                root.reload()
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.notice = "OPERATION FAILED (" + exitCode + ")"
        }
    }

    Process {
        id: opener
        property var queued: []
        property string queuedLabel: ""
        property string actionLabel: ""
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                ShellState.filesOpen = true
                root.notice = actionLabel + " FAILED (" + exitCode + ")"
            }
            if (queued.length > 0) {
                command = queued
                actionLabel = queuedLabel
                queued = []
                queuedLabel = ""
                running = true
            }
        }
    }
}
