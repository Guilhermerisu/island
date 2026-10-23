import QtQuick

// The surface the Settings widget cards (System Stats, Agents) sit on: an
// iOS widget's rounded panel, a touch lighter at the top, with a hairline edge;
// or, with `flat`, a System Settings group box like the other panes' groups.
Rectangle {
  required property var view
  property bool flat: false
  radius: view.host.theme.radii.card
  color: view.card
  gradient: flat ? null : widget
  Gradient {
    id: widget
    GradientStop { position: 0; color: view.host.theme.solid("raised") }
    GradientStop { position: 1; color: view.host.theme.solid("quiet") }
  }
  border.width: 1
  border.color: flat ? view.edge : view.host.theme.fill("subtle")
}
