import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Keyboard-capable popup used when the optional bar icon is hidden. It keeps
// the same surface styling and focus behavior as KeyboardPanel, but places the
// card in the center of the anchor's screen instead of beside the bar.
PanelWindow {
  id: root

  required property Item anchorItem
  required property QtObject bar
  property var owner: null
  property bool open: false
  property Item focusTarget: null
  property int padding: Style.spacing.popupPadding
  property int contentWidth: Style.space(420)
  property int contentHeight: Style.space(260)
  property var borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
  property bool focusPrimed: false

  default property alias contentItem: contentHolder.children

  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  readonly property int verticalContentInset: padding * 2 + Border.top(borderSpec) + Border.bottom(borderSpec)

  function fittedContentWidth(width, cap) {
    var desired = Math.max(1, Number(width) || 1)
    var available = root.width > 0 ? Math.max(120, root.width - Style.gapsOut * 2) : desired
    if (cap !== undefined && Number(cap) > 0) available = Math.min(available, Number(cap))
    return Math.round(Math.min(desired, available))
  }

  function fittedContentHeight(implicitHeight, cap) {
    var desired = Math.max(verticalContentInset, (Number(implicitHeight) || 0) + verticalContentInset)
    var available = root.height > 0 ? Math.max(120, root.height - Style.gapsOut * 2) : desired
    if (cap !== undefined && Number(cap) > 0) available = Math.min(available, Number(cap))
    return Math.round(Math.min(desired, available))
  }

  function close() {
    if (owner && "close" in owner) owner.close()
    else open = false
  }

  screen: anchorWindow ? anchorWindow.screen : null
  visible: open || card.opacity > 0
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore

  WlrLayershell.namespace: "thinkcharge-popup"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open
    ? (focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
    : WlrKeyboardFocus.None

  anchors { top: true; bottom: true; left: true; right: true }
  mask: Region { width: root.width; height: root.height }

  onOpenChanged: {
    if (open) {
      focusPrimed = false
      focusPrimeTimer.restart()
      if (bar && typeof bar.requestPopout === "function") bar.requestPopout(owner || root)
      if (focusTarget) Qt.callLater(function() {
        if (root.open && root.focusTarget) root.focusTarget.forceActiveFocus()
      })
    } else {
      focusPrimeTimer.stop()
      focusPrimed = false
      if (bar && bar.activePopout === (owner || root) && typeof bar.releasePopout === "function")
        bar.releasePopout(owner || root)
    }
  }

  Timer {
    id: focusPrimeTimer
    interval: 75
    onTriggered: if (root.open) root.focusPrimed = true
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.open
    acceptedButtons: Qt.AllButtons
    onClicked: root.close()
  }

  BorderSurface {
    id: card
    x: Math.round((root.width - width) / 2)
    y: Math.round((root.height - height) / 2)
    width: root.contentWidth
    height: root.contentHeight
    color: Color.popups.background
    borderSpec: root.borderSpec
    padding: root.padding
    radius: Style.cornerRadius
    opacity: root.open ? 1 : 0

    Behavior on opacity {
      NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
    }

    Item {
      id: contentHolder
      anchors.fill: parent
      anchors.topMargin: card.contentTopInset
      anchors.rightMargin: card.contentRightInset
      anchors.bottomMargin: card.contentBottomInset
      anchors.leftMargin: card.contentLeftInset
    }
  }
}
