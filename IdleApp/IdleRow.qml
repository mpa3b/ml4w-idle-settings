import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.IdleApp

// One timer row: an on/off switch, a 5-minute stepper and a field for typing an
// exact value. All three only stage the change; "Применить" writes the file.
RowLayout {
    id: row

    property string title: ""
    property string detail: ""
    property int minutes: 0
    property bool timerEnabled: true
    property bool canLess: true
    property bool canMore: true

    signal decrease()
    signal increase()
    signal toggledTo(bool on)
    signal valueEntered(int minutes)

    Layout.fillWidth: true
    Layout.preferredHeight: 38
    spacing: 10
    opacity: row.timerEnabled ? 1 : 0.62

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Text {
            text: row.title
            color: IdleTheme.onSurface
            font.pixelSize: 14
            renderType: Text.NativeRendering
        }
        Text {
            text: row.timerEnabled ? row.detail : "выключено — не срабатывает"
            color: IdleTheme.onSurfaceVariant
            font.pixelSize: 12
            renderType: Text.NativeRendering
        }
    }

    IdleToggle {
        value: row.timerEnabled
        onToggledTo: (on) => row.toggledTo(on)
    }

    TextField {
        id: field
        implicitWidth: 54
        width: 54
        implicitHeight: 32
        text: row.minutes
        enabled: row.timerEnabled
        horizontalAlignment: TextInput.AlignHCenter
        color: IdleTheme.onSurface
        font.pixelSize: 14
        padding: 4
        validator: IntValidator { bottom: 1; top: 10080 }
        background: Rectangle {
            radius: 8
            color: "transparent"
            border.color: field.activeFocus ? IdleTheme.primary : IdleTheme.outline
            border.width: field.activeFocus ? 2 : 1
        }
        onEditingFinished: {
            const entered = parseInt(field.text, 10)
            if (isNaN(entered) || entered < 1) {
                field.text = Qt.binding(() => row.minutes)
                return
            }
            row.valueEntered(entered)
            field.text = Qt.binding(() => row.minutes)
        }
    }

    Text {
        text: "мин"
        color: IdleTheme.onSurfaceVariant
        font.pixelSize: 12
        renderType: Text.NativeRendering
    }

    IdleIconButton {
        buttonSize: 30
        glyph: "−"
        interactive: row.timerEnabled && row.canLess
        onClicked: row.decrease()
    }
    IdleIconButton {
        buttonSize: 30
        glyph: "+"
        interactive: row.timerEnabled && row.canMore
        onClicked: row.increase()
    }
}
