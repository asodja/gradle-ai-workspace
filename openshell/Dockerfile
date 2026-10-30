# Workload image for the OpenShell variant of gradle-ai-workspace.
# Build from the repository root so the shared kit files are in the context:
#   docker build -f openshell/Dockerfile -t gradle-ai-workspace:latest .
#
# Mirrors kits/gradle-tools/spec.yaml: Java 8/17/25, native build tools,
# Python 3, Vim, Git, GitHub CLI, Claude Code, and the shared agent
# instructions. OpenShell replaces CMD with its supervisor, so the image
# defines no entrypoint.

FROM ubuntu:26.04

ARG DEBIAN_FRONTEND=noninteractive
# "latest" resolves at build time. Pin a version for reproducible images.
ARG CLAUDE_CODE_VERSION=latest

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl git gh python3 vim \
      openjdk-8-jdk-headless openjdk-17-jdk-headless openjdk-25-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

# Claude Code lives at one fixed real path. OpenShell network rules and the
# claude-code provider profile match binaries by real path, and the native
# installer's versioned layout under ~/.local/share would change on every
# update. Upgrades therefore happen by rebuilding the image.
RUN set -eu; \
    case "$(dpkg --print-architecture)" in \
      amd64) platform=linux-x64 ;; \
      arm64) platform=linux-arm64 ;; \
      *) echo "unsupported architecture" >&2; exit 1 ;; \
    esac; \
    base=https://downloads.claude.ai/claude-code-releases; \
    version="$CLAUDE_CODE_VERSION"; \
    if [ "$version" = latest ]; then version="$(curl -fsSL "$base/latest")"; fi; \
    curl -fsSL "$base/$version/manifest.json" -o /tmp/manifest.json; \
    checksum="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["platforms"][sys.argv[2]]["checksum"])' /tmp/manifest.json "$platform")"; \
    curl -fsSL "$base/$version/$platform/claude" -o /usr/local/bin/claude; \
    echo "$checksum  /usr/local/bin/claude" | sha256sum -c -; \
    chmod 0755 /usr/local/bin/claude; \
    rm /tmp/manifest.json; \
    /usr/local/bin/claude --version

# The Ubuntu base image ships a placeholder "ubuntu" user with UID 1000.
# Replace it with "agent" so paths match the Docker SBX workspace and the
# OpenShell default identity.
RUN userdel -r ubuntu \
    && useradd --uid 1000 --user-group --create-home --shell /bin/bash agent

COPY --chown=agent:agent kits/gradle-tools/files/home/.config /home/agent/.config
COPY openshell/files/java-trust.sh /usr/local/share/openshell/java-trust.sh

# Login shells read /etc/profile.d, interactive shells read /etc/bash.bashrc,
# and scripts such as gradlew read BASH_ENV. All of them need the Java trust
# setup; the function guard keeps repeated sourcing harmless.
RUN set -eu; \
    install -d -o agent -g agent \
      /home/agent/.claude /home/agent/.codex /home/agent/projects /home/agent/.gradle; \
    for target in /home/agent/.claude/CLAUDE.md /home/agent/.codex/AGENTS.md; do \
      install -o agent -g agent -m 0644 /home/agent/.config/agents/AGENTS.md "$target"; \
    done; \
    ln -s /usr/local/share/openshell/java-trust.sh /etc/profile.d/openshell-java-trust.sh; \
    printf '\n. /usr/local/share/openshell/java-trust.sh\n. /home/agent/.config/scripts/claude-yolo.sh\n' >> /etc/bash.bashrc

# A policy shipped in the image applies when a sandbox is created without
# --policy. Network rules can still be changed later with `openshell policy`.
COPY openshell/policy.yaml /etc/openshell/policy.yaml

# OpenShell sessions start with a minimal environment and do not inherit
# these; create.sh passes the same variables with --env.
ENV GRADLE_USER_HOME=/home/agent/.gradle \
    DISABLE_AUTOUPDATER=1 \
    BASH_ENV=/usr/local/share/openshell/java-trust.sh

# WORKDIR becomes the OpenShell workspace: the read-write root of the sandbox,
# and the default target of `openshell sandbox upload` and `download`.
WORKDIR /home/agent
USER agent
