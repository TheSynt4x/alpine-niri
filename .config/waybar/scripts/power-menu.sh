#!/bin/sh

entries=$(printf '%s\n' "⏾ Hibernate" "Suspend" "⭮ Reboot" "⏻ Shutdown")

selected=$(printf '%s\n' "$entries" | wofi --width 250 --height 210 --dmenu --cache-file /dev/null | awk '{print tolower($NF)}')

case $selected in
  hibernate)
    gtklock &
    sleep 1
    systemctl hibernate;;
  suspend)
    systemctl suspend;;
  reboot)
    systemctl reboot;;
  shutdown)
    systemctl poweroff;;
esac 
