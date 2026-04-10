#!/bin/sh

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)

SUSER=$(awk -F: '$3 == 1000 {print $1}' /etc/passwd)

if [ -z "$SUSER" ]; then
  echo "Error: No user with ID 1000 found. Please create a user first."
  exit 1
fi

TARGET_HOME="/home/${SUSER}"
SOURCE_CONFIG="${SCRIPT_DIR}/.config"
TARGET_CONFIG="${TARGET_HOME}/.config"

if [ ! -d "$SOURCE_CONFIG" ]; then
  echo "Error: ${SOURCE_CONFIG} not found."
  exit 1
fi

mkdir -p "$TARGET_CONFIG"
cp -a "$SOURCE_CONFIG/." "$TARGET_CONFIG/"
chown -R "${SUSER}:" "$TARGET_CONFIG"

if [ -f "${TARGET_CONFIG}/gtklock/config.ini" ]; then
  sed -i "s|/home/user|/home/${SUSER}|g" "${TARGET_CONFIG}/gtklock/config.ini"
fi

if [ -f "${TARGET_CONFIG}/niri/scripts/startup.sh" ]; then
  chmod +x "${TARGET_CONFIG}/niri/scripts/startup.sh"
fi

if [ -f "${TARGET_CONFIG}/waybar/scripts/power-menu.sh" ]; then
  chmod +x "${TARGET_CONFIG}/waybar/scripts/power-menu.sh"
fi

echo "Synced .config to ${TARGET_HOME}."
