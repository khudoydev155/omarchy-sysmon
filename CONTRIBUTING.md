# Contributing to Omarchy System Monitor

Thank you for your interest in contributing to **Omarchy System Monitor**! We welcome bug reports, feature suggestions, and pull requests.

## 🛠 Local Development & Testing

1. **Clone the repository**:
   ```bash
   git clone https://github.com/khudoydev155/omarchy-sysmon.git ~/.config/omarchy/plugins/khudoydev.sysmon
   cd ~/.config/omarchy/plugins/khudoydev.pomodoro
   ```

2. **Test the backend Python script**:
   ```bash
   # JSON status check
   python3 sysmon.py status

   # Waybar module output
   python3 sysmon.py waybar

   # Terminal CLI dashboard
   python3 sysmon.py cli

   # Launch terminal monitor
   python3 sysmon.py launch_monitor
   ```

3. **Reload Quickshell in Omarchy**:
   ```bash
   omarchy restart shell
   ```

4. **Inspect logs**:
   ```bash
   journalctl _PID=$(pgrep -n quickshell) --no-pager | tail -n 30
   ```

## 📋 Pull Request Guidelines

- Ensure `python3 -m py_compile sysmon.py` and `bash -n install.sh` pass without errors.
- Keep UI text clean, minimal, and in international English.
- Avoid hardcoded paths (e.g. use `python3` instead of `/usr/bin/python3`).
- Rely exclusively on standard Linux `/proc` and standard POSIX tools so the widget runs anywhere without extra packages.

## 📄 License
By contributing, you agree that your contributions will be licensed under the project's [MIT License](LICENSE).
