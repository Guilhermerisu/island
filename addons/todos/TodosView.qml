pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import "../../components"
import "Todos.js" as Todos

FocusScope {
  id: view
  required property var todo
  property bool active: false
  readonly property var host: todo.host
  readonly property var theme: host.theme
  readonly property color actionInk: todo.priorityColor("low")
  readonly property var tabs: Todos.tabOptions()
  readonly property var priorities: Todos.priorityOptions()
  readonly property var matches: Todos.listed(todo.tasks, search.text, todo.activeTab)
  readonly property var selected: todo.tasks.find(task => task.id === selectedId)
  readonly property bool hasCompleted: Todos.countStatus(todo.tasks, "complete") > 0
  property string page: "list"
  property string selectedId: ""
  property string draftPriority: "medium"
  property string confirmAction: ""
  property string afterSave: ""

  implicitHeight: panel.implicitHeight

  onActiveChanged: if (active) Qt.callLater(view.focusPage)
  Component.onCompleted: if (active) Qt.callLater(view.focusPage)

  function focusPage() {
    if (!active) return
    if (page === "editor") titleInput.forceActiveFocus()
    else shortcuts.forceActiveFocus()
  }

  Item { id: shortcuts }

  function openTask(task) {
    selectedId = task.id
    page = "details"
    focusPage()
  }

  function edit(task) {
    if (todo.loadState !== "ready" || (task && !todo.writable)) return
    selectedId = task ? task.id : ""
    titleInput.text = task ? task.title : ""
    notes.text = task ? task.description : ""
    draftPriority = task ? task.priority : "medium"
    page = "editor"
    Qt.callLater(view.focusPage)
  }

  function showPage(next) {
    confirmAction = ""
    page = next
    focusPage()
  }

  function saveEditor() {
    if (!todo.writable || !Todos.trim(titleInput.text)) return
    if (selectedId && !selected) {
      showPage("list")
      return
    }
    afterSave = selected ? "details" : "list"
    if (!todo.saveTask(selected, titleInput.text, notes.text, draftPriority)) {
      showPage(afterSave)
      afterSave = ""
    }
  }

  function removeConfirmed() {
    if (!todo.writable || (confirmAction === "remove" && !selected)) return
    afterSave = "list"
    if (confirmAction === "clear" ? !todo.clearCompleted() : !todo.remove(selected)) afterSave = ""
  }

  function goBack() {
    if (afterSave) return
    if (confirmAction) confirmAction = ""
    else if (page === "editor") showPage(selected ? "details" : "list")
    else if (page === "details") showPage("list")
    else host.view = "rest"
  }

  Keys.onEscapePressed: view.goBack()
  Keys.onPressed: function(event) {
    if (page !== "list" || confirmAction || event.modifiers !== Qt.NoModifier) return
    if (event.key === Qt.Key_Slash) search.focusInput()
    else if (event.key === Qt.Key_N) edit(null)
    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right)
      todo.selectTab(Todos.cycleTab(todo.activeTab, event.key === Qt.Key_Right ? 1 : -1))
    else return
    event.accepted = true
  }

  Connections {
    target: view.todo
    function onActiveTabChanged() { list.contentY = 0 }
    function onSaveFinished(success) {
      if (success && view.afterSave) view.showPage(view.afterSave)
      view.afterSave = ""
    }
  }

  component Label: Text {
    color: view.theme.text
    textFormat: Text.PlainText
    property int typeSize: view.theme.size.body
    property string typeFamily: view.theme.textFontFamily
    font.family: typeFamily
    font.pixelSize: typeSize
    font.letterSpacing: view.theme.tracking(typeFamily, typeSize)
  }

  component CheckGlyph: Item {
    id: mark
    property bool checked: false
    required property color ink
    required property int pixelSize
    TextMetrics { id: metrics; font: check.font; text: check.text }
    Text {
      id: check
      x: (mark.width - metrics.tightBoundingRect.width) / 2 - metrics.tightBoundingRect.x
      y: (mark.height - metrics.tightBoundingRect.height) / 2 - metrics.tightBoundingRect.y - baselineOffset
      text: mark.checked ? "󰄳" : "󰄰"
      color: mark.ink
      font.family: view.theme.fontFamily
      font.pixelSize: mark.pixelSize
    }
  }

  component Action: QtControls.AbstractButton {
    id: button
    property string glyph: ""
    property color ink: view.theme.text
    property color fill: view.theme.fill("raised")
    property bool flat: false
    property int minWidth: 36
    implicitWidth: Math.max(minWidth, contentItem.implicitWidth + (glyph ? 16 : 24))
    implicitHeight: 34
    hoverEnabled: true
    opacity: enabled ? 1 : 0.42
    scale: down ? 0.94 : 1
    HoverHandler { enabled: button.enabled; cursorShape: Qt.PointingHandCursor }
    Behavior on scale { MotionAnimation { theme: view.theme; pace: button.down ? "press" : "standard" } }
    background: Rectangle {
      radius: height / 2
      color: button.hovered || button.down ? view.theme.fill("stronger") : button.flat ? "transparent" : button.fill
      border.width: button.visualFocus ? 1 : 0
      border.color: view.theme.accent
      Behavior on color { MotionColorAnimation { theme: view.theme } }
    }
    contentItem: Label {
      text: button.glyph || button.text
      color: button.ink
      typeFamily: button.glyph ? view.theme.fontFamily : view.theme.textFontFamily
      typeSize: button.glyph ? view.theme.px(17) : view.theme.size.subheadline
      font.weight: Font.DemiBold
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }
  }

  component Frame: Rectangle {
    property bool editing: false
    radius: 14
    color: view.theme.fill("subtle")
    border.width: editing ? 1 : 0
    border.color: view.actionInk
  }

  ColumnLayout {
    id: panel
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: 12

    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      Action {
        visible: view.page !== "list"
        glyph: "󰅁"
        text: ("Back")
        enabled: !view.afterSave
        onClicked: view.goBack()
      }
      Rectangle {
        visible: view.page === "list"
        Layout.preferredWidth: 38
        Layout.preferredHeight: 38
        radius: 12
        color: view.theme.withAlpha(view.actionInk, 0.18)
        CheckGlyph {
          anchors.fill: parent
          checked: true
          ink: view.actionInk
          pixelSize: view.theme.px(21)
        }
      }
      Label {
        Layout.fillWidth: true
        text: (view.page === "editor" ? (view.selected ? "Edit task" : "New task")
          : view.page === "details" ? "Task details" : "Priority Todos")
        typeSize: view.theme.px(23)
        font.weight: Font.Bold
        elide: Text.ElideRight
      }
      Action {
        visible: view.page === "list" && !view.confirmAction
        text: ("New task")
        glyph: "󰐕"
        fill: view.theme.withAlpha(view.actionInk, 0.18)
        ink: view.actionInk
        enabled: view.todo.loadState === "ready"
        onClicked: view.edit(null)
      }
      Action {
        visible: view.page === "editor"
        text: ("Save")
        fill: view.theme.withAlpha(view.actionInk, 0.18)
        ink: view.actionInk
        enabled: view.todo.writable && !!Todos.trim(titleInput.text)
        onClicked: view.saveEditor()
      }
    }

    Label {
      Layout.fillWidth: true
      visible: view.todo.error !== ""
      text: (view.todo.error)
      color: view.todo.priorityColor("critical")
      wrapMode: Text.Wrap
      typeSize: view.theme.size.subheadline
    }

    ColumnLayout {
      visible: view.page === "list" && !view.confirmAction
      Layout.fillWidth: true
      spacing: 12

      SearchField {
        id: search
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(36, view.theme.px(14) + 22)
        host: view.host
        placeholder: "Search tasks"
        onKeyPressed: function(event) {
          if (event.key !== Qt.Key_Escape) return
          if (text) clear()
          view.focusPage()
          event.accepted = true
        }
      }

      Frame {
        id: segments
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: 19
        readonly property real cellWidth: (width - 8) / view.tabs.length
        readonly property int selectedIndex: view.tabs.findIndex(tab => tab.value === view.todo.activeTab)
        Rectangle {
          x: 4 + Math.max(0, segments.selectedIndex) * segments.cellWidth
          y: 4
          width: segments.cellWidth
          height: 30
          radius: 15
          color: view.theme.fill("stronger")
          Behavior on x { MotionAnimation { theme: view.theme; pace: "standard" } }
        }
        RowLayout {
          anchors.fill: parent
          anchors.margins: 4
          spacing: 0
          Repeater {
            model: view.tabs
            Action {
              required property var modelData
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              Layout.minimumWidth: 0
              Layout.fillHeight: true
              flat: true
              text: (modelData.label)
              ink: modelData.value === view.todo.activeTab ? view.theme.text : view.theme.secondary
              Accessible.checkable: true
              Accessible.checked: modelData.value === view.todo.activeTab
              onClicked: view.todo.selectTab(modelData.value)
            }
          }
        }
      }

      Frame {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(282, list.contentHeight)
        visible: view.matches.length > 0
        clip: true
        ListView {
          id: list
          anchors.fill: parent
          model: view.matches
          boundsBehavior: Flickable.StopAtBounds
          clip: true
          delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool done: modelData.status === "complete"
            readonly property color priorityInk: view.todo.priorityColor(modelData.priority)
            width: ListView.view.width
            height: modelData.description ? 59 : 51
            Rectangle {
              anchors.fill: parent
              color: taskButton.hovered ? view.theme.fill("quiet") : "transparent"
              Behavior on color { MotionColorAnimation { theme: view.theme } }
            }
            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 12
              spacing: 8
              Action {
                text: (row.done ? "Reopen task" : "Complete task")
                ink: row.priorityInk
                fill: view.theme.withAlpha(ink, 0.16)
                flat: !row.done
                implicitWidth: implicitHeight
                contentItem: CheckGlyph {
                  checked: row.done
                  ink: row.priorityInk
                  pixelSize: view.theme.px(17)
                }
                enabled: view.todo.writable
                onClicked: view.todo.move(row.modelData, row.done ? "ongoing" : "complete")
              }
              QtControls.AbstractButton {
                id: taskButton
                Layout.fillWidth: true
                Layout.fillHeight: true
                hoverEnabled: true
                Accessible.name: row.modelData.title
                onClicked: view.openTask(row.modelData)
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                contentItem: Item {
                  Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 3
                    Label {
                      width: parent.width
                      text: row.modelData.title
                      color: row.done ? view.theme.secondary : view.theme.text
                      font.weight: Font.DemiBold
                      font.strikeout: row.done
                      elide: Text.ElideRight
                    }
                    Label {
                      width: parent.width
                      visible: !!row.modelData.description
                      text: row.modelData.description.replace(/\s+/g, " ")
                      color: view.theme.secondary
                      typeSize: view.theme.size.callout
                      elide: Text.ElideRight
                    }
                  }
                }
              }
              Rectangle {
                Layout.preferredWidth: priorityLabel.implicitWidth + 16
                Layout.preferredHeight: 24
                radius: height / 2
                color: view.theme.withAlpha(row.priorityInk, row.done ? 0.08 : 0.15)
                Label {
                  id: priorityLabel
                  anchors.centerIn: parent
                  text: (Todos.label(row.modelData.priority))
                  color: row.done ? view.theme.secondary : row.priorityInk
                  typeSize: view.theme.size.subheadline
                  font.weight: Font.DemiBold
                }
              }
              Action {
                visible: !row.done
                glyph: row.modelData.status === "backlog" ? "󰐊" : "󰏤"
                text: (row.modelData.status === "backlog" ? "Start task" : "Move to backlog")
                flat: true
                minWidth: 34
                enabled: view.todo.writable
                onClicked: view.todo.move(row.modelData, row.modelData.status === "backlog" ? "ongoing" : "backlog")
              }
            }
            Rectangle {
              visible: row.index < view.matches.length - 1
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: 50
              height: 1
              color: view.theme.hairline
            }
          }
          OverlayScrollbar { parent: list; flickable: list; theme: view.theme }
        }
      }

      Label {
        Layout.fillWidth: true
        Layout.preferredHeight: 62
        visible: view.matches.length === 0 && view.todo.loadState !== "failed"
        text: (view.todo.loadState === "loading" ? "Loading…"
          : Todos.trim(search.text) ? "No matching tasks"
          : view.todo.activeTab === "complete" ? "Nothing completed yet"
          : view.todo.activeTab === "backlog" ? "Nothing in the backlog" : "Nothing ongoing")
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: view.theme.secondary
      }

      Action {
        Layout.alignment: Qt.AlignRight
        visible: view.todo.activeTab === "complete" && view.hasCompleted
        text: ("Clear completed")
        ink: view.todo.priorityColor("critical")
        flat: true
        enabled: view.todo.writable
        onClicked: view.confirmAction = "clear"
      }
    }

    ColumnLayout {
      visible: view.page === "details" && !!view.selected && !view.confirmAction
      Layout.fillWidth: true
      spacing: 12
      Label {
        Layout.fillWidth: true
        text: view.selected?.title || ""
        typeSize: view.theme.px(20)
        font.weight: Font.DemiBold
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
      }
      Label {
        Layout.fillWidth: true
        text: view.selected ? (Todos.statusLabel(view.selected.status)) + " · "
          + (Todos.label(view.selected.priority)) : ""
        color: view.todo.priorityColor(view.selected?.priority || "")
        typeSize: view.theme.size.subheadline
        font.weight: Font.DemiBold
      }
      Frame {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(180, descriptionText.implicitHeight + 24)
        visible: !!view.selected?.description
        clip: true
        Flickable {
          id: descriptionFlick
          anchors.fill: parent
          anchors.margins: 12
          clip: true
          contentHeight: descriptionText.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          Label {
            id: descriptionText
            width: descriptionFlick.width
            wrapMode: Text.Wrap
            text: view.selected?.description || ""
          }
        }
      }
      RowLayout {
        Layout.fillWidth: true
        Action {
          text: ("Edit")
          enabled: view.todo.writable
          onClicked: view.edit(view.selected)
        }
        Action {
          visible: view.selected?.status !== "complete"
          text: (view.selected?.status === "backlog" ? "Start task" : "Move to backlog")
          enabled: view.todo.writable
          onClicked: {
            view.todo.move(view.selected, view.selected.status === "backlog" ? "ongoing" : "backlog")
          }
        }
        Item { Layout.fillWidth: true }
        Action {
          text: ("Delete")
          ink: view.todo.priorityColor("critical")
          enabled: view.todo.writable
          onClicked: view.confirmAction = "remove"
        }
      }
    }

    ColumnLayout {
      visible: view.page === "editor"
      Layout.fillWidth: true
      spacing: 10

      Frame {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        editing: titleInput.activeFocus
        Label {
          anchors.fill: titleInput
          text: ("Task title")
          color: view.theme.placeholder
          visible: !titleInput.text
          verticalAlignment: Text.AlignVCenter
        }
        TextInput {
          id: titleInput
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 12
          clip: true
          selectByMouse: true
          verticalAlignment: TextInput.AlignVCenter
          color: view.theme.text
          selectionColor: view.theme.accentFill("ring")
          selectedTextColor: view.theme.text
          font.family: view.theme.textFontFamily
          font.pixelSize: view.theme.size.body
          KeyNavigation.tab: notes
          onAccepted: view.saveEditor()
          Keys.onEscapePressed: view.goBack()
        }
      }
      Frame {
        Layout.fillWidth: true
        Layout.preferredHeight: 88
        editing: notes.activeFocus
        QtControls.ScrollView {
          anchors.fill: parent
          clip: true
          contentWidth: availableWidth
          QtControls.ScrollBar.horizontal.policy: QtControls.ScrollBar.AlwaysOff
          QtControls.TextArea {
            id: notes
            background: null
            padding: 12
            placeholderText: ("Notes or first step")
            placeholderTextColor: view.theme.placeholder
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            color: view.theme.text
            selectionColor: view.theme.accentFill("ring")
            selectedTextColor: view.theme.text
            font.family: view.theme.textFontFamily
            font.pixelSize: view.theme.size.body
            Keys.onEscapePressed: view.goBack()
            Keys.onPressed: function(event) {
              if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                view.saveEditor()
                event.accepted = true
              }
            }
          }
        }
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
          model: view.priorities
          Action {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            text: (modelData.label)
            ink: view.todo.priorityColor(modelData.value)
            fill: view.theme.withAlpha(ink, view.draftPriority === modelData.value ? 0.23 : 0.08)
            Accessible.checkable: true
            Accessible.checked: view.draftPriority === modelData.value
            onClicked: view.draftPriority = modelData.value
          }
        }
      }
    }

    ColumnLayout {
      visible: view.confirmAction !== ""
      Layout.fillWidth: true
      spacing: 8
      Label {
        Layout.fillWidth: true
        text: (view.confirmAction === "clear" ? "Delete all completed tasks?" : "Delete this task?")
        wrapMode: Text.Wrap
      }
      Label {
        visible: view.confirmAction === "remove"
        Layout.fillWidth: true
        text: view.selected?.title || ""
        color: view.theme.secondary
        elide: Text.ElideRight
      }
      RowLayout {
        Layout.alignment: Qt.AlignRight
        Action {
          text: ("Cancel")
          enabled: !view.afterSave
          onClicked: view.confirmAction = ""
        }
        Action {
          text: ("Delete")
          ink: view.todo.priorityColor("critical")
          fill: view.theme.withAlpha(ink, 0.17)
          enabled: view.todo.writable
          onClicked: view.removeConfirmed()
        }
      }
    }
  }
}
