import QtQuick
import QtQuick.Layouts
import qs.IdleApp

// Section heading with a hairline rule. Separating the timed listeners from the
// live switches keeps the panel readable without adding boxes or extra chrome.
ColumnLayout {
    property string label: ""

    Layout.fillWidth: true
    Layout.topMargin: 4
    spacing: 8

    Text {
        text: label
        color: IdleTheme.onSurfaceVariant
        font.pixelSize: 12
        renderType: Text.NativeRendering
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Qt.rgba(IdleTheme.outline.r, IdleTheme.outline.g,
                       IdleTheme.outline.b, 0.35)
    }
}
