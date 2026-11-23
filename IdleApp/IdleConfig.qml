pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// State for the idle panel: the four timeouts come from idleconf.py, which
// reads/writes hypridle.conf; hypridle and Caffeine are live processes checked
// every few seconds so the GUI agrees with the SUPER + F8 keybinding.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string helper: home + "/.local/share/ml4w-idle-settings/IdleApp/idleconf.py"
    readonly property string caffeine: home + "/.local/bin/ml4w-caffeine"

    property var timeouts: ({ dim: 0, lock: 0, screenOff: 0, suspend: 0 })
    property var present: ({ dim: false, lock: false, screenOff: false, suspend: false })
    property var enabled: ({ dim: true, lock: true, screenOff: true, suspend: true })
    property bool configReady: false
    property bool hypridleRunning: false
    property bool caffeineOn: false
    property bool busy: false
    property string error: ""

    function refresh(): void {
        if (!getProc.running)
            getProc.running = true
    }

    function applyState(text): void {
        try {
            const parsed = JSON.parse(text)
            let values = {}, available = {}, active = {}
            for (const key of ["dim", "lock", "screenOff", "suspend"]) {
                values[key] = parsed[key] ? parsed[key].seconds : 0
                available[key] = parsed[key] ? parsed[key].present : false
                active[key] = parsed[key] ? parsed[key].enabled : true
            }
            root.timeouts = values
            root.present = available
            root.enabled = active
            root.configReady = true
            root.error = ""
        } catch (e) {
            root.error = "Не удалось прочитать hypridle.conf"
        }
    }

    Process {
        id: getProc
        command: ["python3", root.helper, "get"]
        stdout: StdioCollector {
            onStreamFinished: root.applyState(this.text)
        }
        onExited: (code) => {
            if (code !== 0)
                root.error = "Не удалось прочитать hypridle.conf"
        }
    }

    // Writes all four timeouts and their on/off state in one pass, then reloads
    // hypridle so the new configuration takes effect in the current session.
    function setAll(values, enabled): void {
        let payload = {}
        for (const key of ["dim", "lock", "screenOff", "suspend"])
            payload[key] = { seconds: values[key], enabled: enabled[key] }
        root.busy = true
        writeProc.command = ["python3", root.helper, "set-many", JSON.stringify(payload)]
        writeProc.running = true
    }

    Process {
        id: writeProc
        stdout: StdioCollector {
            onStreamFinished: root.applyState(this.text)
        }
        onExited: (code) => {
            root.busy = false
            if (code === 0) {
                root.restartHypridle()
                root.refreshRuntime()
            } else {
                root.error = "Не удалось сохранить настройки"
            }
        }
    }

    function restartHypridle(): void {
        restartProc.running = true
    }

    Process {
        id: restartProc
        command: ["bash", "-c",
            "pkill -x hypridle 2>/dev/null; sleep 0.3;"
            + " setsid hypridle >/dev/null 2>&1 </dev/null &"]
        onExited: root.refreshRuntime()
    }

    function setHypridle(on): void {
        toggleProc.command = ["bash", "-c", on
            ? "pgrep -x hypridle >/dev/null || setsid hypridle >/dev/null 2>&1 </dev/null &"
            : "pkill -x hypridle 2>/dev/null || true"]
        toggleProc.running = true
    }

    Process {
        id: toggleProc
        onExited: root.refreshRuntime()
    }

    function setCaffeine(on): void {
        caffeineProc.command = [root.caffeine, on ? "on" : "off"]
        caffeineProc.running = true
    }

    Process {
        id: caffeineProc
        onExited: root.refreshRuntime()
    }

    function refreshRuntime(): void {
        if (!pgrepProc.running)
            pgrepProc.running = true
        if (!caffeineStatusProc.running)
            caffeineStatusProc.running = true
    }

    Process {
        id: pgrepProc
        command: ["bash", "-c", "pgrep -x hypridle || true"]
        stdout: StdioCollector {
            onStreamFinished: root.hypridleRunning = this.text.trim().length > 0
        }
    }

    Process {
        id: caffeineStatusProc
        command: [root.caffeine, "status"]
        stdout: StdioCollector {
            onStreamFinished: root.caffeineOn = this.text.trim() === "on"
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: root.refreshRuntime()
    }

    Component.onCompleted: {
        root.refresh()
        root.refreshRuntime()
    }
}
