pragma Singleton

import QtQuick
import Quickshell

// Shell-wide UI state toggled through IPC (see session/sentinel-ctl).
Singleton {
    property bool launcherOpen: false
    property bool dashboardOpen: false
    property bool locked: false
    property bool networkOpen: false
    property bool filesOpen: false
    property bool powerOpen: false
    property bool audioOpen: false
    property bool bluetoothOpen: false
    property bool displayOpen: false
    property string wallpaperPath: ""

    function closeMenus() {
        launcherOpen = false
        networkOpen = false
        filesOpen = false
        powerOpen = false
        audioOpen = false
        bluetoothOpen = false
        displayOpen = false
    }

    function menuOpen(name) {
        if (name === "launcher")
            return launcherOpen
        if (name === "network")
            return networkOpen
        if (name === "files")
            return filesOpen
        if (name === "power")
            return powerOpen
        if (name === "audio")
            return audioOpen
        if (name === "bluetooth")
            return bluetoothOpen
        if (name === "display")
            return displayOpen
        return false
    }

    function show(name) {
        closeMenus()
        if (name === "launcher")
            launcherOpen = true
        else if (name === "network")
            networkOpen = true
        else if (name === "files")
            filesOpen = true
        else if (name === "power")
            powerOpen = true
        else if (name === "audio")
            audioOpen = true
        else if (name === "bluetooth")
            bluetoothOpen = true
        else if (name === "display")
            displayOpen = true
    }

    function toggle(name) {
        if (menuOpen(name))
            closeMenus()
        else
            show(name)
    }

    onLockedChanged: if (locked) closeMenus()
}
