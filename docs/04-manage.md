[← Back to the README](../README.md)

# Manage the environment

Use these procedures when you need to inspect, stop, or change the sandbox.
Run host commands involving `.sbxenv.yaml` from the root of this configuration
repository, not from `docs/`.

- [Dashboard and status](#dashboard-and-status)
- [Start, stop, and remove the sandbox](#start-stop-and-remove-the-sandbox)
- [Use a different sandbox name](#use-a-different-sandbox-name)
- [Resource configuration](#resource-configuration)
- [Recreate the environment](05-recreate.md)

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

## Start, stop, and remove the sandbox

Stop the sandbox without losing its state:

```bash
sbx stop gradle-ai-workspace
```

An SSH connection or `sbx env run --name gradle-ai-workspace .sbxenv.yaml`
starts it again. Before removing the sandbox, commit and fetch or push every
change that must be retained:

```bash
sbx env rm --name gradle-ai-workspace .sbxenv.yaml
```

Removing the environment deletes all private repositories, unpushed work,
Gradle caches, downloaded toolchains, installed packages, and sandbox-scoped
secrets.

To change creation-time CPU, memory, or disk settings, follow
[Recreate the environment](05-recreate.md). Preserve project work before removing
the existing sandbox.

## Use a different sandbox name

SBX 0.43.0 supports `--name` on every `sbx env` command. It overrides the
`name` in `.sbxenv.yaml`, so the same configuration can create a personal or
temporary test sandbox:

```bash
DOCKER_SANDBOXES_ROOT_SIZE=90g \
DOCKER_SANDBOXES_DOCKER_SIZE=10g \
DOCKER_SANDBOXES_CLONED_WORKSPACE_SIZE=2g \
  sbx env create --name my-workspace .sbxenv.yaml
```

Use the same `--name` and environment-file paths whenever managing that
environment. Without the override, `sbx env` targets the name in the file,
which is `gradle-ai-workspace`:

```bash
ssh my-workspace.sbx                         # Connect over SSH.
sbx env run --name my-workspace .sbxenv.yaml  # Attach the managed agent.
sbx exec -it my-workspace bash               # Open a shell.
sbx stop my-workspace                       # Stop without deleting data.
```

Use `my-workspace.sbx` in IntelliJ or Orca as well. Project paths inside the
sandbox stay the same. To remove this environment after preserving any work:

```bash
sbx env rm --name my-workspace .sbxenv.yaml
```

This creates a separate sandbox with its own projects and caches. It does not
rename an existing sandbox or copy its data. A temporary sandbox is useful for
testing the setup before following the [recreation procedure](05-recreate.md).

## Resource configuration

The shared configuration in [`.sbxenv.yaml`](../.sbxenv.yaml) requests 8 CPUs
and 32 GiB of memory. The quick-start command uses these disk capacities:

| Variable | Size | What it stores |
| --- | --- | --- |
| `DOCKER_SANDBOXES_ROOT_SIZE` | `90g` | Projects, shared Gradle cache, installed packages, and IDE backends |
| `DOCKER_SANDBOXES_DOCKER_SIZE` | `10g` | `/var/lib/docker`: Docker images, containers, volumes, and Docker build cache |
| `DOCKER_SANDBOXES_CLONED_WORKSPACE_SIZE` | `2g` | The private clone of this small configuration repository |

The sandbox root filesystem defaults to 20 GB, which a shared Gradle cache, the
IDE backend, and a few project clones exhaust quickly. Disk sizes cannot yet be
declared in `.sbxenv.yaml`
([sbx#465](https://github.com/docker/sbx-releases/issues/465)), so set the size
on the creation command instead.

The cloned configuration repository does not contain development projects or
Gradle caches. Those live under `/home/agent/projects` and `/home/agent/.gradle`
on the root filesystem.

All disk capacities are fixed at creation. See Docker's
[troubleshooting guide](https://docs.docker.com/ai/sandboxes/troubleshooting/#sandbox-runs-out-of-disk-space)
and the [recreation procedure](05-recreate.md) to change them.

To inspect current usage, run on the host:

```bash
sbx exec gradle-ai-workspace sh -lc 'df -h / /var/lib/docker "$WORKSPACE_DIR"'
```
