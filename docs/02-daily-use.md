[← Back to the README](../README.md)

# Daily use

Open the same sandbox from your terminal, editor, or AI workspace application.
After the initial connection setup, select your saved connection to resume work.

- [Connect and run Claude](#connect-and-run-claude)
- [SSH connection settings](#ssh-connection-settings)
- [IntelliJ IDEA](#intellij-idea)
- [AI workspace application](#ai-workspace-application)
- [Add another project or tool](#add-another-project-or-tool)
- [Other agents](#other-agents)
- [Access changes from host checkout](#access-changes-from-host-checkout)

## Connect and run Claude

On the host:

```bash
ssh gradle-ai-workspace.sbx
```

Inside the sandbox:

```bash
cd ~/projects/gradle
claude --yolo
```

> [!NOTE]
> The setup kit adds `--yolo` as a convenience alias for Claude Code's
> `--dangerously-skip-permissions` mode. It must be the first argument.
> Arguments placed after `--yolo` are passed through, so commands such as
> `claude --yolo --model opus` also work. This mode disables Claude Code's
> permission prompts; the surrounding SBX filesystem and network boundaries
> still apply. Use plain `claude` to keep permission prompts.

You can also connect without SSH. On the host:

```bash
sbx env run --name gradle-ai-workspace .sbxenv.yaml  # Attach the managed Claude session from this repository.
sbx exec -it gradle-ai-workspace bash               # Open a shell from any directory.
```

### Claude authentication

**Claude subscription:** Run this inside Claude and complete the sign-in:

```text
/login
```

**Anthropic API key:** If you use an API key instead, store it on the host
before creating the environment:

```bash
sbx secret set anthropic
```

## SSH connection settings

**Frequency:** Once per developer machine after installing or upgrading Docker SBX.

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

## IntelliJ IDEA

For daily work, open **Remote Development**, select the saved SSH connection
and project, and reconnect. Use the remote IDE normally for editing, navigation,
and Gradle tasks. Its built-in terminal also runs inside the sandbox and can
start Claude, Codex, or another installed agent.

**First-time setup:** Once per project connection.

1. Choose **File → Remote Development**, or launch **JetBrains Gateway**
   directly. Select the **SSH** provider and click **New Connection**.
2. In the SSH configuration dialog, enable **Parse config file ~/.ssh/config**
   and enter `gradle-ai-workspace.sbx` as the host. Leave the port, user name,
   and key unset; the parsed configuration supplies them.
3. Check the connection and continue.
4. Select an IntelliJ IDEA version for the backend, set the project directory
   to `/home/agent/projects/PROJECT_A`, and start the connection.

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

## AI workspace application

For daily work, open the saved `gradle-ai-workspace.sbx` SSH target and select
the project folder under `/home/agent/projects`. Connecting starts the sandbox
if it is stopped. Editing, terminals, agents, Git operations, and builds then
run remotely while the application provides its local interface.

**First-time setup:** Once per application and project connection.

Any editor or AI workspace application that supports remote development over
SSH can use this environment. For example, in
[Orca](https://www.onorca.dev/docs/ssh):

1. Open **Settings → SSH** and click **Add Target**.
2. Enter `gradle-ai-workspace.sbx` as the host. Leave the identity file unset
   and let Orca resolve the effective settings from `~/.ssh/config`.
3. Click **Test**, verify the host key if prompted, and then click **Save**.
4. Add an existing remote repository or folder using that SSH target and select
   `/home/agent/projects/PROJECT_A`.
5. Open the remote project and start Claude, Codex, or another installed agent.

On its first connection, Orca installs a relay under `/home/agent/.orca-remote`.
The relay can compile the native `node-pty` module on Linux; this environment's
kit installs `build-essential` and Python 3 for that purpose. The initial
connection can therefore take longer than later connections.

## Add another project or tool

Clone additional repositories **inside the sandbox**:

```bash
gh repo clone OWNER/PROJECT_A /home/agent/projects/PROJECT_A
```

Every project shares `/home/agent/.gradle`, including dependency downloads,
wrapper distributions, toolchains, and the local build cache.

To install an additional package, run on the **host**:

```bash
sbx exec -u root gradle-ai-workspace apt-get install -y PACKAGE
```

Installed packages survive restarts. Add tools that every new sandbox needs to
[`kits/gradle-tools/spec.yaml`](../kits/gradle-tools/spec.yaml).
See [Other agents](#other-agents) for additional agent setup.

## Other agents

**Frequency:** Once per sandbox, unless the agent is added to a setup kit.

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

## Access changes from host checkout

Commit changes inside the sandbox first. From the corresponding **host**
checkout, add the sandbox repository as a remote and fetch the branch:

```bash
cd /path/to/host/PROJECT_A
git remote add sbx-gradle-ai-workspace \
  gradle-ai-workspace.sbx:/home/agent/projects/PROJECT_A
git fetch sbx-gradle-ai-workspace

git log sbx-gradle-ai-workspace/ai/my-change
git diff main..sbx-gradle-ai-workspace/ai/my-change
git switch --track -c ai/my-change sbx-gradle-ai-workspace/ai/my-change
```

Add the remote once; subsequent updates only need `git fetch`. Replace
`ai/my-change` with your branch. Alternatively, push a sandbox branch to its
normal `origin` and fetch it from the host.
