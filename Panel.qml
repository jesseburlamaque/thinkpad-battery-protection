import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui

Panel {
  id: root

  moduleName: "jesseburlamaque.thinkcharge"
  ipcTarget: "jesseburlamaque.thinkcharge"
  manageIpc: false

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
  property bool iconOverrideActive: false
  property bool iconOverrideValue: false
  property string errorText: ""

  readonly property var battery: UPower.displayDevice
  readonly property bool batteryPresent: !!(battery && battery.isPresent)
  readonly property int batteryPercent: batteryPresent ? Math.round(battery.percentage * 100) : 0
  readonly property bool isCharging: batteryPresent && battery.state === UPowerDeviceState.Charging

  readonly property color thinkpadRed: "#e2231a"
  readonly property string heroIcon: "󱈑"
  readonly property bool iconVisible: iconOverrideActive
    ? iconOverrideValue
    : setting("showIcon", true) === true

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
      "/usr/local/libexec/thinkcharge-set",
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
      return "Modo Carga Total: bateria carregará até 100% da capacidade."
    }
    return "Carrega até " + previewStop + "% e só volta a recarregar abaixo de " + previewStart + "%."
  }

  function parseBoolean(value) {
    var normalized = String(value || "").trim().toLowerCase()
    if (["1", "true", "yes", "on", "show", "visible"].indexOf(normalized) !== -1) return true
    if (["0", "false", "no", "off", "hide", "hidden"].indexOf(normalized) !== -1) return false
    return null
  }

  function persistIconVisibility(value) {
    if (iconSettingsProc.running) return "busy"
    iconOverrideValue = value
    iconOverrideActive = true
    iconSettingsProc.command = [
      "omarchy", "bar", "set", root.moduleName, "showIcon",
      value ? "true" : "false", "--json"
    ]
    iconSettingsProc.running = true
    return value ? "showing" : "hiding"
  }

  onOpenedChanged: {
    if (opened) {
      cursorActive = false
      refresh()
    }
  }

  Component.onCompleted: refresh()

  Timer {
    interval: 20000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: ["/usr/local/libexec/thinkcharge-helper", "status"]
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

  Process {
    id: iconSettingsProc
    stderr: StdioCollector { id: iconSettingsErrors; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.iconOverrideActive = false
        root.errorText = iconSettingsErrors.text.trim() || "Falha ao salvar configuração do ícone"
      }
    }
  }

  IpcHandler {
    target: root.ipcTarget

    function ping(): string { return "ok" }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }

    function getLimits(): string {
      return root.configuredStop + " " + root.configuredStart
    }

    function getIconVisible(): string { return root.iconVisible ? "true" : "false" }
    function setIconVisible(value: string): string {
      var parsed = root.parseBoolean(value)
      return parsed === null
        ? "value must be true or false"
        : root.persistIconVisibility(parsed)
    }
    function showIcon(): string { return root.persistIconVisibility(true) }
    function hideIcon(): string { return root.persistIconVisibility(false) }
    function toggleIcon(): string { return root.persistIconVisibility(!root.iconVisible) }
  }

  visible: batteryPresent && iconVisible
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.heroIcon
    tooltipText: root.controlAvailable
      ? "ThinkCharge · " + root.configuredStart + "% a " + root.configuredStop + "%"
      : "ThinkCharge · Controle de carga indisponível"
    onPressed: function(mouseButton) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.batteryPresent && root.iconVisible
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    Item {
      id: anchoredHost
      anchors.fill: parent
    }
  }

  CenteredKeyboardPanel {
    id: centeredPanel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.batteryPresent && !root.iconVisible
    focusTarget: keyCatcher
    contentWidth: centeredPanel.fittedContentWidth(Style.space(420))
    contentHeight: centeredPanel.fittedContentHeight(content.implicitHeight)

    Item {
      id: centeredHost
      anchors.fill: parent
    }
  }

  Item {
    parent: root.iconVisible ? anchoredHost : centeredHost
    anchors.fill: parent

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // Header Section
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIconText.implicitHeight, heroLabels.implicitHeight, heroPercent.implicitHeight)

          Row {
            id: heroIconText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            Text {
              text: root.heroIcon
              color: root.thinkpadRed
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.display
            }

            Rectangle {
              width: Style.space(6)
              height: Style.space(6)
              radius: width / 2
              color: root.thinkpadRed
              anchors.verticalCenter: parent.verticalCenter
            }
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
              text: "ThinkCharge"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.busy
                ? "APLICANDO ALTERAÇÕES…"
                : (root.previewStop >= 100 ? "MODO CAPACIDADE TOTAL" : "PROTEÇÃO THINKPAD ATIVA")
              color: root.busy ? root.thinkpadRed : Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
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
            horizontalAlignment: Text.AlignRight
            spacing: Style.space(1)

            Text {
              text: root.previewStart + "–" + root.previewStop + "%"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              anchors.right: parent.right
            }

            Text {
              text: (root.isCharging ? "󱐋 " : "") + root.batteryPercent + "% BAT"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.right: parent.right
            }
          }
        }

        PanelSeparator {
          foreground: root.bar.foreground
        }

        // Natural language summary box
        BorderSurface {
          width: parent.width
          color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.06)
          radius: Style.cornerRadius
          padding: Style.space(8)

          Text {
            width: parent.width
            text: root.summaryText()
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }

        // Slider 1: Stop Threshold (Limite Máximo)
        Column {
          width: parent.width
          spacing: Style.space(4)

          Item {
            width: parent.width
            implicitHeight: Math.max(stopHeader.implicitHeight, stopValueText.implicitHeight)

            PanelSectionHeader {
              id: stopHeader
              text: "1. LIMITE MÁXIMO (PARAR DE CARREGAR)"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: stopValueText
              text: root.previewStop + "%"
              color: root.thinkpadRed
              font.family: root.bar.fontFamily
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
            foreground: root.bar.foreground
            outline: true

            PanelSlider {
              id: stopSlider
              bar: root.bar
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              minimum: 45
              maximum: 100
              step: 5
              tickCount: 12
              integer: true
              value: root.previewStop
              enabled: root.controlAvailable && !root.busy
              onMoved: function(val) { root.onStopMoved(val) }
              onReleased: function(val) { root.applyLimits(val, root.previewStart) }
            }
          }
        }

        // Slider 2: Start Threshold (Início de Recarga)
        Column {
          width: parent.width
          spacing: Style.space(4)

          Item {
            width: parent.width
            implicitHeight: Math.max(startHeader.implicitHeight, startValueText.implicitHeight)

            PanelSectionHeader {
              id: startHeader
              text: "2. INÍCIO DE RECARGA (VOLTAR A CARREGAR)"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: startValueText
              text: root.previewStart + "%"
              color: root.bar.accent
              font.family: root.bar.fontFamily
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
            foreground: root.bar.foreground
            outline: true

            PanelSlider {
              id: startSlider
              bar: root.bar
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              minimum: 40
              maximum: 95
              step: 5
              tickCount: 12
              integer: true
              value: root.previewStart
              enabled: root.controlAvailable && !root.busy && root.thinkpadMode
              onMoved: function(val) { root.onStartMoved(val) }
              onReleased: function(val) { root.applyLimits(root.previewStop, val) }
            }
          }
        }

        // Quick Presets Row
        Column {
          width: parent.width
          spacing: Style.space(4)

          PanelSectionHeader {
            text: "PRESETS RÁPIDOS"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              text: "Dock (50–60%)"
              tooltipText: "Ideal para uso contínuo na tomada ou dock"
              fontSize: Style.font.caption
              selected: root.previewStart === 50 && root.previewStop === 60
              horizontalPadding: Style.space(10)
              verticalPadding: Style.space(6)
              onClicked: root.setPreset(60, 50)
            }

            Button {
              text: "Equilibrado (75–85%)"
              tooltipText: "Ótima autonomia com longevidade química"
              fontSize: Style.font.caption
              selected: root.previewStart === 75 && root.previewStop === 85
              horizontalPadding: Style.space(10)
              verticalPadding: Style.space(6)
              onClicked: root.setPreset(85, 75)
            }

            Button {
              text: "Viagem (95–100%)"
              tooltipText: "Carga total para quando precisar sair"
              fontSize: Style.font.caption
              selected: root.previewStart === 95 && root.previewStop === 100
              horizontalPadding: Style.space(10)
              verticalPadding: Style.space(6)
              onClicked: root.setPreset(100, 95)
            }
          }
        }

        // Footer / Error Text
        Text {
          id: footerMessage
          width: parent.width
          text: root.errorText !== ""
            ? root.errorText
            : (!root.controlAvailable
              ? "Interface de controle de bateria não disponível no kernel."
              : (!root.thinkpadMode
                ? "Aviso: limiar de início não suportado pelo driver deste dispositivo."
                : ""))
          visible: text !== ""
          color: root.errorText !== "" ? root.bar.urgent : Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
