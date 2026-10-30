# Gradle AI workspace

A ready-to-use development environment for working on Gradle projects with AI
agents. It runs inside Docker SBX, with Java 8, 17, and 25, native build tools,
Python 3, Vim, GitHub CLI, and Claude Code.

Your projects and shared Gradle cache stay in the sandbox across sessions.
Connect through a terminal, IntelliJ IDEA, or Orca.

## Get started

### 1. Prepare your machine

**Once per machine.** Install [Docker SBX](https://docs.docker.com/ai/sandboxes/install/)
(version 0.43.0 or newer) and [GitHub CLI](https://cli.github.com/).
You also need an SSH client and a Claude subscription or Anthropic API key.

On your **host**, authenticate and configure SSH:

```bash
sbx login       # Sign in to Docker.
gh auth login   # Sign in to GitHub.
sbx setup ssh   # Configure SSH access to *.sbx hosts.
```

Skip any of these steps you have already completed.

### 2. Create your workspace

**Once per sandbox.** Run on your **host**:

```bash
git clone https://github.com/asodja/gradle-ai-workspace.git ai-workspace
cd ai-workspace

DOCKER_SANDBOXES_ROOT_SIZE=90g \
DOCKER_SANDBOXES_DOCKER_SIZE=10g \
DOCKER_SANDBOXES_CLONED_WORKSPACE_SIZE=2g \
  sbx env create --name gradle-ai-workspace .sbxenv.yaml
```

This creates `gradle-ai-workspace` with 8 CPUs and 32 GiB of memory and installs
the development tools automatically. Allow a few minutes for the first creation.

The command sets disk capacities for projects and the Gradle cache, Docker
data, and the small configuration checkout. You can start with these defaults;
see [Resource configuration](docs/04-manage.md#resource-configuration) to adjust them.

Using a different name? See
[Use a different sandbox name](docs/04-manage.md#use-a-different-sandbox-name).

### 3. Start working

Connect from your **host**:

```bash
ssh gradle-ai-workspace.sbx
```

Then run **inside the sandbox** to clone Gradle and start Claude:

```bash
mkdir -p ~/projects
gh repo clone gradle/gradle ~/projects/gradle
cd ~/projects/gradle
claude --yolo
```

Use your own `OWNER/REPOSITORY` and folder name if you are working on another
project. GitHub credentials come from your host login. If Claude needs
authentication, run `/login` inside Claude and complete the sign-in.
For API-key authentication, see [Claude authentication](docs/02-daily-use.md#claude-authentication).

**Your workspace is ready.** Next time, reconnect and open your existing project.
You do not need to recreate the environment. Configure the credentials below
when your project requires them.

## Connect your tools

Choose the tools you use; each link contains the first-time connection steps.

| Tool | How to connect |
| --- | --- |
| [IntelliJ IDEA](docs/02-daily-use.md#intellij-idea) | Open Remote Development, connect to `gradle-ai-workspace.sbx`, and select your project. |
| [Orca or another AI workspace app](docs/02-daily-use.md#ai-workspace-application) | Add `gradle-ai-workspace.sbx` as an SSH target and open a repository under `/home/agent/projects`. |
| [Terminal](docs/02-daily-use.md#connect-and-run-claude) | Run `ssh gradle-ai-workspace.sbx`. |

If the sandbox does not appear in an application's SSH picker, enter its
hostname manually. See [SSH connection settings](docs/02-daily-use.md#ssh-connection-settings).

## Configure project credentials

These are separate from creating the workspace. Configure them when your
project requires them.

| Integration | When you need it | How often |
| --- | --- | --- |
| [Commit signing](docs/03-credentials.md#commit-signing) | Sign commits with your SSH key | Register each key once with GitHub; configure Git per sandbox |
| [Develocity](docs/03-credentials.md#develocity-access-key) | Authenticate builds with your Develocity server | Once per sandbox |

## Further reading

- [How the workspace works](docs/01-overview.md) — architecture, shared caches,
  and the security boundary.
- [Daily use](docs/02-daily-use.md) — terminals, IntelliJ, Orca, adding projects and tools,
  and accessing changes from a host checkout.
- [Credentials and authentication](docs/03-credentials.md) — GitHub authentication,
  SSH commit signing, and Develocity access.
- [Manage the environment](docs/04-manage.md) — dashboard, start/stop, removal,
  diagnostics, and resource configuration.
- [Recreate the environment](docs/05-recreate.md) — host backups, snapshots,
  restoring projects, and recovering from stop failures.

Projects and caches survive restarts but are deleted when the environment is
removed. Push or fetch important work before removal.

An experimental [NVIDIA OpenShell](openshell/README.md) variant of this
workspace lives in the `openshell/` directory.
