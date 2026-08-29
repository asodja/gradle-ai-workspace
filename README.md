# Gradle Docker SBX hub

This repository defines a shared Docker SBX environment for running coding
agents against many Gradle projects. By default it creates one persistent
sandbox named `gradle-hub` with:

- private project clones under `/home/agent/projects`;
- one sandbox-native Gradle cache at `/home/agent/.gradle`;
- 8 CPUs and 16 GB of memory;
- Claude Code as the Docker-managed agent;
- Java 25 and native build tools installed at creation;
- GitHub credentials resolved from each developer's host `gh` login;
- SSH access for remote-development clients.

This is a configuration repository, not a parent checkout for development
repositories. It intentionally contains only the environment, its installation
kit, and this documentation. Development repositories are cloned independently
inside the sandbox rather than added here as submodules or mounted from the
host.

## Contents

- [Prerequisites](#prerequisites)
- [Create the environment](#create-the-environment)
- [Connect and clone projects](#connect-and-clone-projects)
- [Use with other agents](#use-with-other-agents)
- [Move changes to a host checkout](#move-changes-to-a-host-checkout)
- [Secrets](#secrets)
  - [Develocity access key](#develocity-access-key)
- [Lifecycle](#lifecycle)
- [Security boundary](#security-boundary)

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

The default name can be overridden per developer with an inline environment
variable:

```bash
SBX_NAME=gradle-hub-alice sbx env create .
```

The remaining examples use the default `gradle-hub` name. With an override,
replace it with the resolved name—for example, `gradle-hub-alice.sbx` for SSH
clients. Prefix later `sbx env` commands with the same assignment. Forgetting it
on `sbx env run` would resolve the default name and could create a separate
`gradle-hub` sandbox.

`ai-workspace` is only the local checkout of this small configuration
repository. It does not contain the development projects. Those are cloned
separately under `/home/agent/projects` inside `gradle-hub`.

The first creation installs `build-essential` and Java 25 on top of Docker's
Claude Code sandbox image. Later starts retain installed packages, private
repositories, Gradle caches, and toolchains.

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

To attach the Docker-managed Claude session instead of SSH:

```bash
sbx env run .
```

If no Anthropic API key is configured, run `/login` inside Claude and sign in
with the team's Claude subscription. To use an API key instead, store it on the
host before creating the environment:

```bash
sbx secret set anthropic
```

## Use with other agents

Claude is the managed agent, but additional command-line agents can be
installed inside the persistent sandbox and use the same projects and Gradle
cache. For example, install and run Codex with:

```bash
ssh "${SBX_NAME:-gradle-hub}.sbx"
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

### Develocity access key

Provision a personal Develocity access key from one Develocity-enabled Gradle
project inside the sandbox:

```bash
ssh "${SBX_NAME:-gradle-hub}.sbx"
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

## Lifecycle

Stop the sandbox without losing its state:

```bash
sbx stop "${SBX_NAME:-gradle-hub}"
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
