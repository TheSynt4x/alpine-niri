#!/bin/sh
set -eu

workspaces='[]'
windows='[]'
app_defs_file="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/niri-app-icons.json"

if [ -f "$app_defs_file" ]; then
  app_defs="$(cat "$app_defs_file")"
else
  app_defs='{
    "__default__": {
      "icon": "󰣆",
      "color": "#b8b8b8"
    }
  }'
fi

refresh_workspaces() {
  workspaces="$(niri msg --json workspaces 2>/dev/null || printf '[]')"
}

upsert_window() {
  local window_json="$1"
  windows="$(jq -c --argjson w "$window_json" '
    map(select(.id != $w.id)) + [$w]
  ' <<EOF
$windows
EOF
)"
}

remove_window() {
  local window_id="$1"
  windows="$(jq -c --argjson id "$window_id" '
    map(select(.id != $id))
  ' <<EOF
$windows
EOF
)"
}

apply_layout_changes() {
  local changes_json="$1"
  windows="$(jq -c --argjson changes "$changes_json" '
    reduce $changes[] as $chg (
      .;
      map(
        if .id == $chg[0]
        then .layout = $chg[1]
        else .
        end
      )
    )
  ' <<EOF
$windows
EOF
)"
}

render() {
  jq -cn \
    --argjson workspaces "$workspaces" \
    --argjson windows "$windows" \
    --argjson appdefs "$app_defs" '
    def appdef($app):
      $appdefs[$app] // $appdefs["__default__"];

    def appicon($app):
      appdef($app).icon;

    def appcolor($app):
      appdef($app).color;

    def colored_icon($app):
      "<span foreground=\"" + appcolor($app) + "\">" + appicon($app) + "</span>";

    def wins_for($wsid):
      $windows | map(select(.workspace_id == $wsid));

    def sorted_wins_for($wsid):
      wins_for($wsid)
      | sort_by(.layout.pos_in_scrolling_layout[1], .layout.pos_in_scrolling_layout[0]);

    def ws_text($w):
      (sorted_wins_for($w.id) | map(colored_icon(.app_id // .title // "?")) | join(" ")) as $icons
      | (if $w.is_focused
         then "<span bgcolor=\"#f3f3f3\" foreground=\"#121212\" weight=\"bold\"> " + ($w.idx | tostring) + " </span>"
         else "<span foreground=\"#f3f3f3\">" + ($w.idx | tostring) + "</span>"
         end)
        + (if $icons == "" then "" else " " + $icons end);

    def ws_tip($w):
      (sorted_wins_for($w.id)) as $wins
      | ($w.idx | tostring) + ": "
        + (if ($wins | length) == 0
           then "empty"
           else ($wins | map(.app_id // .title // "?") | join(", "))
           end);

    {
      text: (
        $workspaces
        | sort_by(.idx)
        | map(ws_text(.))
        | join("   ")
      ),
      tooltip: (
        $workspaces
        | sort_by(.idx)
        | map(ws_tip(.))
        | join("\n")
      ),
      class: ["niri-workspaces"]
    }'
}

# Get initial state
refresh_workspaces

niri msg --json event-stream | while IFS= read -r line; do
  [ -n "$line" ] || continue

  maybe_workspaces="$(printf '%s\n' "$line" | jq -c 'if has("WorkspacesChanged") then .WorkspacesChanged.workspaces else empty end')"
  if [ -n "${maybe_workspaces:-}" ]; then
    workspaces="$maybe_workspaces"
  fi

  maybe_windows="$(printf '%s\n' "$line" | jq -c 'if has("WindowsChanged") then .WindowsChanged.windows else empty end')"
  if [ -n "${maybe_windows:-}" ]; then
    windows="$maybe_windows"
  fi

  if printf '%s\n' "$line" | jq -e 'has("WorkspaceActivated")' >/dev/null 2>&1; then
    refresh_workspaces
  fi

  maybe_window_upsert="$(printf '%s\n' "$line" | jq -c 'if has("WindowOpenedOrChanged") then .WindowOpenedOrChanged.window else empty end')"
  if [ -n "${maybe_window_upsert:-}" ]; then
    upsert_window "$maybe_window_upsert"
  fi

  maybe_window_closed="$(printf '%s\n' "$line" | jq -r 'if has("WindowClosed") then .WindowClosed.id else empty end')"
  if [ -n "${maybe_window_closed:-}" ]; then
    remove_window "$maybe_window_closed"
  fi

  maybe_layout_changes="$(printf '%s\n' "$line" | jq -c 'if has("WindowLayoutsChanged") then .WindowLayoutsChanged.changes else empty end')"
  if [ -n "${maybe_layout_changes:-}" ]; then
    apply_layout_changes "$maybe_layout_changes"
  fi

  case "$line" in
    *WorkspacesChanged*|*WindowsChanged*|*WorkspaceActivated*|*WindowFocusChanged*|*WindowOpenedOrChanged*|*WindowClosed*|*WindowLayoutsChanged*)
      render
      ;;
  esac
done