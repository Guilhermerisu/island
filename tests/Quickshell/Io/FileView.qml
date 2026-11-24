import QtQuick

// Test stand-in for Quickshell.Io's FileView, which lives inside the
// quickshell binary and can't load under qmltestrunner.
QtObject {
  property string path
  property bool watchChanges
  property bool printErrors
  signal loaded()
  signal fileChanged()
  function text() { return "" }
  function reload() {}
}
