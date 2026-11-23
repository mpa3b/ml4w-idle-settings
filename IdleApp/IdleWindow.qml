import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.IdleApp

// Modal panel for hypridle's four idle timers plus the two runtime switches
// (hypridle itself and Caffeine). Timer changes are staged and written together
// with "Применить"; the switches take effect immediately.
PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ml4w-idle-settings"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Only the card is interactive; the rest of the surface is a click-away
    // backdrop while open, and a fully transparent pass-through while closing.
    visible: isOpen || fadeAnim.running
    mask: isOpen ? null : emptyMask

    Region {
        id: emptyMask
    }

    property bool isOpen: false
    property var staged: ({ dim: 8, lock: 10, screenOff: 11, suspend: 30 })
    property var enabled: ({ dim: true, lock: true, screenOff: true, suspend: true })
    property bool dirty: false
    property string notice: ""
    readonly property string message: IdleConfig.error !== ""
        ? "Ошибка: " + IdleConfig.error : root.notice

    function toMinutes(seconds): int {
        return seconds > 0 ? Math.max(1, Math.round(seconds / 60)) : 1
    }

    function openPanel(): void {
        const values = IdleConfig.timeouts
        staged = {
            dim: toMinutes(values.dim),
            lock: toMinutes(values.lock),
            screenOff: toMinutes(values.screenOff),
            suspend: toMinutes(values.suspend)
        }
        enabled = Object.assign({}, IdleConfig.enabled)
        dirty = false
        notice = ""
        isOpen = true
        card.forceActiveFocus()
        IdleConfig.refresh()
        IdleConfig.refreshRuntime()
    }

    function closePanel(): void {
        isOpen = false
    }

    // Keep the enabled timers in the order hypridle fires them: dim, lock,
    // screen off, suspend. Disabled timers are skipped, so switching off the
    // lock or the suspend timer removes its constraint on the others.
    function bounds(id): array {
        const order = ["dim", "lock", "screenOff", "suspend"]
        const index = order.indexOf(id)
        let low = 1
        let high = 10080
        for (let i = index - 1; i >= 0; i--) {
            const key = order[i]
            if (root.enabled[key]) {
                low = root.staged[key] + (key === "screenOff" && id === "suspend" ? 5 : 0)
                break
            }
        }
        for (let i = index + 1; i < order.length; i++) {
            const key = order[i]
            if (root.enabled[key]) {
                high = root.staged[key] - (key === "suspend" ? 5 : 0)
                break
            }
        }
        high = Math.max(low, high)
        return [low, high]
    }

    function setValue(id, minutes): void {
        const range = bounds(id)
        const next = Math.max(range[0], Math.min(range[1], Math.round(minutes)))
        if (next === root.staged[id])
            return
        let values = Object.assign({}, root.staged)
        values[id] = next
        staged = values
        dirty = true
        notice = ""
    }

    function step(id, delta): void {
        setValue(id, root.staged[id] + delta)
    }

    function toggleTimer(id, on): void {
        let flags = Object.assign({}, root.enabled)
        flags[id] = on
        enabled = flags
        dirty = true
        notice = ""
    }

    function apply(): void {
        if (!dirty || IdleConfig.busy)
            return
        IdleConfig.setAll({
            dim: root.staged.dim * 60,
            lock: root.staged.lock * 60,
            screenOff: root.staged.screenOff * 60,
            suspend: root.staged.suspend * 60
        }, root.enabled)
        dirty = false
        notice = "Сохранено — hypridle перезапущен"
    }

    function reset(): void {
        staged = { dim: 8, lock: 10, screenOff: 11, suspend: 30 }
        enabled = { dim: true, lock: true, screenOff: true, suspend: true }
        dirty = true
        notice = ""
    }

    onNoticeChanged: if (notice !== "") noticeTimer.restart()
    Timer {
        id: noticeTimer
        interval: 5000
        onTriggered: root.notice = ""
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        onClicked: root.closePanel()
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.closePanel()
    }

    IpcHandler {
        target: "idle"
        function toggle(): void { root.isOpen ? root.closePanel() : root.openPanel() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
        function status(): string { return root.isOpen ? "open" : "closed" }
    }

    Rectangle {
        id: card
        width: 480
        implicitHeight: content.implicitHeight + 48
        radius: 18
        anchors.centerIn: parent
        opacity: root.isOpen ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                id: fadeAnim
                duration: 160
                easing.type: Easing.OutQuad
            }
        }

        color: Qt.rgba(IdleTheme.background.r, IdleTheme.background.g,
                       IdleTheme.background.b, IdleTheme.cardOpacity)
        border.color: Qt.rgba(IdleTheme.outline.r, IdleTheme.outline.g,
                              IdleTheme.outline.b, 0.5)
        border.width: 1

        focus: true
        MouseArea {
            anchors.fill: parent
        }

        RectangularShadow {
            anchors.fill: parent
            radius: card.radius
            blur: 24
            color: Qt.rgba(IdleTheme.shadow.r, IdleTheme.shadow.g,
                           IdleTheme.shadow.b, 0.35)
        }

        ColumnLayout {
            id: content
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 24
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.rightMargin: 44
                    spacing: 4

                    Text {
                        text: "Таймеры бездействия"
                        color: IdleTheme.onSurface
                        font.pixelSize: 18
                        font.bold: true
                        renderType: Text.NativeRendering
                    }
                    Text {
                        text: "Экран, блокировка и сон — по времени бездействия"
                        color: IdleTheme.onSurfaceVariant
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                    }
                }

            }

            // Live state: a dot plus a word, so state is never colour alone.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: status.implicitHeight + 24
                radius: 12
                color: Qt.rgba(IdleTheme.surfaceContainer.r, IdleTheme.surfaceContainer.g,
                               IdleTheme.surfaceContainer.b, 0.85)

                ColumnLayout {
                    id: status
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: IdleConfig.hypridleRunning ? IdleTheme.primary : IdleTheme.outline
                        }
                        Text {
                            text: IdleConfig.hypridleRunning
                                ? "hypridle работает" : "hypridle остановлен"
                            color: IdleTheme.onSurface
                            font.pixelSize: 13
                            renderType: Text.NativeRendering
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: IdleConfig.caffeineOn ? IdleTheme.primary : IdleTheme.outline
                        }
                        Text {
                            text: IdleConfig.caffeineOn
                                ? "Caffeine включён — таймеры приостановлены"
                                : "Caffeine выключен"
                            color: IdleTheme.onSurface
                            font.pixelSize: 13
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }

            IdleSection {
                label: "Когда срабатывает"
            }

            IdleRow {
                title: "Приглушить экран"
                detail: "яркость на минимум"
                minutes: root.staged.dim
                timerEnabled: root.enabled.dim
                canLess: root.staged.dim > root.bounds("dim")[0]
                canMore: root.staged.dim < root.bounds("dim")[1]
                onDecrease: root.step("dim", -5)
                onIncrease: root.step("dim", 5)
                onToggledTo: (on) => root.toggleTimer("dim", on)
                onValueEntered: (minutes) => root.setValue("dim", minutes)
            }
            IdleRow {
                title: "Блокировка экрана"
                detail: "hyprlock"
                minutes: root.staged.lock
                timerEnabled: root.enabled.lock
                canLess: root.staged.lock > root.bounds("lock")[0]
                canMore: root.staged.lock < root.bounds("lock")[1]
                onDecrease: root.step("lock", -5)
                onIncrease: root.step("lock", 5)
                onToggledTo: (on) => root.toggleTimer("lock", on)
                onValueEntered: (minutes) => root.setValue("lock", minutes)
            }
            IdleRow {
                title: "Выключить экран"
                detail: "DPMS, экран просыпается от ввода"
                minutes: root.staged.screenOff
                timerEnabled: root.enabled.screenOff
                canLess: root.staged.screenOff > root.bounds("screenOff")[0]
                canMore: root.staged.screenOff < root.bounds("screenOff")[1]
                onDecrease: root.step("screenOff", -5)
                onIncrease: root.step("screenOff", 5)
                onToggledTo: (on) => root.toggleTimer("screenOff", on)
                onValueEntered: (minutes) => root.setValue("screenOff", minutes)
            }
            IdleRow {
                title: "Перевести в сон"
                detail: "suspend (не полное выключение)"
                minutes: root.staged.suspend
                timerEnabled: root.enabled.suspend
                canLess: root.staged.suspend > root.bounds("suspend")[0]
                canMore: root.staged.suspend < root.bounds("suspend")[1]
                onDecrease: root.step("suspend", -5)
                onIncrease: root.step("suspend", 5)
                onToggledTo: (on) => root.toggleTimer("suspend", on)
                onValueEntered: (minutes) => root.setValue("suspend", minutes)
            }

            IdleSection {
                label: "Сейчас"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Авто-таймеры"
                        color: IdleTheme.onSurface
                        font.pixelSize: 14
                        renderType: Text.NativeRendering
                    }
                    Text {
                        text: "процесс hypridle"
                        color: IdleTheme.onSurfaceVariant
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                    }
                }

                IdleToggle {
                    value: IdleConfig.hypridleRunning
                    onToggledTo: (on) => IdleConfig.setHypridle(on)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Caffeine"
                        color: IdleTheme.onSurface
                        font.pixelSize: 14
                        renderType: Text.NativeRendering
                    }
                    Text {
                        text: "пауза таймеров (SUPER + F8)"
                        color: IdleTheme.onSurfaceVariant
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                    }
                }

                IdleToggle {
                    value: IdleConfig.caffeineOn
                    onToggledTo: (on) => IdleConfig.setCaffeine(on)
                }
            }

            Text {
                text: root.message
                visible: root.message !== ""
                color: IdleConfig.error !== "" ? IdleTheme.error : IdleTheme.primary
                font.pixelSize: 12
                renderType: Text.NativeRendering
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 10

                IdleActionButton {
                    label: "Сбросить"
                    interactive: root.dirty
                    onClicked: root.reset()
                }
                Item {
                    Layout.fillWidth: true
                }
                IdleActionButton {
                    label: "Применить"
                    primary: true
                    interactive: root.dirty && !IdleConfig.busy
                    onClicked: root.apply()
                }
            }
        }

        // Pinned to the window corner, above the header's content.
        IdleIconButton {
            buttonSize: 32
            glyph: "×"
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12
            onClicked: root.closePanel()
        }
    }
}
