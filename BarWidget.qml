import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "khudoydev.sysmon"

  property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  property color barForeground: root.bar ? root.bar.barForeground : Commons.Color.foreground
  property color urgentColor: root.bar ? root.bar.urgent : Commons.Color.urgent
  property color accentColor: Commons.Color.accent

  property bool pressable: true
  property bool interactive: true
  property bool cardOpen: false

  function triggerPress(button) {
    if (button === Qt.RightButton) {
      root.cardOpen = !root.cardOpen
    } else {
      launchProc.running = false
      launchProc.running = true
    }
  }

  readonly property int captionFontSize: Math.max(8, Style.font.caption - 1)
  readonly property int valueFontSize: Math.max(9, Style.font.caption)

  property real prevRx: 0
  property real prevTx: 0
  property real prevIdle: 0
  property real prevTotal: 0
  property real prevTime: 0

  property string upSpeed: "  0 KB/s"
  property string downSpeed: "  0 KB/s"
  property string cpuText: "0%"
  property string memText: "0%"
  property int cpuPercent: 0
  property int memPercent: 0

  property string cpuModel: "Linux Processor"
  property int cpuCores: 1
  property string uptimeStr: "0m"
  property string loadStr: "0.00, 0.00, 0.00"

  property string memUsedStr: "0 MB"
  property string memTotalStr: "0 MB"
  property string swapUsedStr: "0 MB"
  property string swapTotalStr: "0 MB"
  property int swapPercent: 0

  property string dailyTotalStr: "0 B"
  property string dailyRxStr: "0 B"
  property string dailyTxStr: "0 B"
  property string monthlyTotalStr: "0 B"

  property var topCpuList: []
  property var topMemList: []
  property var topNetList: []

  property string netTooltipText: "↑ 0 KB/s   ↓ 0 KB/s"
  property string cpuTooltipText: " CPU: 0%"
  property string memTooltipText: "󰘚 RAM: 0%"

  readonly property bool tooltipHovered: netMouseArea.containsMouse || cpuMouseArea.containsMouse || memMouseArea.containsMouse

  implicitWidth: Style.space(192)
  implicitHeight: root.barSize

  function formatRate(bytesPerSec) {
    if (!bytesPerSec || bytesPerSec < 0) bytesPerSec = 0
    var kb = bytesPerSec / 1024
    if (kb < 1000) {
      var s = Math.round(kb).toString()
      while (s.length < 3) s = " " + s
      return s + " KB/s"
    }
    var mb = bytesPerSec / (1024 * 1024)
    if (mb < 100) {
      var s = mb.toFixed(1)
      while (s.length < 4) s = " " + s
      return s + " MB/s"
    }
    var s = Math.round(mb).toString()
    while (s.length < 3) s = " " + s
    return s + " MB/s"
  }

  function formatKb(kb) {
    if (!kb || kb < 0) return "0 MB"
    if (kb >= 1024 * 1024) return (kb / (1024 * 1024)).toFixed(1) + " GB"
    return Math.round(kb / 1024) + " MB"
  }

  function parseOutput(text) {
    if (!text) return
    var data
    try {
      data = JSON.parse(text.trim())
    } catch (e) {
      return
    }

    var now = Date.now()
    var rx = data.rx || 0
    var tx = data.tx || 0
    var idle = data.idle || 0
    var total = data.total || 0

    // Live CPU & NET Rates
    if (root.prevTotal > 0 && total > root.prevTotal) {
      var dt = (now - root.prevTime) / 1000
      if (dt <= 0.1) dt = 1.0

      var totalDelta = total - root.prevTotal
      var idleDelta = idle - root.prevIdle
      if (totalDelta > 0) {
        var cpuPct = Math.round(100 * (1 - (idleDelta / totalDelta)))
        if (cpuPct < 0) cpuPct = 0
        if (cpuPct > 100) cpuPct = 100
        root.cpuPercent = cpuPct
        root.cpuText = cpuPct + "%"
      }

      if (rx >= root.prevRx) {
        root.downSpeed = formatRate((rx - root.prevRx) / dt)
      }
      if (tx >= root.prevTx) {
        root.upSpeed = formatRate((tx - root.prevTx) / dt)
      }
    }

    root.prevRx = rx
    root.prevTx = tx
    root.prevIdle = idle
    root.prevTotal = total
    root.prevTime = now

    // Memory & Swap
    root.memPercent = data.mem_pct || 0
    root.memText = (data.mem_pct || 0) + "%"
    root.swapPercent = data.swap_pct || 0

    root.memUsedStr = formatKb(data.mem_used_kb)
    root.memTotalStr = formatKb(data.mem_total_kb)
    root.swapUsedStr = formatKb(data.swap_used_kb)
    root.swapTotalStr = formatKb(data.swap_total_kb)

    // CPU Info & Uptime
    root.cpuModel = data.cpu_model || "Linux Processor"
    root.cpuCores = data.cpu_cores || 1
    root.uptimeStr = data.uptime || "0m"
    root.loadStr = data.load || "0.00, 0.00, 0.00"

    // Traffic Totals
    root.dailyTotalStr = data.daily_total_str || "0 B"
    root.dailyRxStr = data.daily_rx_str || "0 B"
    root.dailyTxStr = data.daily_tx_str || "0 B"
    root.monthlyTotalStr = data.monthly_total_str || "0 B"

    // Top Lists
    root.topCpuList = data.top_cpu_list || []
    root.topMemList = data.top_mem_list || []
    root.topNetList = data.top_net_list || []

    // 1. Network Tooltip
    var netLines = [
      "↑ " + root.upSpeed.trim() + "   ↓ " + root.downSpeed.trim(),
      "󰛳 Daily:   " + root.dailyTotalStr + " (↓ " + root.dailyRxStr + "  ↑ " + root.dailyTxStr + ")",
      "─────────────────────────────"
    ]
    if (data.top_net_lines && data.top_net_lines.length > 0) {
      for (var i = 0; i < data.top_net_lines.length; i++) {
        netLines.push(data.top_net_lines[i])
      }
      netLines.push("─────────────────────────────")
    }
    netLines.push("󰛳 Monthly: " + root.monthlyTotalStr + " (↓ " + (data.monthly_rx_str || "0 B") + "  ↑ " + (data.monthly_tx_str || "0 B") + ")")
    netLines.push("─────────────────────────────")
    netLines.push("Left: Monitor • Right: Inspector")
    root.netTooltipText = netLines.join("\n")

    // 2. CPU Tooltip
    var cpuLines = [
      " CPU: " + root.cpuText + "   󰓅 " + root.loadStr,
      "Cores: " + root.cpuCores + " • Uptime: " + root.uptimeStr
    ]
    if (data.top_cpu_lines && data.top_cpu_lines.length > 0) {
      cpuLines.push("─────────────────────────────")
      for (var j = 0; j < data.top_cpu_lines.length; j++) {
        cpuLines.push(data.top_cpu_lines[j])
      }
    }
    cpuLines.push("─────────────────────────────")
    cpuLines.push("Left: Monitor • Right: Inspector")
    root.cpuTooltipText = cpuLines.join("\n")

    // 3. MEM Tooltip
    var memLines = [
      "󰘚 RAM: " + root.memUsedStr + " / " + root.memTotalStr + " (" + root.memText + ")",
      "󰓡 Swap: " + root.swapUsedStr + " / " + root.swapTotalStr + " (" + root.swapPercent + "%)"
    ]
    if (data.top_mem_lines && data.top_mem_lines.length > 0) {
      memLines.push("─────────────────────────────")
      for (var k = 0; k < data.top_mem_lines.length; k++) {
        memLines.push(data.top_mem_lines[k])
      }
    }
    memLines.push("─────────────────────────────")
    memLines.push("Left: Monitor • Right: Inspector")
    root.memTooltipText = memLines.join("\n")

    // Live update open tooltip while hovered
    if (root.bar) {
      if (netMouseArea.containsMouse) {
        root.bar.showTooltip(netItem, root.netTooltipText)
      } else if (cpuMouseArea.containsMouse) {
        root.bar.showTooltip(cpuItem, root.cpuTooltipText)
      } else if (memMouseArea.containsMouse) {
        root.bar.showTooltip(memItem, root.memTooltipText)
      }
    }
  }

  // Cross-distro python3 execution
  Process {
    id: sysmonProc
    command: ["python3", Qt.resolvedUrl("sysmon.py").toString().replace("file://", ""), "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseOutput(text)
    }
  }

  // Monitor launcher process (btop / htop / top in any terminal)
  Process {
    id: launchProc
    command: ["python3", Qt.resolvedUrl("sysmon.py").toString().replace("file://", ""), "launch_monitor"]
    running: false
  }

  Timer {
    id: pollTimer
    interval: (root.tooltipHovered || root.cardOpen) ? 1000 : 1500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!sysmonProc.running) sysmonProc.running = true
    }
  }

  Item {
    id: content
    anchors.fill: parent

    Row {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.space(8)

      // 1. Network Column Item
      Item {
        id: netItem
        width: Style.space(88)
        height: root.barSize
        readonly property bool tooltipHovered: netMouseArea.containsMouse

        Column {
          id: netCol
          anchors.centerIn: parent
          spacing: 0

          Row {
            spacing: 2
            Text {
              text: "↑"
              font.family: root.fontFamily
              font.pixelSize: root.captionFontSize
              color: root.barForeground
              opacity: 0.65
              renderType: Text.NativeRendering
            }
            Text {
              text: root.upSpeed
              font.family: root.fontFamily
              font.pixelSize: root.captionFontSize
              color: root.barForeground
              opacity: 0.95
              renderType: Text.NativeRendering
            }
          }

          Row {
            spacing: 2
            Text {
              text: "↓"
              font.family: root.fontFamily
              font.pixelSize: root.captionFontSize
              color: root.barForeground
              opacity: 0.65
              renderType: Text.NativeRendering
            }
            Text {
              text: root.downSpeed
              font.family: root.fontFamily
              font.pixelSize: root.captionFontSize
              color: root.barForeground
              opacity: 0.95
              renderType: Text.NativeRendering
            }
          }
        }

        MouseArea {
          id: netMouseArea
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: Qt.PointingHandCursor
          onEntered: {
            if (!sysmonProc.running) sysmonProc.running = true
            if (root.bar) root.bar.showTooltip(netItem, root.netTooltipText)
          }
          onExited: if (root.bar) root.bar.hideTooltip(netItem)
          onClicked: (mouse) => {
            root.triggerPress(mouse.button)
          }
        }
      }

      // 2. CPU Column Item
      Item {
        id: cpuItem
        width: Style.space(38)
        height: root.barSize
        readonly property bool tooltipHovered: cpuMouseArea.containsMouse

        Column {
          id: cpuCol
          anchors.centerIn: parent
          spacing: 0

          Text {
            text: "CPU"
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: root.fontFamily
            font.pixelSize: root.captionFontSize
            color: root.barForeground
            opacity: 0.65
            renderType: Text.NativeRendering
          }

          Text {
            text: root.cpuText
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: root.fontFamily
            font.pixelSize: root.valueFontSize
            font.bold: true
            color: root.cpuPercent > 85 ? root.urgentColor : root.barForeground
            opacity: 1.0
            renderType: Text.NativeRendering
          }
        }

        MouseArea {
          id: cpuMouseArea
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: Qt.PointingHandCursor
          onEntered: {
            if (!sysmonProc.running) sysmonProc.running = true
            if (root.bar) root.bar.showTooltip(cpuItem, root.cpuTooltipText)
          }
          onExited: if (root.bar) root.bar.hideTooltip(cpuItem)
          onClicked: (mouse) => {
            root.triggerPress(mouse.button)
          }
        }
      }

      // 3. MEM Column Item
      Item {
        id: memItem
        width: Style.space(38)
        height: root.barSize
        readonly property bool tooltipHovered: memMouseArea.containsMouse

        Column {
          id: memCol
          anchors.centerIn: parent
          spacing: 0

          Text {
            text: "MEM"
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: root.fontFamily
            font.pixelSize: root.captionFontSize
            color: root.barForeground
            opacity: 0.65
            renderType: Text.NativeRendering
          }

          Text {
            text: root.memText
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: root.fontFamily
            font.pixelSize: root.valueFontSize
            font.bold: true
            color: root.memPercent > 90 ? root.urgentColor : root.barForeground
            opacity: 1.0
            renderType: Text.NativeRendering
          }
        }

        MouseArea {
          id: memMouseArea
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: Qt.PointingHandCursor
          onEntered: {
            if (!sysmonProc.running) sysmonProc.running = true
            if (root.bar) root.bar.showTooltip(memItem, root.memTooltipText)
          }
          onExited: if (root.bar) root.bar.hideTooltip(memItem)
          onClicked: (mouse) => {
            root.triggerPress(mouse.button)
          }
        }
      }
    }
  }

  // Interactive System Inspector Companion Card
  Loader {
    id: cardLoader
    active: root.cardOpen && !!root.bar
    sourceComponent: Component {
      PopupCard {
        id: sysmonPopup
        anchorItem: root
        bar: root.bar
        owner: root
        open: root.cardOpen
        margin: Style.gapsOut
        onOpenChanged: {
          if (!open) root.cardOpen = false
        }
        contentWidth: Style.space(360)
        contentHeight: cardCol.implicitHeight + Style.space(28)

        Column {
          id: cardCol
          anchors.fill: parent
          spacing: Style.space(10)

          // 1. Header (Icon, Title, Uptime & Close Button)
          Item {
            width: parent.width
            height: Math.max(headerRow.implicitHeight, closeBtn.height)

            Row {
              id: headerRow
              spacing: Style.space(10)
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter

              Text {
                text: "󰓅"
                font.family: root.fontFamily
                font.pixelSize: Style.font.title + 4
                color: root.accentColor
              }

              Column {
                Text {
                  text: "System Monitor"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  color: root.barForeground
                }
                Text {
                  text: "Uptime: " + root.uptimeStr + " • " + root.cpuCores + " cores"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  color: root.barForeground
                  opacity: 0.7
                }
              }
            }

            Rectangle {
              id: closeBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(26)
              height: Style.space(26)
              radius: Style.space(13)
              color: closeHover.containsMouse ? Util.alpha(root.barForeground, 0.15) : "transparent"

              Text {
                anchors.centerIn: parent
                text: "✕"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                color: root.barForeground
                opacity: closeHover.containsMouse ? 1.0 : 0.6
              }

              MouseArea {
                id: closeHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cardOpen = false
              }
            }
          }

          Rectangle {
            width: parent.width
            height: 1
            color: root.barForeground
            opacity: 0.12
          }

          // 2. CPU & Load Section
          Column {
            width: parent.width
            spacing: Style.space(4)

            Item {
              width: parent.width
              height: Style.space(16)

              Text {
                anchors.left: parent.left
                text: " CPU: " + root.cpuText
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: true
                color: root.cpuPercent > 85 ? root.urgentColor : root.barForeground
              }

              Text {
                anchors.right: parent.right
                text: "Load: " + root.loadStr
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                color: root.barForeground
                opacity: 0.65
              }
            }

            // CPU Meter Bar
            Rectangle {
              width: parent.width
              height: Style.space(6)
              radius: Style.space(3)
              color: Util.alpha(root.barForeground, 0.12)

              Rectangle {
                width: parent.width * (Math.min(100, Math.max(0, root.cpuPercent)) / 100.0)
                height: parent.height
                radius: parent.radius
                color: root.cpuPercent > 85 ? root.urgentColor : root.accentColor
              }
            }

            // Top CPU Process rows
            Repeater {
              model: root.topCpuList.slice(0, 3)
              delegate: Item {
                required property var modelData
                width: parent.width
                height: Style.space(16)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.icon + " " + modelData.name
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 2
                  color: root.barForeground
                  opacity: 0.85
                }

                Text {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.pct_str
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 2
                  font.bold: true
                  color: root.barForeground
                }
              }
            }
          }

          Rectangle {
            width: parent.width
            height: 1
            color: root.barForeground
            opacity: 0.12
          }

          // 3. Memory & Swap Section
          Column {
            width: parent.width
            spacing: Style.space(4)

            Item {
              width: parent.width
              height: Style.space(16)

              Text {
                anchors.left: parent.left
                text: "󰘚 RAM: " + root.memText + " (" + root.memUsedStr + " / " + root.memTotalStr + ")"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: true
                color: root.memPercent > 90 ? root.urgentColor : root.barForeground
              }

              Text {
                anchors.right: parent.right
                text: "Swap: " + root.swapPercent + "%"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                color: root.barForeground
                opacity: 0.65
              }
            }

            // RAM Meter Bar
            Rectangle {
              width: parent.width
              height: Style.space(6)
              radius: Style.space(3)
              color: Util.alpha(root.barForeground, 0.12)

              Rectangle {
                width: parent.width * (Math.min(100, Math.max(0, root.memPercent)) / 100.0)
                height: parent.height
                radius: parent.radius
                color: root.memPercent > 90 ? root.urgentColor : root.accentColor
              }
            }

            // Top Memory Process rows
            Repeater {
              model: root.topMemList.slice(0, 3)
              delegate: Item {
                required property var modelData
                width: parent.width
                height: Style.space(16)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.icon + " " + modelData.name
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 2
                  color: root.barForeground
                  opacity: 0.85
                }

                Text {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.bytes_str + " (" + modelData.pct + "%)"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 2
                  font.bold: true
                  color: root.barForeground
                }
              }
            }
          }

          Rectangle {
            width: parent.width
            height: 1
            color: root.barForeground
            opacity: 0.12
          }

          // 4. Network Traffic Section
          Column {
            width: parent.width
            spacing: Style.space(4)

            Item {
              width: parent.width
              height: Style.space(16)

              Text {
                anchors.left: parent.left
                text: "󰛳 TRAFFIC TODAY: " + root.dailyTotalStr
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: true
                color: root.barForeground
              }

              Text {
                anchors.right: parent.right
                text: "Month: " + root.monthlyTotalStr
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                color: root.barForeground
                opacity: 0.65
              }
            }

            Item {
              width: parent.width
              height: Style.space(14)

              Text {
                anchors.left: parent.left
                text: "↑ " + root.upSpeed.trim() + "   ↓ " + root.downSpeed.trim()
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                color: root.accentColor
                font.bold: true
              }

              Text {
                anchors.right: parent.right
                text: "↓ " + root.dailyRxStr + "  ↑ " + root.dailyTxStr
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                color: root.barForeground
                opacity: 0.7
              }
            }

            // Top Network App rows
            Repeater {
              model: root.topNetList.slice(0, 3)
              delegate: Item {
                required property var modelData
                width: parent.width
                height: Style.space(16)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.icon + " " + modelData.name
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 2
                  color: root.barForeground
                  opacity: 0.85
                }

                Text {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.bytes_str
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 2
                  font.bold: true
                  color: root.barForeground
                }
              }
            }
          }

          Rectangle {
            width: parent.width
            height: 1
            color: root.barForeground
            opacity: 0.12
          }

          // 5. Bottom Action: Launch Full Monitor (btop / htop)
          Rectangle {
            width: parent.width
            height: Style.space(32)
            radius: Style.space(6)
            color: btopHover.containsMouse ? root.accentColor : Util.alpha(root.accentColor, 0.2)
            border.width: 1
            border.color: root.accentColor

            Text {
              anchors.centerIn: parent
              text: "󰓅 Launch Full Monitor (btop / htop)"
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              color: btopHover.containsMouse ? (root.bar ? root.bar.themeContrastForeground : "#101315") : root.accentColor
            }

            MouseArea {
              id: btopHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.cardOpen = false
                launchProc.running = false
                launchProc.running = true
              }
            }
          }
        }
      }
    }
  }
}
