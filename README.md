<div align="center">

# 📊 Omarchy System Monitor (`khudoydev.sysmon`)

**Production-grade, zero-dependency network speed, CPU, and memory monitor for Linux bars.**

[![Release](https://img.shields.io/github/v/tag/khudoydev155/omarchy-sysmon?label=version&color=3b82f6&style=for-the-badge)](https://github.com/khudoydev155/omarchy-sysmon/releases)
[![CI Status](https://img.shields.io/github/actions/workflow/status/khudoydev155/omarchy-sysmon/ci.yml?branch=main&label=CI&style=for-the-badge)](https://github.com/khudoydev155/omarchy-sysmon/actions)
[![Distros](https://img.shields.io/badge/distros-Ubuntu%20%7C%20Debian%20%7C%20Fedora%20%7C%20Arch%20%7C%20openSUSE-ea580c?style=for-the-badge)](#-distribution-install-commands)
[![Desktop](https://img.shields.io/badge/desktop-Omarchy%20%7C%20Hyprland%20%7C%20Waybar-7aa2f7?style=for-the-badge)](#-bar-configuration)
[![License: MIT](https://img.shields.io/badge/license-MIT-10b981?style=for-the-badge)](LICENSE)

Designed for **[Omarchy Linux](https://github.com/basecamp/omarchy)** (Hyprland + Quickshell) and universally compatible with **Ubuntu, Debian, Fedora, Arch Linux, openSUSE**, and **Waybar**.

> ⚠️ **Important Desktop Environment Notice**:
> Top bar widgets require **Omarchy Shell** or **Waybar** (Hyprland / Sway). Standard **GNOME** (default Fedora / Ubuntu) or **KDE** panels do not support Omarchy QML bar widgets directly. On standard GNOME/KDE, you can use the full System Monitor engine via [CLI commands](#-terminal--cli-usage) or launch btop directly!

[Quick Install](#-1-line-universal-installation) • [Distro Setup](#-distribution-install-commands) • [Bar Setup](#-bar-configuration) • [CLI Usage](#-terminal--cli-usage) • [Contributing](#-contributing)

</div>

---

## 📸 Preview

### Top Bar Widget
```text
┌─────────────────────────────────────────┐
│   ↑  12 KB/s        CPU         MEM     │
│   ↓ 145 KB/s        18%         48%     │
└─────────────────────────────────────────┘
```

### Companion Inspector Card (Right Click)
```text
┌──────────────────────────────────────────────┐
│ 󰓅 System Monitor                          ✕  │
│ Uptime: 1h 18m • 18 cores                    │
├──────────────────────────────────────────────┤
│  CPU: 18%          Load: 1.45, 1.20, 1.15   │
│ [████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░]  │
│    brave                               8.4% │
│    python3                             5.2% │
│   󰚩 agy                                 1.5% │
├──────────────────────────────────────────────┤
│ 󰘚 RAM: 48% (3.4 GB / 7.1 GB)    Swap: 10%    │
│ [████████████████░░░░░░░░░░░░░░░░░░░░░░░░░]  │
│    brave                     1.4 GB (20%)   │
│    quickshell                 404 MB ( 6%)  │
│   󰚩 agy                        307 MB ( 4%)  │
├──────────────────────────────────────────────┤
│ 󰛳 TRAFFIC TODAY: 903 MB   Month: 34.6 GB     │
│   ↑ 12 KB/s   ↓ 145 KB/s      ↓ 764M  ↑ 139M │
│    brave                            675 MB  │
│   󰣖 system                           233 MB  │
│   󰚩 agy                              163 MB  │
├──────────────────────────────────────────────┤
│ [ 󰓅 Launch Full Monitor (btop / htop) ]      │
└──────────────────────────────────────────────┘
```

---

## ⚡ 1-Line Universal Installation

The fastest way to install on **any Linux distribution** (Arch, Ubuntu, Debian, Fedora, openSUSE):

```bash
curl -fsSL https://raw.githubusercontent.com/khudoydev155/omarchy-sysmon/main/install.sh | bash
```

> The installer automatically detects your distribution, checks dependencies, verifies the backend, and installs the plugin into `~/.config/omarchy/plugins/khudoydev.sysmon/`.

---

## 📦 Distribution Install Commands

> 💡 **Two-step setup**:
> 1. Run the commands for your distribution below to install packages and download the plugin.
> 2. Then follow [🧩 Bar Configuration](#-bar-configuration) to enable it in **Omarchy Shell** or **Waybar**.

### 🏹 Arch Linux / Omarchy / Manjaro / EndeavourOS

#### Option A: Via Omarchy Plugin Manager
```bash
omarchy plugin add https://github.com/khudoydev155/omarchy-sysmon.git --enable
```

#### Option B: Manual Installation (Pacman)
```bash
sudo pacman -S --needed python iproute2 btop git
git clone https://github.com/khudoydev155/omarchy-sysmon.git ~/.config/omarchy/plugins/khudoydev.sysmon
chmod +x ~/.config/omarchy/plugins/khudoydev.sysmon/sysmon.py
```

---

### 🐧 Ubuntu / Debian / Linux Mint / Pop!_OS
```bash
sudo apt update && sudo apt install -y python3 iproute2 btop git
git clone https://github.com/khudoydev155/omarchy-sysmon.git ~/.config/omarchy/plugins/khudoydev.sysmon
chmod +x ~/.config/omarchy/plugins/khudoydev.sysmon/sysmon.py
```

---

### 🎩 Fedora / RHEL / CentOS / Rocky Linux / AlmaLinux
```bash
sudo dnf install -y python3 iproute btop git
git clone https://github.com/khudoydev155/omarchy-sysmon.git ~/.config/omarchy/plugins/khudoydev.sysmon
chmod +x ~/.config/omarchy/plugins/khudoydev.sysmon/sysmon.py
```

---

### 🦎 openSUSE (Tumbleweed / Leap)
```bash
sudo zypper install -y python3 iproute2 btop git
git clone https://github.com/khudoydev155/omarchy-sysmon.git ~/.config/omarchy/plugins/khudoydev.sysmon
chmod +x ~/.config/omarchy/plugins/khudoydev.sysmon/sysmon.py
```

---

### 🏔️ Alpine Linux
```bash
sudo apk add python3 iproute2 btop git
git clone https://github.com/khudoydev155/omarchy-sysmon.git ~/.config/omarchy/plugins/khudoydev.sysmon
chmod +x ~/.config/omarchy/plugins/khudoydev.sysmon/sysmon.py
```

---

### ❄️ NixOS / Nix
Add to your `configuration.nix`:
```nix
environment.systemPackages = with pkgs; [
  python3
  iproute2
  btop
  git
];
```

---

## 🧩 Bar Configuration

### 1. Omarchy Shell (Hyprland + Quickshell)

Add `"khudoydev.sysmon"` to your `~/.config/omarchy/shell.json` inside `"bar.layout.right"`:

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

Reload the shell to activate immediately:
```bash
omarchy restart shell
```

---

### 2. Waybar (Hyprland / Sway on Ubuntu, Debian, Fedora, Arch)

Add this module block to your `~/.config/waybar/config`:

```json
"custom/sysmon": {
    "exec": "python3 ~/.config/omarchy/plugins/khudoydev.sysmon/sysmon.py waybar",
    "return-type": "json",
    "interval": 2,
    "on-click": "python3 ~/.config/omarchy/plugins/khudoydev.sysmon/sysmon.py launch_monitor"
}
```

Add this styling to `~/.config/waybar/style.css`:

```css
#custom-sysmon {
    color: #cdd6f4;
    padding: 0 10px;
    font-weight: bold;
}
#custom-sysmon.urgent {
    color: #f38ba8;
}
```

---

## 🖱️ Mouse Controls Cheat Sheet

| Trigger | Action | Behavior |
| :--- | :--- | :--- |
| **Left Click** | **Launch Monitor** | Launches terminal monitor (`btop` / `htop` / `top`) in your preferred terminal |
| **Right Click** | **Companion Inspector** | Opens the interactive companion card with live meters and process lists |
| **Hover** | **Dynamic Tooltip** | Live ticking hover tooltips for Network, CPU, or Memory |

---

## ✨ Features

- **🌐 Comprehensive Network Monitoring**:
  - **Live Transfer Rates**: Real-time upload (`↑`) and download (`↓`) speeds.
  - **Daily Bandwidth Tracking**: Automatically tracks total daily traffic with download (`↓`) and upload (`↑`) breakdowns, resetting at midnight.
  - **Monthly Bandwidth Tracking**: Accumulates monthly network usage, rolling over automatically on the 1st of every month.
  - **Per-Process Traffic Attribution**: Tracks active applications consuming bandwidth via socket telemetry, complete with curated Nerd Font application icons.
  - **Loopback Traffic Isolation**: Filters internal loopback sockets (`127.0.0.1`, `::1`) so local IPC (databases, emulators) does not distort real Internet usage stats.
- **⚡ Real-Time CPU & Load Analytics**:
  - Live CPU percentage computed directly from differential `/proc/stat` ticks.
  - Instant 1-minute, 5-minute, and 15-minute system load averages (`󰓅`).
  - Processor model and core count detected dynamically from `/proc/cpuinfo`.
  - Process list showing the top CPU-consuming applications in real-time.
  - Visual urgency indicator (turns red/urgent color when CPU > 85%).
- **🧠 Exact Memory & Swap Accounting**:
  - Accurate RAM percentage utilizing `MemTotal - MemAvailable` accounting from `/proc/meminfo`.
  - Exact breakdown of RAM and Swap usage (`Used / Total`).
  - Top memory-consuming processes ranked by Resident Set Size (RSS).
  - Visual urgency indicator when RAM > 90%.
- **🖱️ Smart Cross-Distro Terminal Monitor Launcher**:
  - Automatically launches `btop`, falling back to `htop` or `top`.
  - Works with Omarchy's floating presentation window, or standard terminal emulators (`ghostty`, `kitty`, `foot`, `alacritty`, `wezterm`, `gnome-terminal`, `xterm`).

---

## 💻 Terminal / CLI Usage

You can also inspect system telemetry directly from any terminal or script:

```bash
# View terminal status dashboard
python3 ~/.config/omarchy/plugins/khudoydev.sysmon/sysmon.py cli

# Launch full terminal monitor
python3 ~/.config/omarchy/plugins/khudoydev.sysmon/sysmon.py launch_monitor

# Output formatted JSON for Waybar
python3 ~/.config/omarchy/plugins/khudoydev.sysmon/sysmon.py waybar

# Raw JSON output for scripts
python3 ~/.config/omarchy/plugins/khudoydev.sysmon/sysmon.py status
```

---

## 📂 Project Structure

```text
omarchy-sysmon/
├── .github/
│   └── workflows/
│       └── ci.yml          # GitHub Actions CI automated validation
├── BarWidget.qml           # Quickshell interactive QML widget & companion card
├── sysmon.py               # Python differential /proc reader & Waybar backend
├── install.sh              # Universal cross-distro auto-installer
├── manifest.json           # Omarchy plugin descriptor
├── CONTRIBUTING.md         # Developer contribution guidelines
├── LICENSE                 # MIT License
└── README.md               # Comprehensive documentation
```

---

## 🤝 Contributing

Contributions are warmly welcomed! Please read our [CONTRIBUTING.md](CONTRIBUTING.md) guide for details on local testing and pull request standards.

---

## 📄 License

Distributed under the [MIT License](LICENSE). Built with ❤️ by [Muhammad Xudayberganov (khudoydev155)](https://github.com/khudoydev155).
