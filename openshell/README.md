[← Back to the README](../README.md)

# OpenShell variant (experimental)

This directory defines the same workspace for
[NVIDIA OpenShell](https://docs.nvidia.com/openshell/latest/about/overview)
instead of Docker SBX. It exists to evaluate OpenShell; `.sbxenv.yaml` and the
kit on `main` remain the supported setup.

## What changes

| Concern | Docker SBX (`main`) | OpenShell (this directory) |
| --- | --- | --- |
| Definition | `.sbxenv.yaml` plus a setup kit that installs tools into a running sandbox | `Dockerfile` builds the image; `policy.yaml` baked into it; provider profiles for credentials; `create.sh` ties them together |
| Isolation | microVM; full outbound network | Container (or microVM runtime) plus Landlock, seccomp, and a per-binary network allowlist. Every outbound connection is denied unless a rule allows it |
| Credentials | `gh auth token` copied into the sandbox and refreshed every 55 minutes | The agent never sees the GitHub token or Anthropic key. The OpenShell proxy injects them only on requests to the hosts the provider profile names |
| Claude authentication | Subscription `/login` or API key | API key through the `claude-code` provider is the documented path. `/login` is allowed by a network rule but untested |
| Persistence | Everything survives restarts until `sbx env rm` | Container writable layer survives stop and start. Named volumes for `~/projects` and `~/.gradle` survive container replacement |
| Adding tools | `sbx exec -u root ... apt-get install` | No root in the sandbox. Add packages to the `Dockerfile` and rebuild |
| Connect | `ssh gradle-ai-workspace.sbx` | `openshell sandbox exec`, or an SSH host entry that uses `openshell ssh-proxy` as `ProxyCommand` |
| Policy changes | None | Network rules hot-reload; the policy advisor drafts rules from denials; the prover checks changes against a boundary |
| Audit | None | Every allowed and denied connection is logged, exportable as OCSF JSON |

## Prerequisites

On the host:

- Docker Desktop 28 or newer with at least 8 CPUs and 32 GiB allotted to its VM,
  or lower `CPUS` and `MEMORY` when running `create.sh`.
- GitHub CLI, logged in (`gh auth login`).
- OpenShell CLI and gateway:

  ```bash
  curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | sh
  openshell status
  ```

- For persistent volumes, merge [`gateway.toml.example`](gateway.toml.example)
  into `~/.config/openshell/gateway.toml` and restart the gateway. Skip this
  and run with `PERSIST=0` to try the workspace without it.

Optional: export `ANTHROPIC_API_KEY` before running `create.sh` to attach the
`claude-code` provider. Without it, run `/login` inside Claude Code.

## Create the workspace

```bash
git clone -b openshell https://github.com/asodja/gradle-ai-workspace.git ai-workspace
cd ai-workspace
./openshell/create.sh
```

The script builds `gradle-ai-workspace:latest`, imports the two provider
profiles, creates a `github` provider from `gh auth token`, creates the two
labeled volumes, and starts the sandbox with `sleep infinity` as its main
process. Repeated runs reuse existing profiles, providers, and volumes.

## Work in the sandbox

```bash
openshell sandbox exec -n gradle-ai-workspace --tty -- bash -l
```

Inside:

```bash
gh repo clone gradle/gradle ~/projects/gradle
cd ~/projects/gradle
claude --yolo
```

The `--yolo` alias and the shared agent instructions come from the same kit
files as the SBX setup.

### IntelliJ IDEA and Orca

`create.sh` prints an SSH host block. Append it to `~/.ssh/config`:

```bash
openshell sandbox ssh-config gradle-ai-workspace >> ~/.ssh/config
```

The entry is named `openshell-gradle-ai-workspace.default` and uses a
`ProxyCommand`, like the `*.sbx` entry from Docker SBX. Point IntelliJ
Remote Development or Orca at that host with **Parse config file ~/.ssh/config**
enabled, and open `/home/agent/projects/PROJECT`.

Untested: the IDE backend download. JetBrains downloads it either on the
host and uploads it over SSH, or inside the sandbox from
`download.jetbrains.com`. The second path needs a network rule.

### Java and the OpenShell proxy

OpenShell terminates TLS for inspected hosts with a per-sandbox CA. It exports
that CA through `SSL_CERT_FILE` and friends, which curl, git, Node, and Python
honor but the JVM does not. [`files/java-trust.sh`](files/java-trust.sh) runs
from `BASH_ENV` and `/etc/bash.bashrc`, builds a truststore containing the CA
under `~/.cache/openshell-java`, and sets `JAVA_TOOL_OPTIONS`. It also sets
`-Djava.net.preferIPv4Stack=true`, because the JVM otherwise connects to
IPv4-mapped IPv6 addresses that the proxy cannot match to a hostname. Every JVM
start prints `Picked up JAVA_TOOL_OPTIONS`, as it does in the SBX workspace.

### When a build is denied network access

Gradle reports a connection failure. On the host:

```bash
openshell logs gradle-ai-workspace --since 5m --source sandbox   # Shows the denied host and binary.
openshell rule get gradle-ai-workspace --status pending          # The advisor's drafted rule.
openshell rule approve gradle-ai-workspace --chunk-id <id>       # Hot-reloads without a restart.
```

To make the change permanent, add the host to [`policy.yaml`](policy.yaml)
and rebuild. Rules list the executable that opens the connection, so Gradle,
Kotlin, and toolchain downloads are matched by the `java` globs, not `gradlew`.

### Refresh the GitHub token

```bash
GITHUB_TOKEN="$(gh auth token)" openshell provider update github --from-existing
```

Running sandboxes pick up the new credential without a restart.

## Stop, start, remove

```bash
openshell sandbox stop gradle-ai-workspace
openshell sandbox start gradle-ai-workspace
openshell sandbox delete gradle-ai-workspace
docker volume rm gradle-ai-workspace-projects gradle-ai-workspace-gradle   # Deletes projects and caches.
```

## What has been tested

Tested on 2026-10-30 with OpenShell 0.1.6, Docker driver, gateway run from the
upstream Docker Compose files, inside a Linux arm64 VM:

- `create.sh` end to end: image build, profile import, provider creation,
  labeled volumes, sandbox creation.
- Landlock: writes under `/home/agent` succeed, writes to `/etc` fail.
- Network: `curl https://example.com` is denied; `git clone` from GitHub
  works; the Gradle wrapper downloads a distribution (via the redirect to
  GitHub release assets), resolves JUnit from Maven Central, and runs tests.
- Credential injection: a test provider's placeholder was replaced by the
  real secret for both `Authorization: Bearer` and `Authorization: token`
  headers, so `gh` and `git` both receive a usable credential.
- Volumes: `~/projects` survived deleting and recreating the sandbox.
- Hot policy update: `openshell policy update --add-endpoint` took effect
  without a restart.

Not tested: `gh` against GitHub with a real token (the test VM only had a
proxy-managed placeholder token), Claude Code itself, IntelliJ and Orca over
the SSH `ProxyCommand`, and macOS Docker Desktop.

## Known gaps

- Claude subscription login is not covered by the OpenShell docs; the
  `claude_code` network rule in `policy.yaml` allows the OAuth hosts, but the
  flow has not been tested.
- Claude Code is pinned at build time (`DISABLE_AUTOUPDATER=1`). Rebuild the
  image to upgrade it.
- The host list in `policy.yaml` covers Gradle distributions, GitHub release
  downloads, Maven Central, the Gradle plugin portal and Artifactory, Google
  Maven, Foojay and Adoptium toolchains, and Develocity at `ge.gradle.org`.
  Other repositories need rules.
- JVMs started outside bash, for example by an IDE backend that bypasses the
  user's shell, do not get `JAVA_TOOL_OPTIONS` and fail with PKIX errors.
- Codex and other agents must be added to the `Dockerfile`; `curl ... | sh`
  installers have no network access and no root.
- OpenShell 0.1.x is young. 0.1.0 shipped breaking CLI changes; expect more.
