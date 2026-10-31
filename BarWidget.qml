import QtQuick
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

    // Memory %
    root.memPercent = data.mem_pct || 0
    root.memText = (data.mem_pct || 0) + "%"

    // 1. Network Tooltip
    var netLines = [
      "↑ " + root.upSpeed.trim() + "   ↓ " + root.downSpeed.trim(),
      "󰛳 Total: " + (data.daily_total_str || "0 B") + " (↓ " + (data.daily_rx_str || "0 B") + "  ↑ " + (data.daily_tx_str || "0 B") + ")"
    ]
    if (data.top_net_lines && data.top_net_lines.length > 0) {
      netLines.push("─────────────────────────────")
      for (var i = 0; i < data.top_net_lines.length; i++) {
        netLines.push(data.top_net_lines[i])
      }
    }
    root.netTooltipText = netLines.join("\n")

    // 2. CPU Tooltip
    var cpuLines = [
      " CPU: " + root.cpuText + "   󰓅 " + (data.load || "")
    ]
    if (data.top_cpu_lines && data.top_cpu_lines.length > 0) {
      cpuLines.push("─────────────────────────────")
      for (var j = 0; j < data.top_cpu_lines.length; j++) {
        cpuLines.push(data.top_cpu_lines[j])
      }
    }
    root.cpuTooltipText = cpuLines.join("\n")

    // 3. MEM Tooltip
    var ramUsed = formatKb(data.mem_used_kb)
    var ramTotal = formatKb(data.mem_total_kb)
    var swapUsed = formatKb(data.swap_used_kb)
    var swapTotal = formatKb(data.swap_total_kb)
    var memLines = [
      "󰘚 RAM: " + ramUsed + " / " + ramTotal + " (" + root.memText + ")",
      "󰓡 Swap: " + swapUsed + " / " + swapTotal + " (" + (data.swap_pct || 0) + "%)"
    ]
    if (data.top_mem_lines && data.top_mem_lines.length > 0) {
      memLines.push("─────────────────────────────")
      for (var k = 0; k < data.top_mem_lines.length; k++) {
        memLines.push(data.top_mem_lines[k])
      }
    }
    root.memTooltipText = memLines.join("\n")

    // Live update open tooltip text without flicker
    if (root.bar && root.bar.tooltipShown) {
      if (root.bar.tooltipTarget === netItem) {
        root.bar.tooltipText = root.netTooltipText
      } else if (root.bar.tooltipTarget === cpuItem) {
        root.bar.tooltipText = root.cpuTooltipText
      } else if (root.bar.tooltipTarget === memItem) {
        root.bar.tooltipText = root.memTooltipText
      }
    }
  }

  Process {
    id: sysmonProc
    command: ["/usr/bin/python3", Qt.resolvedUrl("sysmon.py").toString().replace("file://", "")]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseOutput(text)
    }
  }

  Timer {
    id: pollTimer
    interval: 1500
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

      // 1. Network Column Item (Fixed stable width completely prevents geometry jitter)
      Item {
        id: netItem
        width: Style.space(88)
        height: root.barSize
        readonly property var QsWindow: root.QsWindow
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
          cursorShape: Qt.PointingHandCursor
          onEntered: {
            if (!sysmonProc.running) sysmonProc.running = true
            if (root.bar) root.bar.showTooltip(netItem, root.netTooltipText)
          }
          onExited: if (root.bar) root.bar.hideTooltip(netItem)
          onClicked: if (root.bar) root.bar.run("omarchy-launch-floating-terminal-with-presentation btop")
        }
      }

      // 2. CPU Column Item (Fixed stable width completely prevents geometry jitter)
      Item {
        id: cpuItem
        width: Style.space(38)
        height: root.barSize
        readonly property var QsWindow: root.QsWindow
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
          cursorShape: Qt.PointingHandCursor
          onEntered: {
            if (!sysmonProc.running) sysmonProc.running = true
            if (root.bar) root.bar.showTooltip(cpuItem, root.cpuTooltipText)
          }
          onExited: if (root.bar) root.bar.hideTooltip(cpuItem)
          onClicked: if (root.bar) root.bar.run("omarchy-launch-floating-terminal-with-presentation btop")
        }
      }

      // 3. MEM Column Item (Fixed stable width completely prevents geometry jitter)
      Item {
        id: memItem
        width: Style.space(38)
        height: root.barSize
        readonly property var QsWindow: root.QsWindow
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
          cursorShape: Qt.PointingHandCursor
          onEntered: {
            if (!sysmonProc.running) sysmonProc.running = true
            if (root.bar) root.bar.showTooltip(memItem, root.memTooltipText)
          }
          onExited: if (root.bar) root.bar.hideTooltip(memItem)
          onClicked: if (root.bar) root.bar.run("omarchy-launch-floating-terminal-with-presentation btop")
        }
      }
    }
  }
}
