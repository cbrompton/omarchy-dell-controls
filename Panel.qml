import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Dell hardware controls: battery health and charge mode, BIOS thermal
// profile, fans, CPU turbo and the NVIDIA dGPU. Reads come from
// bin/dell-status (unprivileged); writes go through the root-owned
// /usr/local/libexec/dell-ctl-helper via pkexec (see install.sh).
Panel {
  id: root
  moduleName: "cbrompton.dell"
  ipcTarget: "cbrompton.dell"
  manageIpc: false

  readonly property string statusScript: Qt.resolvedUrl("bin/dell-status").toString().replace(/^file:\/\//, "")
  readonly property string helperPath: "/usr/local/libexec/dell-ctl-helper"
  readonly property string installHint: "sudo " + Qt.resolvedUrl("install.sh").toString().replace(/^file:\/\//, "").replace(Quickshell.env("HOME"), "~")

  property var info: ({})
  property string errorText: ""
  property string pendingAction: ""
  readonly property bool helperReady: info.helper === "1"
  readonly property bool showTemp: setting("showTemp", false) === true
  readonly property string barIcon: "󰈐"
  readonly property string serviceTag: info.service_tag || setting("serviceTag", "")

  // Slider working values for the Custom charge window.
  property int chargeStart: Number(info.charge_start || 50)
  property int chargeEnd: Number(info.charge_end || 100)

  readonly property var chargeOptions: Model.chargeTypeOptions(info)
  readonly property var thermalOptions: Model.thermalOptions(info)

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function run(args) {
    if (actionProc.running) return
    if (!helperReady) {
      errorText = "Controls need the helper — run: " + installHint
      return
    }
    errorText = ""
    pendingAction = args[0]
    actionProc.command = ["pkexec", helperPath].concat(args)
    actionProc.running = true
  }

  function toggleTemp() {
    root.settings = Object.assign({}, root.settings, { showTemp: !root.showTemp })
    if (root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, root.settings)
  }

  IpcHandler {
    target: "cbrompton.dell"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
  }

  Process {
    id: statusProc
    command: ["bash", root.statusScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var next = Model.parseKeyValue(text)
        if (Object.keys(next).length > 0) root.info = next
      }
    }
  }

  Process {
    id: actionProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") root.errorText = text.trim().replace(/^dell-ctl: /, "")
    }
    onExited: function(code) {
      // 126/127: pkexec dismissed or not authorized.
      if (code === 126 || code === 127) root.errorText = "Not authorized"
      root.pendingAction = ""
      root.refresh()
    }
  }

  // Poll quickly while open for live fans/temps; slowly otherwise so the bar
  // temperature stays current.
  Timer {
    interval: root.opened ? 2000 : 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  onOpenedChanged: if (opened) { errorText = ""; refresh() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.showTemp && !vertical && root.info.cpu_temp
      ? root.info.cpu_temp + "° " + root.barIcon
      : root.barIcon
    slotSize: Style.bar.iconSlot * (root.showTemp && !vertical ? 2 : 1)
    tooltipText: ""
    onPressed: function(b) {
      if (b === Qt.RightButton) root.toggleTemp()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroValue.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.barIcon
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            RotationAnimation on rotation {
              running: root.opened && Number(root.info.fan1_rpm || 0) > 0
              loops: Animation.Infinite
              from: 0; to: 360
              duration: Math.max(400, 3000000 / Math.max(1, Number(root.info.fan1_rpm || 1)))
            }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroValue.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: root.info.model ? "Dell " + root.info.model : "Dell"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              textFormat: Text.PlainText
              text: ("CPU " + Model.temp(root.info.cpu_temp) + " · " + (Model.fanSummary(root.info) || "fans idle")).toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Column {
            id: heroValue
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            Text {
              anchors.right: parent.right
              textFormat: Text.PlainText
              text: root.info.capacity ? root.info.capacity + "%" : "—"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.displayLarge
              font.bold: true
            }
            Text {
              anchors.right: parent.right
              textFormat: Text.PlainText
              text: (root.info.status || "Battery").toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }
          }
        }

        // ---------- Battery ----------
        Row {
          width: parent.width
          spacing: Style.space(20)

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair { label: "Capacity"; value: root.info.full_wh ? root.info.full_wh + " / " + root.info.design_wh + " Wh" : "—" }
            InfoPair { label: "Health"; value: Model.healthPercent(root.info) }
            InfoPair { label: "Cycles"; value: Number(root.info.cycles || 0) > 0 ? root.info.cycles : "not reported" }
            InfoPair { label: "Service tag"; value: root.serviceTag || "—" }
          }
          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair { label: "Temperature"; value: Model.temp(root.info.bat_temp) }
            InfoPair { label: "Power"; value: root.info.bat_watts ? root.info.bat_watts + " W" : "—" }
            InfoPair { label: "Made"; value: root.info.manufactured || "—" }
            InfoPair { label: "BIOS"; value: root.info.bios || "—" }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ---------- Charging ----------
        Column {
          width: parent.width
          spacing: Style.space(10)
          visible: root.chargeOptions.length > 0

          PanelSectionHeader {
            text: "BATTERY CHARGING"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          ButtonGroup {
            id: chargeGroup
            width: parent.width
            spacing: Style.space(6)
            options: root.chargeOptions
            value: root.info.charge_type || ""
            focusable: false
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.bodySmall
            onChanged: function(v) { if (v !== root.info.charge_type) root.run(["charge-type", v]) }
          }

          Column {
            width: parent.width
            spacing: Style.space(4)
            visible: root.info.charge_type === "Custom"

            ThresholdSlider {
              label: "Start charging below"
              minimum: 50; maximum: 95
              value: root.chargeStart
              onCommit: function(v) {
                var end = Math.max(root.chargeEnd, v + 5)
                root.run(["charge-thresholds", String(v), String(end)])
              }
            }
            ThresholdSlider {
              label: "Stop charging at"
              minimum: 55; maximum: 100
              value: root.chargeEnd
              onCommit: function(v) {
                var start = Math.min(root.chargeStart, v - 5)
                root.run(["charge-thresholds", String(start), String(v)])
              }
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ---------- Thermal profile ----------
        Column {
          width: parent.width
          spacing: Style.space(10)
          visible: root.thermalOptions.length > 0

          PanelSectionHeader {
            text: "THERMAL PROFILE"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          ButtonGroup {
            spacing: Style.space(6)
            options: root.thermalOptions
            value: root.info.thermal || ""
            focusable: false
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.bodySmall
            onChanged: function(v) { if (v !== root.info.thermal) root.run(["thermal", v]) }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ---------- Fans + CPU ----------
        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "FANS & CPU"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(20)

            Column {
              width: (parent.width - parent.spacing) / 2
              spacing: Style.spacing.labelGap
              InfoPair { label: (root.info.fan1_label || "Fan 1") + " fan"; value: (root.info.fan1_rpm || "0") + " RPM" }
              InfoPair { label: (root.info.fan2_label || "Fan 2") + " fan"; value: (root.info.fan2_rpm || "0") + " RPM" }
              InfoPair { label: "CPU clock"; value: root.info.cpu_mhz ? root.info.cpu_mhz + " MHz" : "—" }
            }
            Column {
              width: (parent.width - parent.spacing) / 2
              spacing: Style.spacing.labelGap
              InfoPair { label: "CPU"; value: Model.temp(root.info.cpu_temp) }
              InfoPair { label: "RAM · SSD"; value: Model.temp(root.info.ram_temp) + " · " + Model.temp(root.info.ssd_temp) }
              InfoPair { label: "EPP"; value: (root.info.cpu_epp || "—").replace(/_/g, " ") }
            }
          }

          Item {
            width: parent.width
            implicitHeight: Math.max(fanGroup.implicitHeight, turboRow.implicitHeight)

            ButtonGroup {
              id: fanGroup
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              visible: root.info.fan_control === "1"
              spacing: Style.space(6)
              options: Model.fanOptions
              value: root.info.fan_mode || "auto"
              focusable: false
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              fontSize: Style.font.bodySmall
              onChanged: function(v) { if (v !== root.info.fan_mode) root.run(["fan", v]) }
            }

            Row {
              id: turboRow
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)
              visible: root.info.cpu_turbo !== undefined

              InfoLabel { text: "Turbo"; anchors.verticalCenter: parent.verticalCenter }
              ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: root.info.cpu_turbo === "1"
                busy: root.pendingAction === "turbo"
                foreground: root.bar.foreground
                onToggled: root.run(["turbo", root.info.cpu_turbo === "1" ? "off" : "on"])
              }
            }
          }
        }

        // ---------- NVIDIA GPU ----------
        PanelSeparator { foreground: root.bar.foreground; visible: root.info.gpu_present === "1" }

        Column {
          width: parent.width
          spacing: Style.space(10)
          visible: root.info.gpu_present === "1"

          PanelSectionHeader {
            text: "GPU · " + (root.info.gpu_name || "NVIDIA").toUpperCase()
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(20)

            Column {
              width: (parent.width - parent.spacing) / 2
              spacing: Style.spacing.labelGap
              InfoPair { label: "State"; value: Model.gpuStateLabel(root.info.gpu_state) }
              InfoPair { label: "Power"; value: root.info.gpu_watts ? Number(root.info.gpu_watts).toFixed(1) + " W" : "—" }
            }
            Column {
              width: (parent.width - parent.spacing) / 2
              spacing: Style.spacing.labelGap
              InfoPair { label: "Temperature"; value: Model.temp(root.info.gpu_temp || root.info.gpu_temp_sensor) }
              InfoPair { label: "P-state · load"; value: root.info.gpu_pstate ? root.info.gpu_pstate + " · " + root.info.gpu_util + "%" : "—" }
            }
          }

          InfoLabel {
            width: parent.width
            wrapMode: Text.Wrap
            visible: root.info.gpu_state === "active" && (root.info.gpu_users || "") !== ""
            text: "Kept awake by: " + (root.info.gpu_users || "")
          }
        }

        // ---------- Footer: setup / errors ----------
        Text {
          width: parent.width
          visible: !root.helperReady || root.errorText !== ""
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          text: root.errorText !== "" ? root.errorText : "Read-only. To enable controls run: " + root.installHint
          color: root.errorText !== "" && root.bar.urgent ? root.bar.urgent : root.bar.foreground
          opacity: 0.8
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }

  component ThresholdSlider: Item {
    id: ts
    property string label: ""
    property int minimum: 50
    property int maximum: 100
    property int value: 50
    signal commit(int value)

    width: parent.width
    implicitHeight: Math.max(tsLabel.implicitHeight, slider.implicitHeight)

    InfoLabel {
      id: tsLabel
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(130)
      text: ts.label
    }
    PanelSlider {
      id: slider
      bar: root.bar
      anchors.left: tsLabel.right
      anchors.right: tsValue.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      minimum: ts.minimum
      maximum: ts.maximum
      step: 5
      integer: true
      tickCount: (ts.maximum - ts.minimum) / 5 + 1
      value: ts.value
      onReleased: function(v) {
        var snapped = Math.round(v / 5) * 5
        if (snapped !== ts.value) ts.commit(snapped)
      }
    }
    InfoValue {
      id: tsValue
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(36)
      horizontalAlignment: Text.AlignRight
      text: Math.round(slider.liveValue / 5) * 5 + "%"
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    InfoValue { text: value }
  }

  component InfoLabel: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    opacity: 0.6
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
