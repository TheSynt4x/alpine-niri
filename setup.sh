#!/bin/sh

set -e

echo "Installing the absolute bare minimum for Niri..."
echo "To continue press RETURN, to abort Ctrl-c"
read n

# --- 1. Reliable Repository Setup ---
VERSION_ID="3.23"
REPO_URL="https://dl-cdn.alpinelinux.org/alpine"

cat << EOF > /etc/apk/repositories
$REPO_URL/v$VERSION_ID/main
$REPO_URL/v$VERSION_ID/community
$REPO_URL/edge/testing
$REPO_URL/edge/main
$REPO_URL/edge/community
EOF

apk update
# save old world
cp /etc/apk/world /tmp/world

# Added the missing essentials for Wayland/Mesa
cat << EOF > /etc/apk/world
tzdata
alpine-base
dbus
eudev
curl
greetd
greetd-tuigreet
linux-firmware-other
linux-lts
linux-pam
fontconfig
doas
gcompat
tlp
tlp-pd
bluez
bluez-openrc
blueman
cups
cups-filters
cups-openrc
avahi
avahi-openrc
elogind
elogind-openrc
polkit-elogind
polkit-openrc
polkit-gnome

mesa-dri-gallium
mesa-egl
mesa-gbm
mesa-gl

wayland
libxkbcommon

nix
shadow
shadow-login

niri
alacritty
wofi
udev-init-scripts
udev-init-scripts-openrc
nautilus
waybar
mako
networkmanager
networkmanager-wifi
networkmanager-cli
networkmanager-tui
networkmanager-dmenu
iwd
swaybg
gtklock
firefox
pavucontrol
fastfetch
micro
font-dejavu
font-jetbrains-mono-nerd
adwaita-icon-theme
hicolor-icon-theme

zsh
docker
docker-compose
nodejs
git

xdg-utils
xdg-desktop-portal
xdg-desktop-portal-wlr
pipewire
pipewire-pulse
pipewire-spa-bluez
wireplumber
EOF

apk update
apk upgrade

# restore old world
while read pkg; do
  apk add "$pkg"
done < /tmp/world

setup-timezone -z Europe/Stockholm

# Find user with id 1000
SUSER=$(awk -F: '$3 == 1000 {print $1}' /etc/passwd)
SUSERID=$(id -u $SUSER)

if [ -z "$SUSER" ]; then
  echo "Error: No user with ID 1000 found. Please create a user first."
  exit 1
fi

# setup services
setup-devd udev
rc-update add elogind default
rc-update add dbus
adduser ${SUSER} lp
adduser ${SUSER} lpadmin

adduser ${SUSER} netdev
rc-update add iwd default

echo "permit keepenv :wheel" > /etc/apk/doas.conf
addgroup "$SUSER" wheel || true

for TARGET in "/home/$SUSER" "/root"; do
    # Add to .profile
    echo "alias sudo='doas'" >> "$TARGET/.profile"
    echo "alias nano='micro'" >> "$TARGET/.profile"
    
    # Add to .zshrc (if it exists)
    if [ -f "$TARGET/.zshrc" ]; then
        echo "alias sudo='doas'" >> "$TARGET/.zshrc"
        echo "alias nano='micro'" >> "$TARGET/.zshrc"
    fi
done

addgroup greetd tty || true

# config greetd
cat << EOF > /etc/conf.d/greetd
rc_need=elogind
EOF

mkdir -p /etc/greetd
cat << EOF > /etc/greetd/config.toml
[terminal]
vt = 7

[default_session]
command = "tuigreet --remember --time --cmd 'dbus-run-session niri --session'"
user = "greetd"
EOF

# 3. Create the cache directory so --remember actually works
mkdir -p /var/cache/greetd
chown greetd:greetd /var/cache/greetd

rc-update add greetd

# --- Environment & Alias Setup ---
setup_env_for_user() {
  local target_user=$1
  local target_home=$2
  local profile_file="$target_home/.profile"

  echo "Configuring environment for $target_user..."

  # Create permanent Nix config (This fixes the screenshot error)
  mkdir -p "$target_home/.config/nixpkgs"
  cat << EOF > "$target_home/.config/nixpkgs/config.nix"
{ allowUnfree = true; }
EOF

  # Create or overwrite .profile
  cat << EOF > "$profile_file"
# Desktop & App Defaults
export TERMINAL=alacritty
export EXPLORER=nautilus
export XDG_CURRENT_DESKTOP=niri
export XDG_SESSION_TYPE=wayland
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland

# Nix Permissions (Crucial for root doas/sudo)
export NIXPKGS_ALLOW_UNFREE=1

# Aliases
alias nano='micro'
alias vi='micro'
EOF

  chown "${target_user}:" "$profile_file"

  # Sync to .zshrc if it exists (Ensures interactivity works)
  if [ -f "$target_home/.zshrc" ]; then
    # Remove existing aliases if they exist to prevent duplicates
    sed -i '/alias nano=/d' "$target_home/.zshrc"
    
    echo "alias nano='micro'" >> "$target_home/.zshrc"
    echo "export NIXPKGS_ALLOW_UNFREE=1" >> "$target_home/.zshrc"
  fi
}

# Apply to your main user and root
setup_env_for_user "${SUSER}" "/home/${SUSER}"
setup_env_for_user "root" "/root"

# Dotfiles from repository (run setup.sh from the repo root, e.g. ./setup.sh)
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

if [ -d "${SCRIPT_DIR}/.config" ]; then
  mkdir -p "/home/${SUSER}/.config"
  cp -a "${SCRIPT_DIR}/.config/." "/home/${SUSER}/.config/"
  chown -R "${SUSER}:" "/home/${SUSER}/.config"
else
  echo "Warning: ${SCRIPT_DIR}/.config not found; skipping dotfiles copy."
fi

if [ -f "/home/${SUSER}/.config/gtklock/config.ini" ]; then
  sed -i "s|/home/user|/home/${SUSER}|g" "/home/${SUSER}/.config/gtklock/config.ini"
fi

if [ -f "/home/${SUSER}/.config/niri/scripts/startup.sh" ]; then
  chmod +x "/home/${SUSER}/.config/niri/scripts/startup.sh"
fi

if [ -d "${SCRIPT_DIR}/wallpapers" ]; then
  cp -a "${SCRIPT_DIR}/wallpapers" "/home/${SUSER}/"
  chown -R "${SUSER}:" "/home/${SUSER}/wallpapers"
else
  echo "Warning: ${SCRIPT_DIR}/wallpapers not found; skipping wallpapers copy."
fi

find /root/.cache/nix -name "*.sqlite" -delete 2>/dev/null || true

mkdir -p /etc/nix

# Configure Nix for flakes
cat <<EOF > /etc/nix/nix.conf
allowed-users = root
trusted-users = root
build-users-group = nixbld
max-jobs = 4
extra-experimental-features = nix-command flakes
EOF

resolve_system_bin() {
  command -p -v "$1"
}

REAL_NIX=$(resolve_system_bin nix)
REAL_NIX_ENV=$(resolve_system_bin nix-env)
REAL_NIX_CHANNEL=$(resolve_system_bin nix-channel)
REAL_NIX_BUILD=$(resolve_system_bin nix-build)
REAL_NIX_SHELL=$(resolve_system_bin nix-shell)
REAL_NIX_STORE=$(resolve_system_bin nix-store)

install_nix_wrapper() {
  local name=$1
  local real_bin=$2

  cat <<EOF > "/usr/local/bin/$name"
#!/bin/sh

if [ "\$(id -u)" -ne 0 ]; then
  echo "nix on this system must be run with doas: doas $name \"\$@\"" >&2
  exit 1
fi

exec "$real_bin" "\$@"
EOF
  chmod +x "/usr/local/bin/$name"
}

install_nix_wrapper nix "$REAL_NIX"
install_nix_wrapper nix-env "$REAL_NIX_ENV"
install_nix_wrapper nix-channel "$REAL_NIX_CHANNEL"
install_nix_wrapper nix-build "$REAL_NIX_BUILD"
install_nix_wrapper nix-shell "$REAL_NIX_SHELL"
install_nix_wrapper nix-store "$REAL_NIX_STORE"

cat <<'EOF' > /usr/local/bin/sudo
#!/bin/sh
exec doas "$@"
EOF
chmod +x /usr/local/bin/sudo

# Enable nix-daemon on boot
rc-update add nix-daemon
rc-service nix-daemon restart

nix-channel --add https://nixos.org/channels/nixos-unstable nixpkgs
nix-channel --add https://github.com/nix-community/nixGL/archive/main.tar.gz nixgl
nix-channel --update
nix-env -iA nixgl.auto.nixGLDefault

# --- Safe Zsh Setup (No Nuking) ---
chsh -s /bin/zsh $SUSER
chsh -s /bin/zsh root

# Function to install OMZ and plugins for a specific user
setup_zsh_for_user() {
  local target_user=$1
  local target_home=$2
  local z_dir="$target_home/.oh-my-zsh"
  local c_dir="$z_dir/custom"

  # 1. Install OMZ if missing
  if [ ! -d "$z_dir" ]; then
    echo "Installing Oh My Zsh for $target_user..."
    su - ${target_user} -c "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended"
  else
    echo "Oh My Zsh already exists for $target_user, skipping..."
  fi

  if [ -f "$target_home/.zsh_history" ]; then
    echo "Fixing Zsh history for $target_user..."
    mv "$target_home/.zsh_history" "$target_home/.zsh_history_bad"
    strings "$target_home/.zsh_history_bad" > "$target_home/.zsh_history"
    rm "$target_home/.zsh_history_bad"
    chown "${target_user}:" "$target_home/.zsh_history"
  fi

  # 2. Plugins (Clone if missing, Pull if exists)
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    local plugin_dir="$c_dir/plugins/$plugin"
    if [ ! -d "$plugin_dir" ]; then
        su - ${target_user} -c "git clone https://github.com/zsh-users/$plugin $plugin_dir"
    else
        su - ${target_user} -c "cd $plugin_dir && git pull"
    fi
  done

  # 3. Fix .zshrc plugins line
  sed -i 's/plugins=(.*)/plugins=(git docker zsh-autosuggestions zsh-syntax-highlighting)/' "$target_home/.zshrc"
}

# Run for the user
setup_zsh_for_user "${SUSER}" "/home/${SUSER}"

# Run for root (so root doesn't complain)
setup_zsh_for_user "root" "/root"

# Install scripts from scripts/ directory
for script in "${SCRIPT_DIR}/scripts/"*.sh; do
    if [ -f "$script" ]; then
        basename_script=$(basename "$script" .sh)
        cp "$script" "/usr/local/bin/$basename_script"
        chmod +x "/usr/local/bin/$basename_script"
        echo "Installed $basename_script to /usr/local/bin/"
    fi
done

fc-cache -fv

rc-update add docker default
rc-service docker start

rc-update add avahi-daemon default
rc-service avahi-daemon start

rc-service elogind start

rc-update add cupsd default
rc-service cupsd start

rc-update add tlp default
rc-update add bluetooth default
rc-service bluetooth start

# --- THE NETWORK SWITCH (Last step before reboot) ---
echo "Configuring NetworkManager and disabling old stack..."

# 1. Config NM
mkdir -p /etc/NetworkManager/conf.d
cat << EOF > /etc/NetworkManager/NetworkManager.conf
[main]
dhcp=internal
plugins=ifupdown,keyfile
[ifupdown]
managed=true
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=yes
EOF

# 2. Config iwd
mkdir -p /etc/iwd
cat << EOF > /etc/iwd/main.conf
[General]
EnableNetworkConfiguration=false
EOF

# 3. Clean up interfaces
if [ -f /etc/network/interfaces ]; then
    echo -e "auto lo\niface lo inet loopback" > /etc/network/interfaces
fi

# 4. Enable/Disable Services
addgroup ${SUSER} netdev || true
addgroup ${SUSER} plugdev || true

rc-update add iwd default
rc-update add networkmanager default
rc-update del networking default 2>/dev/null || true

# Force GTK to use the icons you installed
mkdir -p /home/${SUSER}/.config/gtk-3.0
cat << EOF > /home/${SUSER}/.config/gtk-3.0/settings.ini
[Settings]
gtk-icon-theme-name = Adwaita
gtk-theme-name = Adwaita
gtk-font-name = JetBrainsMono Nerd Font
EOF

chown -R ${SUSER}:${SUSER} /home/${SUSER}

if [ -f "/home/${SUSER}/.config/waybar/scripts/power-menu.sh" ]; then
    chmod +x /home/${SUSER}/.config/waybar/scripts/power-menu.sh
fi

echo "Setup done. Rebooting."
sleep 3
reboot
