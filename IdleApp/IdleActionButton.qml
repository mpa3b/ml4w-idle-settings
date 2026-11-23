import QtQuick
import qs.IdleApp

// Text action: filled for the one primary action of the panel, outlined for a
// secondary one. Disabling only dims it; it never swaps to another variant.
Rectangle {
    id: button

    property string label: ""
    property bool primary: false
    property bool interactive: true

    signal clicked()

    implicitWidth: labelText.implicitWidth + 32
    implicitHeight: 36
    radius: 8

    opacity: interactive ? 1 : 0.4
    color: primary ? IdleTheme.primary : "transparent"
    border.width: 1
    border.color: IdleTheme.primary

    Text {
        id: labelText
        anchors.centerIn: parent
        text: button.label
        color: button.primary ? IdleTheme.onPrimary : IdleTheme.primary
        font.pixelSize: 13
        renderType: Text.NativeRendering
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: button.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (button.interactive)
                button.clicked()
        }
    }
}
