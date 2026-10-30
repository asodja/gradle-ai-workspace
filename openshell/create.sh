#!/usr/bin/env bash
# Build the workload image and create the gradle-ai-workspace sandbox on the
# local OpenShell gateway. Run on the host from any directory.
#
# Environment overrides:
#   SANDBOX_NAME   sandbox name                      (default: gradle-ai-workspace)
#   IMAGE          image tag to build and use        (default: gradle-ai-workspace:latest)
#   CPUS, MEMORY   sandbox size                      (default: 8, 32Gi)
#   PERSIST        "0" skips the named volumes; the workspace then lives only
#                  in the container's writable layer
#   ANTHROPIC_API_KEY  when set, a claude-code provider is created and attached;
#                  when unset, use /login inside Claude Code instead
set -euo pipefail

cd "$(dirname "$0")/.."

name="${SANDBOX_NAME:-gradle-ai-workspace}"
image="${IMAGE:-gradle-ai-workspace:latest}"
cpus="${CPUS:-8}"
memory="${MEMORY:-32Gi}"
persist="${PERSIST:-1}"

openshell status >/dev/null

echo "==> Building $image"
docker build -f openshell/Dockerfile -t "$image" .

echo "==> Importing provider profiles"
# Lint checks against the gateway catalog and rejects an id that is already
# imported, so lint and import only profiles the gateway does not have yet.
profiles="$(openshell provider list-profiles 2>/dev/null || true)"
for profile in github claude-code; do
  if grep -qw "$profile" <<<"$profiles"; then
    echo "profile $profile already imported"
  else
    openshell provider profile lint -f "openshell/providers/$profile.yaml"
    openshell provider profile import -f "openshell/providers/$profile.yaml"
  fi
done

echo "==> Creating providers"
providers=(--provider github)
if openshell provider get github >/dev/null 2>&1; then
  echo "provider github exists; refresh it with:"
  echo "  GITHUB_TOKEN=\"\$(gh auth token)\" openshell provider update github --from-existing"
else
  GITHUB_TOKEN="$(gh auth token)" \
    openshell provider create --name github --type github --from-existing
fi

if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  providers+=(--provider claude-code)
  if ! openshell provider get claude-code >/dev/null 2>&1; then
    openshell provider create --name claude-code --type claude-code --from-existing
  fi
else
  echo "ANTHROPIC_API_KEY is unset; run /login inside Claude Code"
fi

driver_config=()
if [ "$persist" != 0 ]; then
  echo "==> Creating persistent volumes"
  for volume in projects gradle; do
    docker volume create \
      --label openshell.ai/sandbox-attachable=true \
      --label openshell.ai/sandbox-attachable-workspace=default \
      "$name-$volume" >/dev/null
  done
  driver_config=(--driver-config-json "$(cat <<EOF
{"docker":{"mounts":[
  {"type":"volume","source":"$name-projects","target":"/home/agent/projects","read_only":false},
  {"type":"volume","source":"$name-gradle","target":"/home/agent/.gradle","read_only":false}
]}}
EOF
)")
fi

echo "==> Creating sandbox $name"
# `sleep infinity` keeps the sandbox running; shells, agents, and IDE
# backends attach with exec or SSH instead of owning the main process.
# OpenShell sessions do not inherit the image's ENV, so the variables the
# Dockerfile declares are repeated here.
openshell sandbox create \
  --name "$name" \
  --from "$image" \
  --cpu "$cpus" \
  --memory "$memory" \
  "${providers[@]}" \
  "${driver_config[@]}" \
  --env GRADLE_USER_HOME=/home/agent/.gradle \
  --env DISABLE_AUTOUPDATER=1 \
  --env BASH_ENV=/usr/local/share/openshell/java-trust.sh \
  --detach \
  -- sleep infinity

echo
echo "Sandbox ready. Open a shell with:"
echo "  openshell sandbox exec -n $name --tty -- bash -l"
echo "For IntelliJ, Orca, or ssh, add this host entry to ~/.ssh/config:"
openshell sandbox ssh-config "$name"
