# Omarchy System Monitor (`khudoydev.sysmon`)

A lightweight, native system monitoring bar widget for [Omarchy Linux](https://github.com/basecamp/omarchy) / Hyprland.

Displays real-time network speeds, CPU usage, and Memory percentage in a compact 2-line column layout matching the bar aesthetics, with rich, independent tooltips for each metric.

## Features

- **🌐 Network Speed & Daily Traffic**:
  - Live upload (`↑`) and download (`↓`) speeds.
  - Independent hover tooltip showing **Daily Total** traffic (`Total: X MB (↓ Y MB ↑ Z MB)`).
  - Breakdown of active applications and background processes using network bandwidth with application icons.
- **⚡ CPU Monitoring**:
  - Real-time overall CPU usage percentage (`CPU XX%`).
  - Independent hover tooltip showing system load averages (`1m, 5m, 15m`) and top CPU-consuming processes.
- **🧠 Memory & Swap**:
  - Real-time RAM percentage (`MEM XX%`).
  - Independent hover tooltip showing exact RAM and Swap usage (`Used / Total`) and top memory-consuming processes.
- **🖱️ Quick Access**:
  - Clicking any of the metrics launches `btop` in a floating terminal window.
- **🎨 Native Styling**:
  - Seamlessly integrates with Omarchy's color themes, corner rounding, and monospace/Nerd fonts.

## Installation

Install directly using the Omarchy plugin CLI:

```bash
omarchy plugin add https://github.com/khudoydev155/omarchy-sysmon.git --enable
```

Or manually clone it into your plugins directory:

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

Reload the shell:

```bash
omarchy restart shell
```

## Requirements

- Python 3 (`python`)
- `iproute2` (`ss`)
- Nerd Font (pre-installed on Omarchy)

## License

[MIT](LICENSE)
