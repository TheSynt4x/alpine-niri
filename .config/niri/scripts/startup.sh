#!/bin/sh

dbus-update-activation-environment --all

pipewire &
pipewire-pulse &
wireplumber &
for agent in \
  /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 \
  /usr/libexec/polkit-gnome-authentication-agent-1
do
  if [ -x "$agent" ]; then
    "$agent" &
    break
  fi
done
/usr/libexec/xdg-desktop-portal-wlr &
/usr/libexec/xdg-desktop-portal &
doas /usr/sbin/tlp-pd &

swaybg -i "$HOME/wallpapers/wall.jpg" -m fill &
waybar &
mako &
