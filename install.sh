#!/usr/bin/env bash
# ==============================================================================
# Omarchy System Monitor - Cross-Distro Universal Installer v1.2.0
# Compatible with Ubuntu, Debian, Fedora, Arch Linux, openSUSE, and more.
# ==============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${BOLD}${GREEN}  📊 Omarchy System Monitor Installer v1.2.0       ${NC}"
echo -e "${BLUE}====================================================${NC}"

# 1. Detect Linux Distribution
DISTRO="unknown"
DISTRO_NAME="Linux"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    DISTRO_NAME=${NAME:-$ID}
    DISTRO_LIKE=${ID_LIKE:-$ID}
fi

echo -e "Detected OS: ${BOLD}${GREEN}${DISTRO_NAME}${NC} (${DISTRO_LIKE:-$DISTRO})"

# 2. Check & Advise Prerequisites
check_and_install_deps() {
    MISSING_DEPS=()
    command -v python3 >/dev/null 2>&1 || MISSING_DEPS+=("python3")
    command -v ss >/dev/null 2>&1 || MISSING_DEPS+=("iproute2")

    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}Notice: Recommended packages missing: ${MISSING_DEPS[*]}${NC}"
        echo "To install missing packages:"
        case "$DISTRO" in
            ubuntu|debian|linuxmint|pop)
                echo -e "  Run: ${GREEN}sudo apt update && sudo apt install -y python3 iproute2 btop${NC}"
                ;;
            fedora|rhel|centos|rocky|alma)
                echo -e "  Run: ${GREEN}sudo dnf install -y python3 iproute btop${NC}"
                ;;
            arch|omarchy|manjaro|endeavouros)
                echo -e "  Run: ${GREEN}sudo pacman -S --needed python iproute2 btop${NC}"
                ;;
            opensuse*|suse)
                echo -e "  Run: ${GREEN}sudo zypper install -y python3 iproute2 btop${NC}"
                ;;
            *)
                echo -e "  Please install python3 and iproute2 with your package manager."
                ;;
        esac
    else
        echo -e "${GREEN}✓ All core dependencies found (python3, ss).${NC}"
    fi
}

check_and_install_deps

# 3. Target Installation Directory
TARGET_DIR="${HOME}/.config/omarchy/plugins/khudoydev.sysmon"
SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

echo -e "\nTarget directory: ${BLUE}${TARGET_DIR}${NC}"
mkdir -p "$(dirname "$TARGET_DIR")"

if [ -f "${SCRIPT_SRC}/BarWidget.qml" ] && [ -f "${SCRIPT_SRC}/sysmon.py" ]; then
    # Local install from cloned directory
    if [ "$SCRIPT_SRC" != "$TARGET_DIR" ]; then
        echo "Copying plugin files..."
        rm -rf "$TARGET_DIR"
        cp -r "$SCRIPT_SRC" "$TARGET_DIR"
    else
        echo "Running directly inside destination directory."
    fi
else
    # Remote install: clone directly from GitHub
    if command -v git >/dev/null 2>&1; then
        if [ -d "$TARGET_DIR/.git" ]; then
            echo "Updating existing installation from GitHub..."
            git -C "$TARGET_DIR" pull --ff-only
        else
            echo "Cloning repository from GitHub..."
            rm -rf "$TARGET_DIR"
            git clone https://github.com/khudoydev155/omarchy-sysmon.git "$TARGET_DIR"
        fi
    else
        echo -e "${RED}Error: git is required to clone the repository.${NC}"
        exit 1
    fi
fi

chmod +x "${TARGET_DIR}/sysmon.py"

# 4. Self-test
echo -e "Verifying plugin backend..."
if python3 "${TARGET_DIR}/sysmon.py" status >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Plugin verification passed (0 errors).${NC}"
else
    echo -e "${RED}✗ Backend self-test failed. Please check python3 installation.${NC}"
    exit 1
fi

# 5. Integration Guidance & Auto-Registration
SHELL_CONFIG="${HOME}/.config/omarchy/shell.json"
WAYBAR_CONFIG="${HOME}/.config/waybar/config"

if [ -f "$SHELL_CONFIG" ]; then
    echo -e "\n${BOLD}${GREEN}Omarchy Shell Detected!${NC}"
    # Automatically add widget to shell.json if not present
    REGISTER_RESULT=$(python3 -c "
import json, sys
config_file = '$SHELL_CONFIG'
plugin_id = 'khudoydev.sysmon'
try:
    with open(config_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    right = data.setdefault('bar', {}).setdefault('layout', {}).setdefault('right', [])
    if not any(item.get('id') == plugin_id for item in right if isinstance(item, dict)):
        right.append({'id': plugin_id})
        with open(config_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
        print('ADDED')
    else:
        print('EXISTS')
except Exception as e:
    print('ERROR', file=sys.stderr)
" 2>/dev/null || echo "FAILED")

    if [ "$REGISTER_RESULT" = "ADDED" ]; then
        echo -e "${GREEN}✓ Successfully added 'khudoydev.sysmon' to ${BLUE}${SHELL_CONFIG}${NC}"
        if command -v omarchy >/dev/null 2>&1; then
            echo -e "Reloading Omarchy Shell..."
            omarchy restart shell >/dev/null 2>&1 || true
            echo -e "${GREEN}✓ Shell reloaded! Widget is now visible on your bar.${NC}"
        fi
    elif [ "$REGISTER_RESULT" = "EXISTS" ]; then
        echo -e "${GREEN}✓ 'khudoydev.sysmon' is already active in your shell.json.${NC}"
        if command -v omarchy >/dev/null 2>&1; then
            omarchy restart shell >/dev/null 2>&1 || true
        fi
    else
        echo -e "To activate manually, add ${YELLOW}\"khudoydev.sysmon\"${NC} to ${BLUE}${SHELL_CONFIG}${NC} inside \"bar.layout.right\":"
        echo -e '  "right": ['
        echo -e '    { "id": "khudoydev.sysmon" }'
        echo -e '  ]'
        echo -e "Then run: ${BOLD}${GREEN}omarchy restart shell${NC}"
    fi
elif [ -f "$WAYBAR_CONFIG" ] || command -v waybar >/dev/null 2>&1; then
    echo -e "\n${BOLD}${BLUE}Waybar Environment Detected (Fedora / Ubuntu / Sway / Hyprland):${NC}"
    echo "To display the System Monitor in Waybar, add this module to your ~/.config/waybar/config:"
    echo '  "custom/sysmon": {'
    echo "    \"exec\": \"python3 ${TARGET_DIR}/sysmon.py waybar\","
    echo '    "return-type": "json",'
    echo '    "interval": 2,'
    echo "    \"on-click\": \"python3 ${TARGET_DIR}/sysmon.py launch_monitor\""
    echo '  }'
    echo -e "\nAnd include ${YELLOW}\"custom/sysmon\"${NC} in your waybar \"modules-right\"."
else
    echo -e "\n${BOLD}${YELLOW}Standard Desktop Environment Detected (${DISTRO_NAME} / GNOME / KDE):${NC}"
    echo "• Note: Omarchy bar widgets are designed for Omarchy Shell (Quickshell) and Waybar."
    echo "• In GNOME/KDE, you can run the live CLI monitor directly in your terminal:"
    echo -e "    ${BOLD}${GREEN}python3 ${TARGET_DIR}/sysmon.py cli${NC}"
    echo "• Or launch btop system monitor instantly:"
    echo -e "    ${BOLD}${GREEN}python3 ${TARGET_DIR}/sysmon.py launch_monitor${NC}"
fi

echo -e "\n${BOLD}${GREEN}✨ Installation complete! System monitoring active! 📊${NC}"
