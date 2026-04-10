#!/bin/bash

entries="⏾ Hibernate\nSuspend\n⭮ Reboot\n⏻ Shutdown"

selected=$(echo -e $entries | wofi --width 250 --height 210 --dmenu --cache-file /dev/null | awk '{print tolower($NF)}')

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