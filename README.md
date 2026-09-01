# Gradle AI workspace

This repository defines a shared Docker SBX environment for running coding
agents against many Gradle projects. It creates one persistent sandbox named
`gradle-ai-workspace` with:

- private project clones under `/home/agent/projects`;
- one sandbox-native Gradle cache at `/home/agent/.gradle`;
- 8 CPUs and 32 GB of memory;
- Claude Code as the Docker-managed agent;
- Java 8, Java 17, Java 25, and native build tools installed at creation;
- GitHub credentials resolved from each developer's host `gh` login;
- SSH access for remote-development clients.

This is a configuration repository, not a parent checkout for development
repositories. It intentionally contains only the environment, its installation
kit, and this documentation. Development repositories are cloned independently
inside the sandbox rather than added here as submodules or mounted from the
host.

## Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Create the environment](#create-the-environment)
- [Lifecycle](#lifecycle)
  - [Recreate with different resources or configuration](#recreate-with-different-resources-or-configuration)
- [Dashboard and status](#dashboard-and-status)
- [Set up projects](#set-up-projects)
- [Connect to the sandbox](#connect-to-the-sandbox)
  - [Connect over SSH or with sbx](#connect-over-ssh-or-with-sbx)
  - [Connect from an AI workspace application](#connect-from-an-ai-workspace-application)
  - [Connect from IntelliJ IDEA](#connect-from-intellij-idea)
- [Move changes to a host checkout](#move-changes-to-a-host-checkout)
- [Secrets](#secrets)
  - [Develocity access key](#develocity-access-key)
- [Use with other agents](#use-with-other-agents)
- [Security boundary](#security-boundary)

## Overview

One long-lived sandbox holds every project, agent, and build cache. The host
keeps only this configuration repository, an SSH client, and the editor.

```text
  HOST (developer machine)
  ┌───────────────────────────────────────────────────────────┐
  │  ai-workspace/  — this repository, configuration only     │
  │    .sbxenv.yaml           sandbox, resources, secrets     │
  │    kits/gradle-tools/     JDKs and native build tools     │
  │                                                           │
  │  gh auth token  ─────────────────►  github secret         │
  │  editor / AI workspace app  ─────►  ssh *.sbx             │
  └───────────────┬──────────────────────────────┬────────────┘
                  │ sbx env create .             │ SSH
                  ▼                              ▼
  SANDBOX gradle-ai-workspace — 8 CPUs, 32 GB, persistent
  ┌───────────────────────────────────────────────────────────┐
  │  /home/agent/projects/                                    │
  │    PROJECT_A        PROJECT_B        PROJECT_C            │
  │        └────────────────┴─────────────────┘               │
  │                         ▼                                 │
  │  /home/agent/.gradle   — shared GRADLE_USER_HOME          │
  │    dependency cache, wrappers, toolchains, build cache,   │
  │    Develocity access key                                  │
  │                                                           │
  │  agents   Claude Code (Docker-managed), Codex, others     │
  │  tools    Java 8/17/25, build-essential, Python 3         │
  │                                                           │
  │  /run/sandbox/source  — read-only copy of this repository │
  └───────────────────────────────────────────────────────────┘
```

The arrangement follows from four decisions:

- **Configuration is separate from code.** This repository declares the
  environment; it never contains the projects. Development repositories are
  cloned inside the sandbox, so the environment can be shared without sharing
  anyone's working state.
- **One sandbox, many projects.** Projects that build against each other stay
  in a single trust boundary and a single machine-sized pool of CPU and memory.
- **One Gradle User Home.** `GRADLE_USER_HOME` points at sandbox-native
  storage, so downloads, toolchains, and the Develocity key are paid for once
  and reused by every project, agent, and restart.
- **The host stays clean.** Agents, builds, and terminals run in the sandbox.
  The host contributes credentials over short-lived secrets and an editor over
  SSH, and receives finished work by fetching from the sandbox as a Git remote.

## Prerequisites

- Docker SBX 0.39.0 or newer;
- GitHub CLI (`gh`) authenticated on the host;
- OpenSSH on the host;
- a Claude subscription or Anthropic API key.

Verify the tools and authenticate:

```bash
sbx version
sbx login
gh auth status
sbx setup ssh
```

Use `gh auth login` if `gh auth status` reports that no account is active.

## Create the environment

Clone this configuration repository, enter it, and create the declared
sandbox:

```bash
git clone TEAM_CONFIGURATION_REPOSITORY_URL ai-workspace
cd ai-workspace
sbx env create .
```

The sandbox root filesystem defaults to 20 GB, which a shared Gradle cache, the
IDE backend, and a few project clones exhaust quickly. Disk sizes cannot
yet be declared in `.sbxenv.yaml`
([sbx#465](https://github.com/docker/sbx-releases/issues/465)), so set the size
on the creation command instead:

```bash
DOCKER_SANDBOXES_ROOT_SIZE=90g sbx env create .
```

`DOCKER_SANDBOXES_DOCKER_SIZE` and `DOCKER_SANDBOXES_CLONED_WORKSPACE_SIZE`
size `/var/lib/docker` and the cloned workspace the same way. All three are
read only at creation; see Docker's
[troubleshooting guide](https://docs.docker.com/ai/sandboxes/troubleshooting/#sandbox-runs-out-of-disk-space).

`ai-workspace` is only the local checkout of this small configuration
repository. It does not contain the development projects. Those are cloned
separately under `/home/agent/projects` inside `gradle-ai-workspace`.

The first creation installs `build-essential`, Python 3, Java 8, Java 17, and
Java 25 on top of Docker's Ubuntu-based sandbox image. Gradle detects all three
JDK installations under `/usr/lib/jvm` for toolchain selection. Java 8 comes
from Ubuntu's `universe` component, which the base image enables by default.
Later starts retain installed packages, private repositories, Gradle caches,
and toolchains.

## Lifecycle

Stop the sandbox without losing its state:

```bash
sbx stop gradle-ai-workspace
```

An SSH connection or `sbx env run .` starts it again. Before removing the
sandbox, commit and fetch or push every change that must be retained:

```bash
sbx env rm .
```

Removing the environment deletes all private repositories, unpushed work,
Gradle caches, downloaded toolchains, installed packages, and sandbox-scoped
secrets.

Changes to kits, workspaces, secrets, or sandbox resource options require
recreating the environment. Preserve project work before doing so. Memory,
CPUs, and disk sizes are fixed when the sandbox is created; nothing resizes
them in place, so raising one means recreating the sandbox. The procedure below
preserves its name and root-filesystem data across that recreation.

### Recreate with different resources or configuration

To change creation-time properties such as memory, CPU, or disk size, recreate
the sandbox because SBX cannot change them in place. SBX also cannot rename a
sandbox. To keep the stable name `gradle-ai-workspace`, save the old root
filesystem as a local template, remove the old environment, and recreate it
under the same name from that template.

> [!WARNING]
> This procedure has downtime, and the recreated sandbox cannot be tested
> before the old sandbox is removed because both cannot have the same name.
> The local template is the rollback copy. If `sbx template save` fails or the
> saved tag does not appear in `sbx template ls`, stop and do not remove the
> environment. Never run `sbx reset` during the migration: reset also deletes
> locally cached templates.

The template preserves the writable root filesystem, including
`/home/agent/.gradle`, `/home/agent/projects`, installed packages, downloaded
toolchains, and other files under `/home/agent`. Commit and push or fetch all
important Git work as an independent backup anyway. Stop active builds and the
sandbox, save it under a unique local tag, and confirm that the tag exists:

```bash
sbx stop gradle-ai-workspace
sbx template save \
  gradle-ai-workspace \
  gradle-ai-workspace-migration:2026-09-01
sbx template ls
```

The template also contains secrets written to the filesystem, including the
Develocity access key under `/home/agent/.gradle`. Keep it local; do not export,
publish, or share it.

Create an uncommitted temporary file named `restore.sbxenv.yaml` containing:

```yaml
sandboxOptions:
  template: gradle-ai-workspace-migration:2026-09-01
  pullPolicy: never
```

The partial file will be merged over `.sbxenv.yaml` during creation. It does
not declare `name`, so the replacement retains `gradle-ai-workspace` from the
main environment file. While `.sbxenv.yaml` still describes the old
environment, remove it:

```bash
sbx env rm .
```

Update the permanent CPU, memory, kit, workspace, or other settings in
`.sbxenv.yaml`, but keep the existing name. For example:

```yaml
name: gradle-ai-workspace

sandboxOptions:
  cpus: 8
  memory: 32g
```

SBX 0.39.0 limits a sandbox to 32 GiB of memory; check `sbx create --help`
after upgrading in case that limit changes. Disk capacities are independent
and must be supplied when the replacement is created:

```bash
DOCKER_SANDBOXES_ROOT_SIZE=90g \
DOCKER_SANDBOXES_DOCKER_SIZE=50g \
DOCKER_SANDBOXES_CLONED_WORKSPACE_SIZE=50g \
  sbx env create . restore.sbxenv.yaml
```

The disk variables control different data:

- `DOCKER_SANDBOXES_ROOT_SIZE` contains `/home/agent/.gradle`,
  `/home/agent/projects`, installed packages, and most sandbox state;
- `DOCKER_SANDBOXES_DOCKER_SIZE` contains the private Docker daemon's
  `/var/lib/docker` data;
- `DOCKER_SANDBOXES_CLONED_WORKSPACE_SIZE` contains the private clone of this
  control repository because `workspace.clone` is enabled.

The template preserves the root filesystem. Do not rely on it to preserve the
separate Docker data or cloned-workspace disks; rebuild Docker images and make
sure required workspace commits exist on the host or a Git remote.

If creation fails, do not delete the template. Correct the configuration or
disk sizes and retry the same `sbx env create` command. After creation succeeds,
verify the new capacity and restored data before resuming normal work:

```bash
sbx exec gradle-ai-workspace df -h /
sbx exec gradle-ai-workspace du -sh /home/agent/.gradle
sbx exec gradle-ai-workspace du -sh /home/agent/projects
```

Connect to the recreated environment, inspect every project's `git status`,
and run a representative offline build to prove that the required cache entries
are present:

```bash
ssh gradle-ai-workspace.sbx
cd /home/agent/projects/PROJECT_A
git status
./gradlew help --offline
```

After verification, delete `restore.sbxenv.yaml`; normal commands use
`.sbxenv.yaml` and attach to the recreated environment. Keep the migration
template until the replacement and independent Git backups are known to be
good. It can then be removed with:

```bash
sbx template rm gradle-ai-workspace-migration:2026-09-01
```

## Dashboard and status

Docker Sandboxes includes an interactive dashboard. Run it on the host from any
directory:

```bash
sbx
```

Running `sbx` with no command opens interactive mode; `sbx tui` opens the same
dashboard explicitly. It covers every sandbox on the host, not only this
environment's `gradle-ai-workspace`.

The same information is available non-interactively, which is easier to script
and to paste into an issue:

```bash
sbx ls           # agent, status, published ports, and workspace
sbx ls --json    # machine-readable output
sbx ls --quiet   # sandbox names only
```

If a command reports that you are not authenticated, run `sbx login`. Run
`sbx diagnose` when connections or the dashboard misbehave.

## Set up projects

Connect once and clone as many repositories as needed:

```bash
ssh gradle-ai-workspace.sbx

mkdir -p /home/agent/projects
gh repo clone OWNER/PROJECT_A /home/agent/projects/PROJECT_A
gh repo clone OWNER/PROJECT_B /home/agent/projects/PROJECT_B
```

Cloning uses the `github` secret resolved from the host, so no credentials are
entered inside the sandbox.

Every project and agent in this sandbox shares `/home/agent/.gradle`. Gradle's
dependency cache, wrapper distributions, downloaded toolchains, and local build
cache therefore remain available across projects and sandbox restarts.

This is a one-time step per repository. The clones survive restarts and are
deleted with the environment, so push or fetch anything that must outlive it.

## Connect to the sandbox

Docker exposes the sandbox as an OpenSSH-compatible target, so one environment
is reachable from a terminal, from an editor, and from a full IDE. Run the SSH
setup once on the host and verify the connection before configuring any
application:

```bash
sbx setup ssh
ssh gradle-ai-workspace.sbx
```

Use these connection values wherever an application asks for them:

| Setting | Value |
| --- | --- |
| SSH host | `gradle-ai-workspace.sbx` |
| Project folder | `/home/agent/projects/PROJECT_A` |
| Authentication | Host OpenSSH configuration created by `sbx setup ssh` |

Enter the hostname manually when an application's SSH picker does not list it.
Docker registers a wildcard `*.sbx` host in `~/.ssh/config`, so individual
sandbox names might not appear in host pickers. Do not replace the hostname
with `localhost`, provide a normal SSH key, or use the host macOS username.
The Docker-managed `ProxyCommand` selects the sandbox and supplies its default
user without an SSH server listening on port 22.

See Docker's [editor and app integration guide](https://docs.docker.com/ai/sandboxes/integrations/)
for how the `.sbx` SSH transport works. Docker documents VS Code, Cursor, and
several other clients there; JetBrains IDEs are not listed but connect over the
same transport.

### Connect over SSH or with sbx

A plain SSH session is the simplest way in:

```bash
ssh gradle-ai-workspace.sbx
```

`sbx` reaches the same sandbox without SSH and starts it if it is stopped:

```bash
sbx env run .                            # attach the managed Claude session
sbx exec -it gradle-ai-workspace bash    # open a shell
sbx exec -u root gradle-ai-workspace apt-get install -y PACKAGE
```

Packages installed that way survive restarts but are lost when the environment
is removed. Add anything that must always be present to
`kits/gradle-tools/spec.yaml` instead.

If no Anthropic API key is configured, run `/login` inside Claude and sign in
with the team's Claude subscription. To use an API key instead, store it on the
host before creating the environment:

```bash
sbx secret set anthropic
```

### Connect from an AI workspace application

Any editor or AI workspace application that supports remote development over
SSH can use this environment. For example, in
[Orca](https://www.onorca.dev/docs/ssh):

1. Open **Settings → SSH** and click **Add Target**.
2. Enter `gradle-ai-workspace.sbx` as the host. Leave the identity file unset
   and let Orca resolve the effective settings from `~/.ssh/config`.
3. Click **Test**, verify the host key if prompted, and then click **Save**.
4. Add an existing remote repository or folder using that SSH target and select
   `/home/agent/projects/PROJECT_A`.
5. Start Claude, Codex, or another installed agent. Its process, terminals,
   Git worktrees, and builds run inside the sandbox while Orca provides the
   local editor and diff interface.

On its first connection, Orca installs a relay under `/home/agent/.orca-remote`.
The relay can compile the native `node-pty` module on Linux; this environment's
kit installs `build-essential` and Python 3 for that purpose. The initial
connection can therefore take longer than later connections.

### Connect from IntelliJ IDEA

1. Choose **File → Remote Development**, or launch **JetBrains Gateway**
   directly. Select the **SSH** provider and click **New Connection**.
2. In the SSH configuration dialog, enable **Parse config file ~/.ssh/config**
   and enter `gradle-ai-workspace.sbx` as the host. Leave the port, user name,
   and key unset; the parsed configuration supplies them.
3. Check the connection and continue.
4. Select an IntelliJ IDEA version for the backend, set the project directory
   to `/home/agent/projects/PROJECT_A`, and start the connection.
5. Open the built-in terminal in the remote IDE and start Claude, Codex, or
   another installed agent. The agent, its terminals, and Gradle run inside the
   sandbox while the local thin client provides the editor.

Enabling **Parse config file ~/.ssh/config** is what makes this work. JetBrains
remote development supports the `ProxyCommand` directive that Docker's `*.sbx`
entry relies on, but not `ProxyJump`. Typing a host, port, and user name into
the dialog by hand instead bypasses that entry and fails to connect. Existing
configurations can be edited later under
**Settings → Tools → SSH Configurations**.

The first connection downloads the IDE backend into
`/home/agent/.cache/JetBrains/RemoteDev/dist` and therefore takes noticeably
longer than later ones. That directory is the single largest consumer of the
root filesystem — it reached 5.7 GB here, because each backend version is kept
alongside the previous ones. Delete the versions no longer in use when disk
runs short. The backend survives sandbox restarts and is removed
with the environment. It is self-contained on this glibc-based image and needs
no extra packages; the kit's `curl` covers its download requirement.

Point **Gradle JVM** at one of the installed JDKs under `/usr/lib/jvm` in
**Settings → Build, Execution, Deployment → Build Tools → Gradle**. Toolchain
resolution then uses the same shared `/home/agent/.gradle` as every other
project and agent in the sandbox.

## Move changes to a host checkout

Commit changes inside the sandbox first. Any sandbox repository can then be
used as an SSH Git remote from its corresponding host checkout:

```bash
cd /path/to/host/PROJECT_A
git remote add sbx-gradle-ai-workspace \
  gradle-ai-workspace.sbx:/home/agent/projects/PROJECT_A
git fetch sbx-gradle-ai-workspace

git log sbx-gradle-ai-workspace/ai/my-change
git diff main..sbx-gradle-ai-workspace/ai/my-change
git switch --track -c ai/my-change sbx-gradle-ai-workspace/ai/my-change
```

Alternatively, push a sandbox branch to its normal `origin` and fetch it from
the host.

## Secrets

`.sbxenv.yaml` declares the GitHub secret using:

```yaml
secrets:
  github:
    command: gh auth token
```

The command executes on each developer's host. The token itself is not stored
in this repository or copied into the sandbox. Do not replace it with a literal
token value.

### Develocity access key

Provision a personal Develocity access key from one Develocity-enabled Gradle
project inside the sandbox:

```bash
ssh gradle-ai-workspace.sbx
cd /home/agent/projects/PROJECT_A
./gradlew provisionDevelocityAccessKey
```

If Gradle cannot open a browser, copy the URL printed in the terminal into a
browser on the host and complete the sign-in there. The key is stored in the
shared Gradle User Home at:

```text
/home/agent/.gradle/develocity/keys.properties
```

This only needs to be done once per sandbox, not once per project. The key is
available to every project and agent in that sandbox and remains across
sandbox restarts. It is deleted when the environment is removed. Treat it like
a password and never commit it or put a literal value in `.sbxenv.yaml`.

The interactive command is the recommended setup for this persistent sandbox.
For disposable or automated environments, Develocity also supports the
`DEVELOCITY_ACCESS_KEY` environment variable in
`develocity.example.com=ACCESS_KEY` form. Resolve that value from a secret
manager at runtime rather than storing it in this repository.

## Use with other agents

Claude is the managed agent, but additional command-line agents can be
installed inside the persistent sandbox and use the same projects and Gradle
cache. For example, install and run Codex with:

```bash
ssh gradle-ai-workspace.sbx
curl -fsSL https://chatgpt.com/codex/install.sh | sh

cd /home/agent/projects/PROJECT_A
codex login --device-auth
codex
```

Device-code authentication is suitable for the sandbox's headless SSH session.
If it is not enabled for the ChatGPT account or workspace, run `codex login`
and follow the available sign-in flow. The installation and login state remain
until the sandbox is removed. Install other agents in the same way, following
their official Linux installation and authentication instructions.

## Security boundary

Keep `workspace.clone: true`. Changing it to direct mode would let agents write
to this host checkout, including future environment configuration.

Clone mode still exposes this host repository read-only at
`/run/sandbox/source`, including ignored and untracked files. Do not store
credentials or other sensitive files anywhere beneath this repository.

All projects and agents inside `gradle-ai-workspace` share one trust boundary.
Use separate sandboxes when projects must not see or affect one another.
