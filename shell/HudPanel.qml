import QtQuick

// Translucent glass panel with thin cyan outline and corner brackets.
Rectangle {
    id: panel

    property color bracketColor: Theme.accent
    property int bracketSize: 12
    property color outline: Theme.border

    color: Theme.panel
    border.color: outline
    border.width: 1
    radius: Theme.radius

    component Bracket: Item {
        property bool atRight: false
        property bool atBottom: false
        width: panel.bracketSize
        height: panel.bracketSize
        x: atRight ? panel.width - width : 0
        y: atBottom ? panel.height - height : 0

        Rectangle {
            width: parent.width
            height: 2
            y: atBottom ? parent.height - 2 : 0
            color: panel.bracketColor
        }
        Rectangle {
            width: 2
            height: parent.height
            x: atRight ? parent.width - 2 : 0
            color: panel.bracketColor
        }
    }

    Bracket {}
    Bracket { atRight: true }
    Bracket { atBottom: true }
    Bracket { atRight: true; atBottom: true }
}
