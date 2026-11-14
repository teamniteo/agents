#!/bin/bash
# Claude Code SessionEnd hook: stop processes the session left running
# (dev servers, databases, headless Chrome), including orphans reparented to
# launchd.
#
# Claude Code exports CLAUDE_CODE_SESSION_ID to every process it spawns and
# orphans keep it, so processes are matched on that variable in their
# environment. macOS hides the environment of Apple platform binaries
# (/usr/bin/*), so those are never matched.
#
# Usage:
#   cleanup.sh                     hook mode, reads the SessionEnd JSON on stdin
#   cleanup.sh --escalate <sid>    SIGKILL whatever still matches <sid>
#   DRY_RUN=1 cleanup.sh           list matches instead of signalling them
#
# Requires JQ to point at a jq binary.

# Shared daemons a session may start on demand but other sessions and
# terminals keep using. Matched against the executable's basename.
KEEP='^(gpg-agent|ssh-agent|tmux|screen|watchman|nix-daemon)$'

# Print the PIDs of processes tagged with session $1, excluding this script,
# its ancestors, its descendants, and the KEEP list. Works from a single ps
# snapshot; the tag is passed through the environment and compared as a whole
# token, so neither ps nor awk can match through their own arguments.
matching_pids() {
  /bin/ps -wwEaxo pid=,ppid=,command= \
    | TAG="CLAUDE_CODE_SESSION_ID=$1" SELF=$$ KEEP="$KEEP" /usr/bin/awk '
        {
          ppid[$1] = $2
          tagged[$1] = 0
          for (i = 3; i <= NF; i++) if ($i == ENVIRON["TAG"]) { tagged[$1] = 1; break }
          exe = $3; sub(/.*\//, "", exe)
          if (exe ~ ENVIRON["KEEP"]) tagged[$1] = 0
        }
        END {
          self = ENVIRON["SELF"]
          for (p = self; p > 1 && (p in ppid); p = ppid[p]) skip[p] = 1
          for (pid in tagged) {
            if (!tagged[pid] || (pid in skip)) continue
            mine = 0
            for (p = pid; p > 1 && (p in ppid); p = ppid[p]) if (p == self) { mine = 1; break }
            if (!mine) print pid
          }
        }'
}

# Relies on BSD ps (-E prints the environment).
[ "$(/usr/bin/uname)" = Darwin ] || exit 0

if [ "$1" = "--escalate" ]; then
  sid=$2
  sleep 3
  pids=$(matching_pids "$sid")
  [ -n "$pids" ] && kill -KILL $pids 2>/dev/null
  exit 0
fi

input=$(cat)
sid=$(printf '%s' "$input" | "$JQ" -r '.session_id // empty')
reason=$(printf '%s' "$input" | "$JQ" -r '.reason // empty')
[ -n "$sid" ] || exit 0

# /clear and /resume end the session ID but Claude Code keeps running, along
# with its MCP servers and anything the user still needs.
case "$reason" in
  clear | resume) exit 0 ;;
esac

pids=$(matching_pids "$sid")
[ -n "$pids" ] || exit 0

if [ -n "$DRY_RUN" ]; then
  /bin/ps -o pid=,etime=,comm= -p "$(echo $pids | /usr/bin/tr ' ' ',')"
  exit 0
fi

kill -TERM $pids 2>/dev/null

# Escalate in a new session so it survives Claude Code tearing down the hook's
# process group. It re-matches instead of reusing PIDs, so a recycled PID is
# never signalled.
/usr/bin/perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV' \
  /bin/bash "${BASH_SOURCE[0]}" --escalate "$sid" </dev/null >/dev/null 2>&1 &
exit 0
