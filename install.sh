#!/bin/bash

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo (e.g., sudo ./install.sh)"
  exit 1
fi

echo "============================================="
echo " Installing Android Mirroring (scrcpy) Tools"
echo "============================================="

# 1. Enable contrib and backports repository for Debian
echo "-> Checking and configuring Debian apt repositories..."
if [ -f /etc/apt/sources.list ]; then
    # Backup current sources.list
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    echo "   [Backed up current sources.list to /etc/apt/sources.list.bak]"
    
    # Add 'contrib' and 'non-free' in standard repo lines if not present
    sed -i 's/main non-free-firmware/main contrib non-free non-free-firmware/g' /etc/apt/sources.list
    
    # Add backports repository if not already present
    if ! grep -q "trixie-backports" /etc/apt/sources.list; then
        echo "deb http://deb.debian.org/debian/ trixie-backports main contrib non-free" >> /etc/apt/sources.list
        echo "   [Added trixie-backports to sources.list]"
    fi
fi

# 2. Update and install packages
echo "-> Updating package lists..."
apt-get update -y

echo "-> Installing scrcpy, adb, zenity, and python3-gi..."
# Install scrcpy and adb from backports for the latest updates
apt-get install -t trixie-backports -y scrcpy adb
# Install zenity and python3-gi for GUI and control bar
apt-get install -y zenity python3-gi

# 3. Install scripts into /usr/local/bin
echo "-> Installing launcher script and control bar..."
cp scrcpy-launcher.sh /usr/local/bin/scrcpy-launcher.sh
chmod +x /usr/local/bin/scrcpy-launcher.sh

cp scrcpy-control-bar.py /usr/local/bin/scrcpy-control-bar.py
chmod +x /usr/local/bin/scrcpy-control-bar.py

echo "-> Installing custom app icon..."
mkdir -p /usr/local/share/android-monitoring
cp icon.jpg /usr/local/share/android-monitoring/icon.jpg

# 4. Configure desktop entry for showapps (GNOME)
# Identify the original user (non-root) running sudo
REAL_USER=$SUDO_USER
if [ -z "$REAL_USER" ]; then
    REAL_USER=$(whoami)
fi

USER_HOME=$(eval echo ~$REAL_USER)
USER_APP_DIR="$USER_HOME/.local/share/applications"

echo "-> Creating desktop entry for user: $REAL_USER..."
mkdir -p "$USER_APP_DIR"
cp scrcpy.desktop "$USER_APP_DIR/scrcpy.desktop"
chmod +x "$USER_APP_DIR/scrcpy.desktop"
chown -R $REAL_USER:$REAL_USER "$USER_APP_DIR/scrcpy.desktop"

# 5. Configure udev rules for UHID (physical keyboard simulation)
echo "-> Configuring udev rules for UHID (physical keyboard)..."
echo 'KERNEL=="uhid", MODE="0666"' > /etc/udev/rules.d/99-uhid.rules
udevadm control --reload-rules && udevadm trigger

# Refresh desktop database for the user
sudo -u $REAL_USER update-desktop-database "$USER_APP_DIR" >/dev/null 2>&1

echo "============================================="
echo " Installation Completed Successfully!"
echo "============================================="
echo "How to use:"
echo "1. Connect your Android phone via USB cable."
echo "2. Make sure USB Debugging is enabled in developer options."
echo "3. Open GNOME Applications and click on 'Android Mirroring'."
echo "4. Authorize the connection on your phone screen when prompted."
