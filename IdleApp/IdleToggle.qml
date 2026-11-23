import QtQuick
import QtQuick.Controls
import qs.IdleApp

// Themed on/off switch. It reports the requested state through toggledTo()
// instead of owning it, so a change made elsewhere (a keybinding or a config
// reload) is still reflected in the checked state.
Switch {
    id: control

    property bool value: false

    signal toggledTo(bool on)

    checked: control.value
    onToggled: {
        control.toggledTo(control.checked)
        control.checked = Qt.binding(() => control.value)
    }

    implicitWidth: 44
    implicitHeight: 24

    indicator: Rectangle {
        implicitWidth: 44
        implicitHeight: 24
        radius: 12
        color: control.checked ? IdleTheme.primary : "transparent"
        border.color: IdleTheme.primary
        border.width: 1

        Rectangle {
            x: control.checked ? parent.width - width - 3 : 3
            y: 3
            implicitWidth: 18
            implicitHeight: 18
            radius: 9
            color: control.checked ? IdleTheme.onPrimary : IdleTheme.primary
            Behavior on x {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}
