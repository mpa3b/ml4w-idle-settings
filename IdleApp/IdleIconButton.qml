import QtQuick
import qs.IdleApp

// Small square button used for the row steppers and the panel's close control.
// 8 px corners match the rest of the shell's in-app controls; a disabled
// control only loses opacity, it never changes shape or variant.
Rectangle {
    id: button

    property string glyph: ""
    property bool interactive: true
    property int buttonSize: 28

    signal clicked()

    implicitWidth: buttonSize
    implicitHeight: buttonSize
    width: buttonSize
    height: buttonSize
    radius: 8

    opacity: interactive ? 1 : 0.35
    color: area.containsMouse && interactive
        ? Qt.rgba(IdleTheme.primary.r, IdleTheme.primary.g, IdleTheme.primary.b, 0.18)
        : "transparent"
    border.color: IdleTheme.outline
    border.width: 1

    Text {
        anchors.centerIn: parent
        text: button.glyph
        color: IdleTheme.onSurface
        font.pixelSize: button.buttonSize >= 32 ? 17 : 15
        renderType: Text.NativeRendering
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: button.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (button.interactive)
                button.clicked()
        }
    }
}
