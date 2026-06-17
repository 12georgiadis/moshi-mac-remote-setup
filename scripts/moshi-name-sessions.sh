#!/bin/bash
# moshi-name-sessions.sh
#
# Rename the tmux sessions that cmux creates (ttysNNN) to the friendly cmux
# workspace title, so the Moshi app (iPhone / Apple Watch) shows them by name
# instead of "ttys000". Idempotent: only touches sessions still named ttysNNN
# (already-renamed ones are left alone), so it is safe to run on a schedule.
#
# Meant to be run periodically by launchd (see com.example.moshi-name-sessions.plist).
# Uninstall: launchctl unload ~/Library/LaunchAgents/<your-label>.plist

TMUX_BIN=/opt/homebrew/bin/tmux
CMUX_BIN=/Applications/cmux.app/Contents/Resources/bin/cmux
JQ=/opt/homebrew/bin/jq

# real tmux on the default socket, free of any inherited cmux/tmux env
T() { env -u TMUX -u TMUX_PANE "$TMUX_BIN" -L default "$@"; }

[ -x "$CMUX_BIN" ] || exit 0
[ -x "$JQ" ] || JQ=jq

# map: cmux workspace_id -> friendly title
tmpmap=$(mktemp)
"$CMUX_BIN" rpc debug.terminals 2>/dev/null \
  | "$JQ" -r '.terminals[] | "\(.workspace_id)\t\(.workspace_title)"' > "$tmpmap" 2>/dev/null
[ -s "$tmpmap" ] || { rm -f "$tmpmap"; exit 0; }

while read -r pid cmd; do
  sess=$(echo "$cmd" | sed -nE 's/.*-s ([^ ]+).*/\1/p')
  [ -z "$sess" ] && continue
  case "$sess" in ttys[0-9]*) : ;; *) continue ;; esac   # only not-yet-named sessions
  T has-session -t "$sess" 2>/dev/null || continue
  # the cmux workspace id lives in the env of the `tmux new-session` process
  wsid=$(ps eww "$pid" 2>/dev/null | tr ' ' '\n' | grep '^CMUX_WORKSPACE_ID=' | cut -d= -f2)
  [ -z "$wsid" ] && continue
  title=$(grep -F "$wsid" "$tmpmap" 2>/dev/null | head -1 | cut -f2)
  [ -z "$title" ] && continue
  clean=$(echo "$title" | sed 's/[^a-zA-Z0-9 ._-]//g' | tr -s ' ' | sed 's/^ *//; s/ *$//' | cut -c1-28)
  [ -z "$clean" ] && continue
  # de-duplicate against existing session names
  key="$clean"; n=2
  while T has-session -t "$key" 2>/dev/null; do key="$clean $n"; n=$((n+1)); done
  T rename-session -t "$sess" "$key" 2>/dev/null \
    && echo "$(date '+%F %T')  $sess -> $key" >> "$HOME/.moshi-rename.log"
done < <(ps -Ao pid,command | grep '[t]mux new-session')

rm -f "$tmpmap"
exit 0
