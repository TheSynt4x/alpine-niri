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
font-jetbrains-mono-nerd
adwaita-icon-theme
hicolor-icon-theme
curl
greetd
greetd-agreety
linux-firmware-other
linux-lts
linux-pam
fontconfig

mesa-dri-gallium
mesa-egl
mesa-gbm
mesa-gl

wayland
libxkbcommon

nix
shadow

niri
alacritty
wofi
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
pavucontrol

zsh
docker
docker-compose
nodejs
git

xdg-desktop-portal
xdg-desktop-portal-wlr
pipewire
pipewire-pulse
wireplumber 
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
export NIXPKGS_ALLOW_UNFREE=1

export XDG_CURRENT_DESKTOP=niri
export XDG_SESSION_TYPE=wayland
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland

if [ -z "\$USER_SERVICES_STARTED" ]; then
    /usr/bin/pipewire &
    sleep 1
    /usr/bin/pipewire-pulse &
    /usr/bin/wireplumber &
    /usr/libexec/xdg-desktop-portal &
    /usr/libexec/xdg-desktop-portal-wlr &
    export USER_SERVICES_STARTED=1
fi
EOF

chown ${SUSER}: /home/${SUSER}/.profile

# Dotfiles from repository (run setup.sh from the repo root, e.g. ./setup.sh)
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

if [ -d "${SCRIPT_DIR}/.config" ]; then
  mkdir -p "/home/${SUSER}/.config"
  cp -a "${SCRIPT_DIR}/.config/." "/home/${SUSER}/.config/"
  chown -R "${SUSER}:" "/home/${SUSER}/.config"
else
  echo "Warning: ${SCRIPT_DIR}/.config not found; skipping dotfiles copy."
fi

if [ -d "${SCRIPT_DIR}/wallpapers" ]; then
  cp -a "${SCRIPT_DIR}/wallpapers" "/home/${SUSER}/"
  chown -R "${SUSER}:" "/home/${SUSER}/wallpapers"
else
  echo "Warning: ${SCRIPT_DIR}/wallpapers not found; skipping wallpapers copy."
fi

# Install Nix package
apk add --no-cache nix shadow

usermod -aG nix $SUSER

# Configure Nix for flakes
cat <<EOF > /etc/nix/nix.conf
allowed-users = @nix
build-users-group = nixbld
max-jobs = 4
extra-experimental-features = nix-command flakes
EOF

# Enable nix-daemon on boot
rc-update add nix-daemon
rc-service nix-daemon restart

nix-channel --add https://nixos.org/channels/nixos-unstable nixpkgs

# zsh setup
chsh -s /bin/zsh $SUSER

# Define the custom plugin path for clarity
ZSH_CUSTOM_DIR="/home/${SUSER}/.oh-my-zsh/custom"

# Install OMZ as the user
su - ${SUSER} -c "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended"

# Install plugins as the user
su - ${SUSER} -c "git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM_DIR}/plugins/zsh-autosuggestions"
su - ${SUSER} -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM_DIR}/plugins/zsh-syntax-highlighting"

# Fix the .zshrc plugins line (running as root is fine here since we specify the path)
sed -i 's/plugins=(git)/plugins=(git docker zsh-autosuggestions zsh-syntax-highlighting)/' /home/${SUSER}/.zshrc

fc-cache -fv

rc-update add docker default
rc-service docker start

# Force GTK to use the icons you installed
mkdir -p /home/${SUSER}/.config/gtk-3.0
cat << EOF > /home/${SUSER}/.config/gtk-3.0/settings.ini
[Settings]
gtk-icon-theme-name = Adwaita
gtk-theme-name = Adwaita
gtk-font-name = JetBrainsMono Nerd Font
EOF

chown -R ${SUSER}:${SUSER} /home/${SUSER}

echo "Setup done. Rebooting."
sleep 3
reboot
