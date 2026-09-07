# Translate the familiar --yolo shorthand to Claude Code's bypass mode.
claude() {
  if [ "${1:-}" = "--yolo" ]; then
    shift
    command claude --dangerously-skip-permissions "$@"
  else
    command claude "$@"
  fi
}
