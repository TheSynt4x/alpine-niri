#!/bin/sh

set -eu

if ! command -v jq >/dev/null 2>&1; then
  printf '{"text":"%s","tooltip":"jq is missing"}\n' ""
  exit 0
fi

json_from_niri() {
  niri msg --json "$1" 2>/dev/null || printf '{}'
}

workspaces_json=$(json_from_niri workspaces)
windows_json=$(json_from_niri windows)

printf '%s\n%s\n' "$workspaces_json" "$windows_json" | jq -s -r '
  def unwrap_workspaces:
    if type == "array" then .
    elif .Ok? then (.Ok.Workspaces // .Ok.workspaces // .Ok // [])
    elif .Workspaces? then .Workspaces
    elif .workspaces? then .workspaces
    else [] end;

  def unwrap_windows:
    if type == "array" then .
    elif .Ok? then (.Ok.Windows // .Ok.windows // .Ok // [])
    elif .Windows? then .Windows
    elif .windows? then .windows
    else [] end;

  def icon_for($app; $title):
    ($app // "" | ascii_downcase) as $a
    | ($title // "" | ascii_downcase) as $t
    | if ($a | test("firefox|librewolf|floorp")) then "󰈹"
      elif ($a | test("alacritty|kitty|foot|wezterm|ghostty|st|terminator")) then ""
      elif ($a | test("nautilus|org\\.gnome\\.nautilus|dolphin|thunar|pcmanfm|nemo")) then "󰉋"
      elif ($a | test("wofi|bemenu|dmenu|rofi")) then "󰍉"
      elif ($a | test("pavucontrol")) then "󰕾"
      elif ($a | test("blueman")) then ""
      elif ($a | test("mako")) then "󰟻"
      elif ($t | test("browser")) then "󰈹"
      else "󰊠"
      end;

  (.[0] | unwrap_workspaces) as $workspaces
  | (.[1] | unwrap_windows) as $windows
  | $workspaces
    | sort_by(.idx // .id // 0)
    | map(
        . as $ws
        | ($windows
            | map(select((.workspace_id // empty) == ($ws.id // $ws.idx)))
            | map(icon_for(.app_id; .title))
            | unique
            | join(" ")
          ) as $icons
        | ((if ($ws.is_focused // false) then "●" else "○" end)
          + (if ($ws.name? and ($ws.name|tostring) != "") then ($ws.name|tostring) else (($ws.idx // $ws.id // 0) | tostring) end)
          + (if $icons != "" then " " + $icons else "" end))
      )
    | join("  ")
    | {"text": ., "tooltip": "Workspace app icons"}
'
