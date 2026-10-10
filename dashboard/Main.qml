import Quickshell

// Standalone entry point (run-demo.sh); inside the desktop the shell loads Dashboard directly.
ShellRoot {
    Dashboard {
        onCloseRequested: Qt.quit()
    }
}
