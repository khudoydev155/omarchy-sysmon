import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

export default class OmarchySysmonExtension extends Extension {
    enable() {
        this._indicator = new PanelMenu.Button(0.0, 'Omarchy System Monitor', false);
        
        this._label = new St.Label({
            text: '↑ 0 KB/s  ↓ 0 KB/s  CPU 0%  MEM 0%',
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'panel-label'
        });
        this._indicator.add_child(this._label);

        const home = GLib.get_home_dir();
        const pyPath = `${home}/.config/omarchy/plugins/khudoydev.sysmon/sysmon.py`;

        // Menu Header
        let titleItem = new PopupMenu.PopupMenuItem('📊 Omarchy System Monitor', { reactive: false });
        titleItem.label.style = 'font-weight: bold;';
        this._indicator.menu.addMenuItem(titleItem);
        this._indicator.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Live stats placeholder in menu
        this._statsItem = new PopupMenu.PopupMenuItem('Loading stats...', { reactive: false });
        this._indicator.menu.addMenuItem(this._statsItem);
        this._indicator.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Action: Launch Monitor (btop / htop)
        let launchItem = new PopupMenu.PopupMenuItem('🚀 Launch Full Monitor (btop)');
        launchItem.connect('activate', () => {
            GLib.spawn_command_line_async(`python3 "${pyPath}" launch_monitor`);
        });
        this._indicator.menu.addMenuItem(launchItem);

        Main.panel.addToStatusArea(this.uuid, this._indicator);

        this._updateStatus = () => {
            try {
                let [ok, out] = GLib.spawn_command_line_sync(`python3 "${pyPath}" waybar`);
                if (ok && out) {
                    let jsonStr = new TextDecoder().decode(out).trim();
                    let data = JSON.parse(jsonStr);
                    if (data && data.text) {
                        this._label.set_text(data.text);
                    }
                    if (data && data.tooltip && this._statsItem) {
                        this._statsItem.label.set_text(data.tooltip);
                    }
                }
            } catch (e) {}
        };

        this._updateStatus();
        this._timeout = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 2, () => {
            this._updateStatus();
            return GLib.SOURCE_CONTINUE;
        });
    }

    disable() {
        if (this._timeout) {
            GLib.Source.remove(this._timeout);
            this._timeout = null;
        }
        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }
    }
}
