#!/bin/sh
set -eu

status="$(tlp-stat -s 2>/dev/null || true)"
profile="$(printf '%s\n' "$status" | sed -n 's/^[[:space:]]*Power profile[[:space:]]*=[[:space:]]*//p' | head -n1)"
mode="$(printf '%s\n' "$status" | sed -n 's/^[[:space:]]*Mode[[:space:]]*=[[:space:]]*//p' | head -n1)"

if [ -z "${profile:-}" ] && [ -n "${mode:-}" ]; then
  profile="$mode"
fi

case "$profile" in
  performance/*|performance)
    next="balanced"
    ;;
  balanced/*|balanced)
    next="powersave"
    ;;
  powersave/*|power-saver/*|powersave|power-saver)
    next="performance"
    ;;
  *)
    next="balanced"
    ;;
esac

exec doas tlp setprofile "$next"