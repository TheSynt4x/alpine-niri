#!/bin/sh

set -e

echo "Installing the absolute bare minimum for Niri..."
echo "To continue press RETURN, to abort Ctrl-c"
read n

sed -i '/community/s/^#//g' /etc/apk/repositories

# save old world
cp /etc/apk/world /tmp/world

# Added the missing essentials for Wayland/Mesa
cat << EOF > /etc/apk/world
alpine-base
dbus
eudev
font-dejavu
alacritty
greetd
greetd-agreety
linux-firmware-other
linux-lts
linux-pam
# Critical for VM acceleration:
mesa-dri-gallium
mesa-egl
mesa-gbm
mesa-gl
# Essential Wayland libs:
wayland
libxkbcommon
# Desktop Environment
niri
rofi-wayland
seatd
shadow
shadow-login
udev-init-scripts
udev-init-scripts-openrc
thunar
waybar
mako
iwd
iwgtk
swaybg
swaylock
firefox
pulseaudio
pavucontrol
EOF

apk update
apk upgrade

# restore old world
while read pkg; do
  apk add "$pkg"
done < /tmp/world

# Find user with id 1000
SUSER=$(awk -F: '$3 == 1000 {print $1}' /etc/passwd)
SUSERID=$(id -u $SUSER)

if [ -z "$SUSER" ]; then
  echo "Error: No user with ID 1000 found. Please create a user first."
  exit 1
fi

# setup services
setup-devd udev
rc-update add seatd
rc-update add dbus
adduser ${SUSER} seat
adduser ${SUSER} video
adduser ${SUSER} input
adduser greetd seat
adduser greetd video

adduser ${SUSER} netdev
rc-update add iwd default

# config greetd
cat << EOF > /etc/conf.d/greetd
rc_need=seatd
EOF

cat << EOF > /etc/greetd/config.toml
[terminal]
vt = 7

[default_session]
command = "agreety --cmd 'env LIBSEAT_BACKEND=seatd dbus-run-session niri --session'"
user = "greetd"
EOF

rc-update add greetd

# Set XDG_RUNTIME_DIR
cat << EOF > /home/${SUSER}/.profile
if [ -z "\$XDG_RUNTIME_DIR" ]; then
  XDG_RUNTIME_DIR="/tmp/${SUSERID}-runtime-dir"
  mkdir -pm 0700 \$XDG_RUNTIME_DIR
  export XDG_RUNTIME_DIR
fi
export TERMINAL=alacritty
export EXPLORER=thunar
EOF

chown ${SUSER}: /home/${SUSER}/.profile

# Setup Niri Config Directory
mkdir -p /home/${SUSER}/.config/niri

# Create minimal config.kdl
cat << EOF > /home/${SUSER}/.config/niri/config.kdl
prefer-no-csd

input {
    keyboard {
        xkb {
            layout "us,se"
            options "grp:alt_shift_toggle"
        }
        repeat-delay 200
        repeat-rate 35
    }
}

layout {
    gaps 0
    center-focused-column "never"
    preset-column-widths {
        proportion 1.0
        proportion 0.5
    }
    focus-ring {
        width 0.0
        active-color "#ffffff"
        inactive-color "#000000"
    }
    border {
        off
    }
}

binds {
    Alt+Tab { toggle-overview; }
    Alt+T { spawn "$TERMINAL"; }
    Alt+E { spawn "$EXPLORER"; }
    Alt+R { spawn "rofi" "-show-icons" "-show" "drun"; }
    Alt+C { close-window; }
    Alt+Return { maximize-column; }
    Alt+V { toggle-window-floating; }
    Alt+F { switch-preset-column-width; }

    Alt+H { focus-column-left; }
    Alt+L { focus-column-right; }
    Alt+J { focus-workspace-down; }
    Alt+K { focus-workspace-up; }

    Alt+Shift+H { focus-column-left-or-last; }
    Alt+Shift+L { focus-column-right-or-first; }
    Alt+Shift+J { focus-window-down; }
    Alt+Shift+K { focus-window-up; }

    Ctrl+Alt+H { move-column-left; }
    Ctrl+Alt+L { move-column-right; }
    Ctrl+Alt+J { move-column-to-workspace-down; }
    Ctrl+Alt+K { move-column-to-workspace-up; }

    Alt+1 { focus-workspace 1; }
    Alt+2 { focus-workspace 2; }
    Alt+3 { focus-workspace 3; }
    Alt+4 { focus-workspace 4; }
    Alt+5 { focus-workspace 5; }
    Alt+6 { focus-workspace 6; }
    Alt+7 { focus-workspace 7; }
    Alt+8 { focus-workspace 8; }
    Alt+9 { focus-workspace 9; }

    Ctrl+Alt+1 { move-column-to-workspace 1; }
    Ctrl+Alt+2 { move-column-to-workspace 2; }
    Ctrl+Alt+3 { move-column-to-workspace 3; }
    Ctrl+Alt+4 { move-column-to-workspace 4; }
    Ctrl+Alt+5 { move-column-to-workspace 5; }
    Ctrl+Alt+6 { move-column-to-workspace 6; }
    Ctrl+Alt+7 { move-column-to-workspace 7; }
    Ctrl+Alt+8 { move-column-to-workspace 8; }
    Ctrl+Alt+9 { move-column-to-workspace 9; }

    Alt+WheelScrollDown { focus-workspace-down; }
    Alt+WheelScrollUp { focus-workspace-up; }

    Print { screenshot; }
    Alt+B { spawn "pkill waybar; waybar"; }
    Super+L { spawn "swaylock"; }
}

workspace "1"
workspace "2"
workspace "3"
workspace "4"

spawn-at-startup "waybar"
spawn-at-startup "mako"
EOF

chown -R ${SUSER}: /home/${SUSER}/.config/niri

# TODO: setup nix package manager

echo "Setup done. Rebooting."
sleep 3
reboot
