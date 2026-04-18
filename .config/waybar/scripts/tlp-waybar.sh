#!/bin/sh
set -eu

status="$(tlp-stat -s 2>/dev/null || true)"

profile="$(printf '%s\n' "$status" | sed -n 's/^[[:space:]]*Power profile[[:space:]]*=[[:space:]]*//p' | head -n1)"
power_source="$(printf '%s\n' "$status" | sed -n 's/^[[:space:]]*Power source[[:space:]]*=[[:space:]]*//p' | head -n1)"
mode="$(printf '%s\n' "$status" | sed -n 's/^[[:space:]]*Mode[[:space:]]*=[[:space:]]*//p' | head -n1)"

if [ -z "${profile:-}" ] && [ -n "${mode:-}" ]; then
  profile="$mode"
fi

if [ -z "${profile:-}" ]; then
  profile="unknown"
fi

if [ -z "${power_source:-}" ]; then
  power_source="unknown"
fi

case "$profile" in
  performance/*|performance)
    icon=""
    class="performance"
    ;;
  balanced/*|balanced)
    icon=""
    class="balanced"
    ;;
  powersave/*|power-saver/*|powersave|power-saver)
    icon=""
    class="powersave"
    ;;
  *)
    case "$power_source" in
      battery)
        icon="󰂄"
        class="battery"
        ;;
      AC|ac|mains)
        icon=""
        class="ac"
        ;;
      *)
        icon="󱐋"
        class="unknown"
        ;;
    esac
    ;;
esac

tooltip="TLP profile: $profile
Power source: $power_source"

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
  "$icon" \
  "$(printf '%s' "$tooltip" | sed ':a;N;$!ba;s/\n/\\n/g;s/"/\\"/g')" \
  "$class"