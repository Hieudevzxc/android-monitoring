# Android Mirroring & Control (scrcpy-launcher)

This project provides a clean, fully-featured desktop wrapper for [scrcpy](https://github.com/Genymobile/scrcpy) tailored for Linux desktop environments (optimized for GNOME/Debian). It enables mirroring and controlling your Android device screen using your computer's keyboard and mouse with extremely low latency, alongside a handy floating control toolbar.

## Features

- **Quick Start (Left-Click)**: Instantly starts mirroring with optimal default settings—automatically turns off the physical phone screen to save power/maintain privacy, forwards audio, and locks the phone screen when you close the connection.
- **Right-Click Context Options**:
  - **Start with screen ON**: Keeps your physical phone screen turned on during mirroring.
  - **Configure options...**: Opens a native GUI configuration form (Zenity) to customize connection settings:
    - Toggle physical screen dimming.
    - Toggle automatic phone locking on close.
    - Limit resolution (Default, 1080p, 720p, 480p) to optimize performance on slower connections.
    - Toggle audio forwarding.
    - Enable read-only mode (view-only without keyboard/mouse interaction).
- **Floating Control Bar**: A modern, dark-themed utility bar built using native GNOME GTK 3 symbolic icons. It floats on top of your windows, can be dragged anywhere (using the `⠿` handle), and provides quick shortcuts for:
  - `◀` Back
  - `🏠` Home
  - `⏹` Recents (App switcher)
  - `🔉 / 🔊` Volume Down / Volume Up
  - `🌙` Screen Sleep (turns off the phone screen manually)
  - `⚡` Power key emulation
  - `✕` Disconnect (safely closes both the toolbar and scrcpy)
- **Automatic Sync**: The control bar automatically closes when you exit the mirroring window, and closing the control bar terminates the mirroring session.

## Installation

Simply clone this repository and run the automated installation script:

```bash
git clone https://github.com/Hieudevzxc/android-monitoring.git
cd android-monitoring
chmod +x install.sh
sudo ./install.sh
```

The script will automatically configure Debian repositories (`contrib` and `trixie-backports`), install packages (`scrcpy`, `adb`, `zenity`, `python3-gi`), copy launcher binaries, and integrate the application shortcut into your desktop environment.

## Android Phone Setup

Before starting, you must enable **USB Debugging** on your phone:
1. Open **Settings** on your phone.
2. Navigate to **About Phone** (or **System** -> **About Phone**).
3. Tap **Build Number** continuously **7 times** until you see a message saying *"You are now a developer"*.
4. Go back to main Settings -> **System** -> **Developer Options**.
5. Find and enable **USB Debugging**.
6. Connect your phone to your computer via USB.
7. Unlock your phone; a prompt asking to allow USB Debugging will appear. Check **"Always allow from this computer"** and tap **Allow**.

## Usage & Connections

### 1. Wired Connection (USB)
1. Connect your phone to your computer via a USB cable.
2. Open **Show Applications** in GNOME (or press the `Super`/`Windows` key) and search for **"Android Mirroring"** (or **"Điều khiển Android"**).
3. Left-click the icon to start mirroring instantly with default options, or right-click the icon to adjust configuration settings.

### 2. Wireless Connection (Wi-Fi)
To use the application wirelessly over Wi-Fi (no USB cable needed after initial setup):
1. **Initial Setup (Must do once)**:
   - Connect your phone to the computer via USB cable.
   - Right-click the **"Android Mirroring"** icon in GNOME Applications and select **"Thiết lập kết nối Wi-Fi (Không dây)..."** (Wireless Wi-Fi Setup).
   - Follow the onscreen prompt. The script will automatically configure TCP/IP mode on your phone, retrieve its IP address, establish the connection, and save it.
2. **Subsequent Launches**:
   - Make sure both your phone and computer are connected to the **same Wi-Fi network**.
   - Simply left-click the **"Android Mirroring"** icon (no USB cable needed).
   - The launcher will automatically detect the last connected Wi-Fi IP address and try to connect wirelessly in the background. If successful, mirroring starts immediately.
   - *Note: If the connection fails (e.g., if the phone's IP address changes due to a network reset), connect the USB cable and run the Wi-Fi setup again to update the saved IP.*

## Handy Keyboard Shortcuts
When the mirroring window is focused, you can also use these standard shortcuts (using the `Alt` key as the default control key):
- `Alt + O`: Turn the physical phone screen off.
- `Alt + Shift + O`: Turn the physical phone screen back on.
- `Alt + Backspace` or `Right-Click`: Go Back.
- `Alt + H` or `Middle-Click`: Go Home.
- `Alt + S`: App Switcher.
- `Alt + Up / Down`: Adjust Volume.
- `Alt + P`: Emulate Power button.
- `Drag & Drop Files`: Copy files from PC to phone.
