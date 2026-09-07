import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property string moduleName: "jesseburlamaque.thinkpad-battery-protection"
  property string ipcTarget: "jesseburlamaque.thinkpad-battery-protection"

  property bool opened: false
  property bool focusPrimed: false
  property int configuredStop: 85
  property int configuredStart: 75
  property int appliedStop: 85
  property int appliedStart: 75
  property int previewStop: configuredStop
  property int previewStart: configuredStart

  property bool controlAvailable: false
  property bool thinkpadMode: false
  property bool busy: false
  property bool cursorActive: false
  property string errorText: ""

  readonly property string pluginDir: decodeURIComponent(
    Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, ""))
  readonly property string statusHelper: pluginDir + "/system/tbp-helper"

  readonly property var battery: UPower.displayDevice
  readonly property bool batteryPresent: !!(battery && battery.isPresent)
  readonly property int batteryPercent: batteryPresent ? Math.round(battery.percentage * 100) : 0
  readonly property bool isCharging: batteryPresent && battery.state === UPowerDeviceState.Charging
  readonly property string heroIcon: "󱈑"

  function open(payloadJson) {
    opened = true
    cursorActive = false
    focusPrimed = false
    focusPrimeTimer.restart()
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    opened = false
    focusPrimed = false
    focusPrimeTimer.stop()
  }

  function dismiss() {
    close()
    if (shell && typeof shell.hide === "function") {
      shell.hide(manifest ? manifest.id : root.moduleName)
    }
  }

  function toggle() {
    if (opened) dismiss()
    else open()
  }

  function normalizeStop(value) {
    return Math.max(45, Math.min(100, Math.round(Number(value) / 5) * 5))
  }

  function normalizeStart(value) {
    return Math.max(40, Math.min(95, Math.round(Number(value) / 5) * 5))
  }

  function onStopMoved(value) {
    var s = normalizeStop(value)
    previewStop = s
    if (previewStart >= s) {
      previewStart = Math.max(40, s - 5)
    }
  }

  function onStartMoved(value) {
    var r = normalizeStart(value)
    previewStart = r
    if (previewStop <= r) {
      previewStop = Math.min(100, r + 5)
    }
  }

  function parseStatus(raw) {
    var values = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var tab = lines[i].indexOf("\t")
      if (tab > 0) values[lines[i].substring(0, tab)] = lines[i].substring(tab + 1).trim()
    }

    controlAvailable = values.available === "1"
    thinkpadMode = values.thinkpad_mode === "1"
    if (values.configured_stop !== undefined) configuredStop = Number(values.configured_stop)
    if (values.configured_start !== undefined) configuredStart = Number(values.configured_start)
    if (values.applied_stop !== undefined) appliedStop = Number(values.applied_stop)
    if (values.applied_start !== undefined) appliedStart = Number(values.applied_start)

    if (!stopSlider.dragging && !startSlider.dragging) {
      previewStop = configuredStop
      previewStart = configuredStart
    }
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function applyLimits(stopVal, startVal) {
    var s = normalizeStop(stopVal)
    var r = normalizeStart(startVal)
    if (r >= s) r = Math.max(40, s - 5)

    previewStop = s
    previewStart = r

    if (!controlAvailable || busy) return
    busy = true
    errorText = ""
    setProc.command = [
      "pkexec",
      "/usr/local/libexec/tbp-set",
      String(s),
      String(r)
    ]
    setProc.running = true
  }

  function setPreset(stopVal, startVal) {
    applyLimits(stopVal, startVal)
  }

  function summaryText() {
    if (previewStop >= 100) {
      return "Full Charge Mode: battery will charge to 100% capacity."
    }
    if (thinkpadMode) {
      return "Charges to " + previewStop + "%, recharges below " + previewStart + "%."
    }
    return "Battery will stop charging at " + previewStop + "%."
  }

  Component.onCompleted: refresh()

  Timer {
    id: focusPrimeTimer
    interval: 120
    repeat: false
    onTriggered: if (root.opened) root.focusPrimed = true
  }

  Timer {
    interval: 20000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: [root.statusHelper, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStatus(text)
    }
  }

  Process {
    id: setProc
    stderr: StdioCollector { id: setErrors; waitForEnd: true }
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode !== 0) {
        root.errorText = setErrors.text.trim() || "Falha ao salvar limites de carga"
      }
      root.refresh()
    }
  }

  IpcHandler {
    target: root.ipcTarget

    function ping(): string { return "ok" }
    function open(): void { root.open() }
    function close(): void { root.dismiss() }
    function show(): void { root.open() }
    function hide(): void { root.dismiss() }
    function toggle(): void { root.toggle() }

    function getLimits(): string {
      return root.configuredStop + " " + root.configuredStart
    }
  }

  // Pure floating overlay: invisible on top bar
  visible: false
  implicitWidth: 0
  implicitHeight: 0

  // The centered floating window
  PanelWindow {
    id: popupWindow
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "thinkpad-battery-protection-floating"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // Dimmed background overlay (clicking outside closes the card)
    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.45)

      MouseArea {
        anchors.fill: parent
        onClicked: function(mouse) {
          if (!root.focusPrimed) return
          root.dismiss()
        }
      }
    }

    // Centered card
    BorderSurface {
      id: card
      width: Style.space(430)
      height: content.implicitHeight + card.contentTopInset + card.contentBottomInset
      radius: Style.cornerRadius
      anchors.centerIn: parent
      color: Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.popupPadding

      // Swallow clicks on the card so they don't dismiss the window
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
      }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: function(event) {
          if (!root.focusPrimed) return
          root.dismiss()
          event.accepted = true
        }

        Column {
          id: content
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.leftMargin: card.contentLeftInset
          anchors.rightMargin: card.contentRightInset
          anchors.topMargin: card.contentTopInset
          spacing: Style.space(12)

          // Header
          Item {
            width: parent.width
            height: Math.max(heroIconText.implicitHeight, heroLabels.implicitHeight, heroPercent.implicitHeight)

            Text {
              id: heroIconText
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: root.heroIcon
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.display
            }

            Column {
              id: heroLabels
              anchors.left: heroIconText.right
              anchors.leftMargin: Style.space(12)
              anchors.right: heroPercent.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: "ThinkPad Battery Protection"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                text: root.busy
                  ? "APPLYING CHANGES…"
                  : (root.previewStop >= 100 ? "FULL CHARGE MODE" : "PROTECTION ACTIVE")
                color: root.busy ? Color.accent : Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.1
                elide: Text.ElideRight
                width: parent.width
              }
            }

            Column {
              id: heroPercent
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(1)

              Text {
                text: root.thinkpadMode
                  ? root.previewStart + "–" + root.previewStop + "%"
                  : root.previewStop + "%"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
                anchors.right: parent.right
              }

              Text {
                text: (root.isCharging ? "󱐋 " : "") + root.batteryPercent + "% BAT"
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
              }
            }
          }

          PanelSeparator {
            foreground: Color.foreground
          }

          // Summary box
          BorderSurface {
            width: parent.width
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
            borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent)
            radius: Style.cornerRadius
            padding: Style.space(8)

            Text {
              width: parent.width
              text: root.summaryText()
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          // Slider 1: Stop Threshold
          Column {
            width: parent.width
            spacing: Style.space(4)

            Item {
              width: parent.width
              height: Math.max(stopHeader.implicitHeight, stopValueText.implicitHeight)

              PanelSectionHeader {
                id: stopHeader
                text: root.thinkpadMode
                  ? "1. STOP THRESHOLD (CHARGE LIMIT)"
                  : "CHARGE LIMIT"
                foreground: Color.foreground
                fontFamily: Style.font.family
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: stopValueText
                text: root.previewStop + "%"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            CursorSurface {
              id: stopSliderRow
              width: parent.width
              height: stopSlider.implicitHeight + Style.spacing.controlGap
              hasCursor: root.cursorActive
              foreground: Color.foreground
              bordered: true
              outline: true

              PanelSlider {
                id: stopSlider
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                minimum: 45
                maximum: 100
                step: 5
                tickCount: 12
                integer: true
                value: root.previewStop
                trackColor: Style.selectedFillFor(Color.foreground, Color.accent)
                fillColor: Color.accent
                knobColor: Color.foreground
                tickColor: Color.popups.background
                enabled: root.controlAvailable && !root.busy
                onMoved: function(val) { root.onStopMoved(val) }
                onReleased: function(val) { root.applyLimits(val, root.previewStart) }
              }

              HoverHandler {
                onHoveredChanged: if (hovered) root.cursorActive = true
              }
            }
          }

          // Slider 2: Start Threshold (hidden when device lacks dual-threshold support)
          Column {
            width: parent.width
            spacing: Style.space(4)
            visible: root.thinkpadMode

            Item {
              width: parent.width
              height: Math.max(startHeader.implicitHeight, startValueText.implicitHeight)

              PanelSectionHeader {
                id: startHeader
                text: "2. START THRESHOLD (RECHARGE BELOW)"
                foreground: Color.foreground
                fontFamily: Style.font.family
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: startValueText
                text: root.previewStart + "%"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            CursorSurface {
              id: startSliderRow
              width: parent.width
              height: startSlider.implicitHeight + Style.spacing.controlGap
              hasCursor: root.cursorActive
              foreground: Color.foreground
              bordered: true
              outline: true

              PanelSlider {
                id: startSlider
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                minimum: 40
                maximum: 95
                step: 5
                tickCount: 12
                integer: true
                value: root.previewStart
                trackColor: Style.selectedFillFor(Color.foreground, Color.accent)
                fillColor: Color.accent
                knobColor: Color.foreground
                tickColor: Color.popups.background
                enabled: root.controlAvailable && !root.busy && root.thinkpadMode
                onMoved: function(val) { root.onStartMoved(val) }
                onReleased: function(val) { root.applyLimits(root.previewStop, val) }
              }

              HoverHandler {
                onHoveredChanged: if (hovered) root.cursorActive = true
              }
            }
          }

          // Presets
          Column {
            width: parent.width
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "QUICK PRESETS"
              foreground: Color.foreground
              fontFamily: Style.font.family
            }

            Row {
              width: parent.width
              spacing: Style.space(6)

              Button {
                text: root.thinkpadMode ? "Dock (50–60%)" : "Dock (60%)"
                tooltipText: "Best for laptops mostly plugged into a dock"
                fontSize: Style.font.caption
                selected: root.thinkpadMode
                  ? root.previewStart === 50 && root.previewStop === 60
                  : root.previewStop === 60
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(6)
                onClicked: root.setPreset(60, 50)
              }

              Button {
                text: root.thinkpadMode ? "Balanced (75–85%)" : "Balanced (85%)"
                tooltipText: "Great balance of runtime and battery longevity"
                fontSize: Style.font.caption
                selected: root.thinkpadMode
                  ? root.previewStart === 75 && root.previewStop === 85
                  : root.previewStop === 85
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(6)
                onClicked: root.setPreset(85, 75)
              }

              Button {
                text: root.thinkpadMode ? "Travel (95–100%)" : "Travel (100%)"
                tooltipText: "Full charge for when you need to head out"
                fontSize: Style.font.caption
                selected: root.thinkpadMode
                  ? root.previewStart === 95 && root.previewStop === 100
                  : root.previewStop === 100
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(6)
                onClicked: root.setPreset(100, 95)
              }
            }
          }

          // Footer message
          Text {
            id: footerMessage
            width: parent.width
            text: root.errorText !== ""
              ? root.errorText
              : (!root.controlAvailable
                ? "Battery charge control interface not available in the kernel."
                : (!root.thinkpadMode
                  ? "Warning: start threshold not supported by this device's driver."
                  : ""))
            visible: text !== ""
            color: root.errorText !== "" ? Color.urgent : Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
