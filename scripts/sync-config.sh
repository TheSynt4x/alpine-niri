#!/bin/sh

set -e

if [ -n "$1" ]; then
  SOURCE_ROOT=$1
else
  SOURCE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
fi

SUSER=$(awk -F: '$3 == 1000 {print $1}' /etc/passwd)

if [ -z "$SUSER" ]; then
  echo "Error: No user with ID 1000 found. Please create a user first."
  exit 1
fi

TARGET_HOME="/home/${SUSER}"
SOURCE_CONFIG="${SOURCE_ROOT}/.config"
TARGET_CONFIG="${TARGET_HOME}/.config"

if [ ! -d "$SOURCE_CONFIG" ]; then
  echo "Error: ${SOURCE_CONFIG} not found."
  exit 1
fi

mkdir -p "$TARGET_CONFIG"
cp -a "$SOURCE_CONFIG/." "$TARGET_CONFIG/"
chown -R "${SUSER}:" "$TARGET_CONFIG"
find "/home/${SUSER}/.config" -type f -name "*.sh" -exec chmod +x {} \;

if [ -f "${TARGET_CONFIG}/gtklock/config.ini" ]; then
  sed -i "s|/home/user|/home/${SUSER}|g" "${TARGET_CONFIG}/gtklock/config.ini"
fi

echo "Synced .config to ${TARGET_HOME}."
