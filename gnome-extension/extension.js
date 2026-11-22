import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

export default class OmarchySysmonExtension extends Extension {
    enable() {
        try {
            this._indicator = new PanelMenu.Button(0.0, 'Omarchy System Monitor', false);
            
            this._label = new St.Label({
                text: 'CPU 0%  RAM 0%',
                y_align: Clutter.ActorAlign.CENTER
            });
            this._indicator.add_child(this._label);

            const home = GLib.get_home_dir();
            const pyPath = `${home}/.config/omarchy/plugins/khudoydev.sysmon/sysmon.py`;

            // Menu Header
            let titleItem = new PopupMenu.PopupMenuItem('📊 Omarchy System Monitor', { reactive: false });
            this._indicator.menu.addMenuItem(titleItem);
            this._indicator.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

            // Live stats placeholder in menu
            this._statsItem = new PopupMenu.PopupMenuItem('Loading system stats...', { reactive: false });
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
                    let [res, out] = GLib.spawn_command_line_sync(`python3 "${pyPath}" waybar`);
                    if (res && out && out.length > 0) {
                        let jsonStr = new TextDecoder().decode(out).trim();
                        let data = JSON.parse(jsonStr);
                        if (data && data.text) {
                            let cleanText = data.text
                                .replace(/\uf4bc/g, 'CPU')
                                .replace(/\udb81\ude1a/g, 'RAM')
                                .replace(/\s+/g, ' ')
                                .trim();
                            this._label.set_text(cleanText || data.text);
                        }
                        if (data && data.tooltip && this._statsItem) {
                            let cleanTooltip = data.tooltip
                                .replace(/[\uf4bc\udb81\udef3\udb81\ude1a\udb81\udce1]/g, '•');
                            this._statsItem.label.set_text(cleanTooltip);
                        }
                    }
                } catch (e) {
                    console.error('[Omarchy Sysmon] Update error:', e);
                }
            };

            this._updateStatus();
            this._timeout = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 2, () => {
                this._updateStatus();
                return GLib.SOURCE_CONTINUE;
            });
        } catch (err) {
            console.error('[Omarchy Sysmon] enable() failed:', err);
        }
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
