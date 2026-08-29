# AI workspace for Gradle projects

This repository defines a shared Docker SBX environment for running coding
agents against many Gradle projects. It creates one persistent sandbox named
`gradle-hub` with:

- private project clones under `/home/agent/projects`;
- one sandbox-native Gradle cache at `/home/agent/.gradle`;
- Java 21 and native build tools installed at creation;
- GitHub credentials resolved from each developer's host `gh` login;
- SSH access for Orca and other remote-development clients.

The repository is intentionally small. It contains only the environment, its
installation kit, and this documentation. Development repositories are not
added as submodules or mounted from the host.

## Prerequisites

- Docker SBX 0.39.0 or newer;
- GitHub CLI (`gh`) authenticated on the host;
- OpenSSH on the host;
- Orca, Codex, or another client as desired.

Verify the tools and authenticate:

```bash
sbx version
sbx login
gh auth status
sbx setup ssh
```

Use `gh auth login` if `gh auth status` reports that no account is active.

## Create the environment

Clone this repository, enter it, and create the declared sandbox:

```bash
git clone TEAM_REPOSITORY_URL ai-workspace
cd ai-workspace
sbx env create .
```

The first creation installs `build-essential` and Java 21. Later starts retain
installed packages, private repositories, Gradle caches, and toolchains.

For machine-specific resource limits, create an ignored local override:

```bash
cp local.sbxenv.example.yaml local.sbxenv.yaml
sbx env create . local.sbxenv.yaml
```

When using an override, pass the same files to later `sbx env` lifecycle
commands.

## Connect and clone projects

Connect over SSH and clone as many repositories as needed:

```bash
ssh gradle-hub.sbx

mkdir -p /home/agent/projects
gh repo clone OWNER/PROJECT_A /home/agent/projects/PROJECT_A
gh repo clone OWNER/PROJECT_B /home/agent/projects/PROJECT_B
```

Every project and agent in this sandbox shares `/home/agent/.gradle`. Gradle's
dependency cache, wrapper distributions, downloaded toolchains, and local build
cache therefore remain available across projects and sandbox restarts.

To attach the built-in Codex session instead of SSH:

```bash
sbx env run .
```

## Use with Orca

1. Add the concrete SSH target `gradle-hub.sbx` in Orca.
2. Leave user and identity file empty unless Orca requires a user; then use
   `_default_user_`.
3. Disable **Reuse SSH connection** under Advanced Connection.
4. Add repositories using paths such as
   `/home/agent/projects/PROJECT_A`.
5. Give concurrent agents separate Git branches or Orca worktrees.

## Move changes to a host checkout

Commit changes inside the sandbox first. Any sandbox repository can then be
used as an SSH Git remote from its corresponding host checkout:

```bash
cd /path/to/host/PROJECT_A
git remote add sbx-gradle-hub \
  gradle-hub.sbx:/home/agent/projects/PROJECT_A
git fetch sbx-gradle-hub

git log sbx-gradle-hub/ai/my-change
git diff main..sbx-gradle-hub/ai/my-change
git switch --track -c ai/my-change sbx-gradle-hub/ai/my-change
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

## Lifecycle

Stop the sandbox without losing its state:

```bash
sbx stop gradle-hub
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
recreating the environment. Preserve project work before doing so.

## Security boundary

Keep `workspace.clone: true`. Changing it to direct mode would let agents write
to this host checkout, including future environment configuration.

Clone mode still exposes this host repository read-only at
`/run/sandbox/source`, including ignored and untracked files. Do not store
credentials or other sensitive files anywhere beneath this repository.

All projects and agents inside `gradle-hub` share one trust boundary. Use
separate sandboxes when projects must not see or affect one another.

