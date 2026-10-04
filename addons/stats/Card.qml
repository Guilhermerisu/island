import QtQuick

// The surface every stats card sits on: an iOS widget's rounded panel, a
// touch lighter at the top, with a hairline edge.
Rectangle {
  required property var view
  radius: 20
  gradient: Gradient {
    GradientStop { position: 0; color: Qt.tint(view.panel, view.host.theme.withAlpha(view.text, 0.11)) }
    GradientStop { position: 1; color: Qt.tint(view.panel, view.host.theme.withAlpha(view.text, 0.06)) }
  }
  border.width: 1
  border.color: view.host.theme.withAlpha(view.text, 0.07)
}
