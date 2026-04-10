#!/bin/sh

dbus-update-activation-environment --all

pipewire &
pipewire-pulse &
wireplumber &
/usr/libexec/xdg-desktop-portal-wlr &
/usr/libexec/xdg-desktop-portal &
tlp-pd &

swaybg -i "$HOME/wallpapers/wall.jpg" -m fill &
waybar &
mako &
