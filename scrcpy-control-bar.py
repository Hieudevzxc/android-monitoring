#!/usr/bin/env python3
import os
import sys
import subprocess
import gi

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib, Gio

# Get args
if len(sys.argv) < 3:
    print("Usage: scrcpy-control-bar.py <serial> <scrcpy_pid>")
    sys.exit(1)

SERIAL = sys.argv[1]
SCRCPY_PID = int(sys.argv[2])

class ControlBar(Gtk.Window):
    def __init__(self):
        super().__init__(title="Android Control Bar")
        self.set_keep_above(True)
        self.set_type_hint(Gdk.WindowTypeHint.UTILITY)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_border_width(4)
        self.set_position(Gtk.WindowPosition.CENTER)
        
        # Connect drag events to window
        self.connect("button-press-event", self.on_button_press)
        
        # Main layout
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        self.add(hbox)
        
        # Drag Handle
        handle = Gtk.EventBox()
        handle_label = Gtk.Label(label=" ⠿ ")
        handle_label.set_tooltip_text("Kéo để di chuyển thanh công cụ")
        handle.add(handle_label)
        handle.connect("button-press-event", self.on_button_press)
        hbox.pack_start(handle, False, False, 4)
        
        # Buttons configuration: (icon_name, keyevent, tooltip)
        buttons = [
            ("go-previous-symbolic", 4, "Quay lại (Back)"),
            ("go-home-symbolic", 3, "Trang chủ (Home)"),
            ("view-grid-symbolic", 187, "Ứng dụng gần đây (Recents)"),
            ("audio-volume-low-symbolic", 25, "Giảm âm lượng"),
            ("audio-volume-high-symbolic", 24, "Tăng âm lượng"),
            ("weather-clear-night-symbolic", "scrcpy_screen_off", "Tắt màn hình điện thoại (Giữ kết nối máy tính)"),
            ("system-shutdown-symbolic", 26, "Nguồn điện thoại (Power)"),
            ("network-wireless-symbolic", "wifi_setup", "Thiết lập kết nối Wi-Fi (Không dây)"),
        ]
        
        for icon_name, keycode, tooltip in buttons:
            btn = Gtk.Button()
            btn.set_tooltip_text(tooltip)
            btn.set_relief(Gtk.ReliefStyle.NONE)
            
            try:
                icon = Gio.ThemedIcon(name=icon_name)
                img = Gtk.Image.new_from_gicon(icon, Gtk.IconSize.BUTTON)
                btn.set_image(img)
            except Exception:
                # Fallback to first char if icon fails
                btn.set_label(tooltip[0])
                
            btn.connect("clicked", self.on_action_clicked, keycode)
            hbox.pack_start(btn, False, False, 0)
            
        # Close Button
        close_btn = Gtk.Button()
        close_btn.set_tooltip_text("Đóng kết nối")
        close_btn.set_relief(Gtk.ReliefStyle.NONE)
        try:
            icon = Gio.ThemedIcon(name="window-close-symbolic")
            img = Gtk.Image.new_from_gicon(icon, Gtk.IconSize.BUTTON)
            close_btn.set_image(img)
        except Exception:
            close_btn.set_label("✕")
        close_btn.connect("clicked", self.on_close_clicked)
        hbox.pack_start(close_btn, False, False, 0)
        
        # Apply CSS styling for premium look
        self.apply_css()
        
        # Check if scrcpy is still alive periodically
        GLib.timeout_add(1000, self.check_scrcpy_alive)
        
        self.show_all()
        
    def apply_css(self):
        css = b"""
        window {
            background-color: #1e1e24;
            border-radius: 8px;
            border: 1px solid #33333c;
        }
        button {
            color: #eeeeee;
            padding: 4px 6px;
            border-radius: 6px;
        }
        button:hover {
            background-color: rgba(255, 255, 255, 0.1);
        }
        button:active {
            background-color: rgba(255, 255, 255, 0.2);
        }
        label {
            color: #888888;
            font-weight: bold;
            font-size: 14px;
        }
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
        
    def on_button_press(self, widget, event):
        if event.button == 1:
            self.begin_move_drag(
                event.button,
                event.x_root,
                event.y_root,
                event.time
            )
            return True
        return False
        
    def on_action_clicked(self, button, keycode):
        if keycode == "wifi_setup":
            subprocess.Popen(["/usr/local/bin/scrcpy-launcher.sh", "--wifi-setup"])
        elif keycode == "scrcpy_screen_off":
            subprocess.Popen(["xdotool", "search", "--name", "^Android Mirroring$", "windowactivate", "--sync", "key", "alt+o"])
        else:
            subprocess.Popen(["adb", "-s", SERIAL, "shell", "input", "keyevent", str(keycode)])
        
    def on_close_clicked(self, button):
        # Kill scrcpy and exit
        try:
            os.kill(SCRCPY_PID, 15) # SIGTERM
        except OSError:
            pass
        Gtk.main_quit()
        
    def check_scrcpy_alive(self):
        try:
            os.kill(SCRCPY_PID, 0)
        except OSError:
            # scrcpy is dead, close this window
            Gtk.main_quit()
            return False
        return True

if __name__ == "__main__":
    win = ControlBar()
    Gtk.main()
