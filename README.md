# Omarchy System Monitor (`khudoydev.sysmon`)

<div align="center">

[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg?style=for-the-badge)](https://github.com/khudoydev155/omarchy-sysmon)
[![Platform](https://img.shields.io/badge/platform-Omarchy%20%7C%20Hyprland-7aa2f7.svg?style=for-the-badge)](https://github.com/basecamp/omarchy)
[![Technology](https://img.shields.io/badge/tech-Quickshell%20%E2%80%A2%20QML%20%E2%80%A2%20Python%203-10b981.svg?style=for-the-badge)](#architecture)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

A sleek, lightweight, and native system monitoring bar widget built specifically for **[Omarchy Linux](https://github.com/basecamp/omarchy)** (Hyprland + Quickshell).

Displays real-time network speeds, CPU usage, and Memory percentage in a compact 2-line column layout that integrates seamlessly with your bar, accompanied by rich, dynamic hover tooltips.

</div>

---

## 📸 Preview

### Bar Widget Appearance

```text
┌─────────────────────────────────────────┐
│   ↑  12 KB/s        CPU         MEM     │
│   ↓ 145 KB/s        18%         58%     │
└─────────────────────────────────────────┘
```

### Interactive Hover Tooltips

<table width="100%">
<tr>
<th width="33%">🌐 Network Tooltip</th>
<th width="33%">⚡ CPU Tooltip</th>
<th width="33%">🧠 Memory Tooltip</th>
</tr>
<tr>
<td valign="top">

```text
       ↑ 12 KB/s   ↓ 145 KB/s
󰛳 Daily:   1.8 GB (↓ 1.3 GB  ↑ 487 MB)
─────────────────────────────
   󰚩 agy            1.2 GB
    brave          827 MB
    AyuGram        418 MB
   󰕼 yt-dlp          46 MB
─────────────────────────────
󰛳 Monthly: 30.6 GB (↓ 26.5 GB  ↑ 4.0 GB)
```

</td>
<td valign="top">

```text
 CPU: 18%   󰓅 1.45, 1.20, 1.15
─────────────────────────────
    brave          8.4%
    python3        5.2%
    quickshell     2.1%
   󰚩 agy            1.5%
   󰓅 btop           0.8%
```

</td>
<td valign="top">

```text
󰘚 RAM:  4.3 GB / 7.1 GB (58%)
󰓡 Swap: 1.8 GB / 14.2 GB (12%)
─────────────────────────────
    brave         2.7 GB (37%)
   󰚩 agy           615 MB ( 8%)
    quickshell    341 MB ( 5%)
    AyuGram       266 MB ( 4%)
   󰣖 java          208 MB ( 3%)
```

</td>
</tr>
</table>

---

## ✨ Features

- **🌐 Comprehensive Network Monitoring**:
  - **Live Transfer Rates**: Real-time upload (`↑`) and download (`↓`) speeds.
  - **Daily Bandwidth Tracking**: Automatically tracks total daily traffic with download (`↓`) and upload (`↑`) breakdowns, resetting at midnight.
  - **Monthly Bandwidth Tracking**: Accumulates monthly network usage, rolling over automatically on the 1st of every month.
  - **Per-Process Traffic Attribution**: Tracks active applications and background services consuming bandwidth via socket inspection, complete with curated Nerd Font application icons.
  - **Loopback Traffic Isolation**: Filters internal loopback sockets (`127.0.0.1`, `::1`) so local IPC (e.g., Android emulator ADB, local databases) does not distort real Internet usage stats.

- **⚡ Real-Time CPU & Load Analytics**:
  - Live CPU percentage computed directly from differential `/proc/stat` ticks.
  - Instant 1-minute, 5-minute, and 15-minute system load averages (`󰓅`).
  - Process list showing the top 5 CPU-consuming applications in real-time.
  - Visual urgency indicator (turns red/urgent color when CPU > 85%).

- **🧠 Exact Memory & Swap Accounting**:
  - Real-time RAM percentage utilizing accurate `MemTotal - MemAvailable` accounting from `/proc/meminfo`.
  - Exact breakdown of RAM and Swap usage (`Used / Total`).
  - Top memory-consuming processes ranked by Resident Set Size (RSS) with individual percentage shares.
  - Visual urgency indicator when RAM > 90%.

- **🔄 Real-Time Live Tooltips**:
  - Tooltips dynamically tick every second while hovered, ensuring up-to-the-second precision without UI flicker.

- **🖱️ Quick Access to System Monitor**:
  - Clicking any metric immediately launches `btop` in an Omarchy floating terminal window.

- **🎨 Seamless Native Integration**:
  - Automatically matches your active Omarchy theme colors, fonts, bar height, spacing, and Nerd Font icons.

---

## 🚀 Installation

### Option 1: Direct via Omarchy CLI (Recommended)

Run the following command in your terminal:

```bash
omarchy plugin add https://github.com/khudoydev155/omarchy-sysmon.git --enable
```

### Option 2: Manual Git Clone

Clone the repository into your Omarchy plugins directory:

```bash
git clone https://github.com/khudoydev155/omarchy-sysmon.git ~/.config/omarchy/plugins/khudoydev.sysmon
```

Then add `"khudoydev.sysmon"` to your bar layout in `~/.config/omarchy/shell.json`:

```json
{
  "bar": {
    "layout": {
      "right": [
        { "id": "khudoydev.sysmon" }
      ]
    }
  }
}
```

Reload the Omarchy shell to activate:

```bash
omarchy restart shell
```

---

## ⚙️ How It Works

- **QML Frontend (`BarWidget.qml`)**:
  A lightweight Quickshell component that handles UI rendering, responsive sizing, theme bindings, mouse interaction, and live tooltip updates.
- **Python Backend (`sysmon.py`)**:
  A fast, asynchronous script reading directly from `/proc` (`/proc/stat`, `/proc/net/dev`, `/proc/meminfo`, `/proc/loadavg`, `/proc/[pid]/stat`, `/proc/[pid]/statm`) and standard `ss` socket telemetry.
- **Persistent State (`~/.local/state/omarchy/sysmon_net.json`)**:
  Stores daily and monthly accumulators locally. If the computer reboots during the day, your daily traffic count is preserved without starting from zero or inheriting stale boot counters.

---

## 📋 Requirements & Dependencies

- **OS**: Linux (tested on Arch Linux / Omarchy Linux)
- **Desktop**: Hyprland with Quickshell
- **Runtime**: Python 3 (`python3`)
- **Tools**: `iproute2` (`ss` - pre-installed on standard Linux distributions)
- **Fonts**: Any Nerd Font (e.g., *JetBrainsMono Nerd Font*, pre-installed on Omarchy)
- **Optional**: `btop` (for click-to-open system monitor)

---

## 🛠️ Troubleshooting & FAQ

<details>
<summary><b>How do I reset my daily or monthly traffic counter?</b></summary>
<br>
Simply remove the state file:

```bash
rm ~/.local/state/omarchy/sysmon_net.json
```
The counter will reinitialize on the next polling cycle.
</details>

<details>
<summary><b>The icons look like squares or broken glyphs. What should I do?</b></summary>
<br>
Make sure a compatible Nerd Font is installed and configured in your system font settings. Omarchy comes pre-configured with Nerd Fonts by default.
</details>

<details>
<summary><b>Can I change the polling interval?</b></summary>
<br>
Yes! Open `BarWidget.qml` and locate <code>pollTimer</code>:

```qml
Timer {
  id: pollTimer
  interval: root.tooltipHovered ? 1000 : 1500 // 1.5s normally, 1s when hovered
  ...
}
```
Adjust the intervals according to your preference and restart the shell.
</details>

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
Feel free to use, modify, and contribute!
