[← Back to the README](../README.md)

# Recreate the environment

Run host commands from the root of this configuration repository, not from
`docs/`. These procedures remove and recreate the sandbox; they are not part of
initial setup or daily use.

The examples use the default name `gradle-ai-workspace`. If you created the
environment with `--name`, replace that name throughout (including SSH hosts
and `sbx cp` targets), and pass the same `--name` to every `sbx env` command,
including creation with `restore.sbxenv.yaml`. See
[Use a different sandbox name](04-manage.md#use-a-different-sandbox-name).

- [Recreate from a host project backup](#recreate-from-a-host-project-backup)
- [Recreate from a local template](#recreate-from-a-local-template)

To change creation-time properties such as memory, CPU, or disk size, recreate
the sandbox because SBX cannot change them in place. SBX also cannot rename a
sandbox. Keeping the stable name `gradle-ai-workspace` therefore requires
backing up the required data, removing the old environment, and recreating it
under the same name.

Choose one of these migration methods:

- **Host project backup:** copies `/home/agent/projects` to the host, recreates
  a clean environment, and copies the projects back. This is usually faster
  and more reliable when caches can be downloaded again.
- **Local template:** preserves the writable root filesystem, including caches
  and installed tools, but large snapshots can be slow or fail.

## Recreate from a host project backup

As an alternative to a snapshot, copy the project checkouts to the host before
removing the sandbox. From the root of this configuration repository, choose a
timestamped backup directory and copy `/home/agent/projects` into it:

```bash
BACKUP_DIR="$HOME/.sbx-project-backups/gradle-ai-workspace-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$BACKUP_DIR"
sbx cp gradle-ai-workspace:/home/agent/projects "$BACKUP_DIR"
```

This copies complete working trees, including `.git` directories, untracked
files, and uncommitted changes. Verify that the backup exists and looks
complete before removing the sandbox:

```bash
test -d "$BACKUP_DIR/projects"
du -sh "$BACKUP_DIR/projects"
find "$BACKUP_DIR/projects" -mindepth 1 -maxdepth 1 -type d
```

Then stop and remove the old environment, and recreate it with the desired
configuration and disk sizes:

```bash
sbx stop gradle-ai-workspace
sbx env rm .sbxenv.yaml
DOCKER_SANDBOXES_ROOT_SIZE=90g \
DOCKER_SANDBOXES_DOCKER_SIZE=10g \
DOCKER_SANDBOXES_CLONED_WORKSPACE_SIZE=2g \
  sbx env create .sbxenv.yaml
```

After the replacement is running, restore the projects:

```bash
sbx cp "$BACKUP_DIR/projects" gradle-ai-workspace:/home/agent/
sbx exec -u root gradle-ai-workspace \
  chown -R agent:agent /home/agent/projects
```

The ownership correction is required because the copy may preserve the host
user's numeric UID and GID, which do not identify the `agent` user inside the
sandbox. Without it, tools such as Orca cannot create new project checkouts.

Check the projects and their Git status inside the replacement before deleting
the host backup. If environment creation fails, retain the backup, resolve the
creation problem, and run only the create and restore commands again.

> [!WARNING]
> This method does not preserve `/home/agent/.gradle`, installed packages that
> are not in the setup kit, agent configuration, commit-signing configuration,
> sandbox-local secrets, Docker images, containers, volumes, or Docker build
> cache. Configure those again after recreation. Keep important Git work on a
> remote as an additional independent backup.

## Recreate from a local template

Use a local template when the complete writable root filesystem must survive,
including `/home/agent/.gradle`, installed packages, downloaded toolchains,
and other files under `/home/agent`.

> [!WARNING]
> This procedure has downtime, and the recreated sandbox cannot be tested
> before the old sandbox is removed because both cannot have the same name.
> The local template is the rollback copy. If `sbx template save` fails or the
> saved tag does not appear in `sbx template ls`, stop and do not remove the
> environment. Never run `sbx reset` during the migration: reset also deletes
> locally cached templates.

`sbx template save` currently has open reports for commit failures
([sbx#375](https://github.com/docker/sbx-releases/issues/375)) and snapshot
inflation from filesystem layering, hardlinks, and sparse files
([sbx#379](https://github.com/docker/sbx-releases/issues/379)). A large Gradle
cache can make this method much slower than downloading dependencies again.

> [!TIP]
> A host-side AI coding agent can carry out this procedure, update the
> configuration, and verify the replacement. Do not run the agent inside the
> sandbox being replaced because removing that sandbox terminates the agent.
> Ask the agent to pause before removing the old environment and confirm that
> the template and independent Git backups exist. For example:
>
> ```text
> Recreate gradle-ai-workspace using the procedure in docs/05-recreate.md with the new
> resource settings. Preserve all project work and the Gradle cache. Before
> removing the old environment, verify the migration template and Git backups
> and show me the result. After recreation, verify disk sizes, project Git
> status, restored data, and a representative offline Gradle build. Keep the
> migration template until I confirm that the replacement is good.
> ```

The template preserves the writable root filesystem, including
`/home/agent/.gradle`, `/home/agent/projects`, installed packages, downloaded
toolchains, and other files under `/home/agent`. Commit and push or fetch all
important Git work as an independent backup anyway. Stop active builds and the
sandbox, then confirm that it is stopped:

```bash
sbx stop gradle-ai-workspace
sbx ls
```

If stopping fails with `context deadline exceeded`, the runtime may be stuck.
Stop active agents and builds, then restart the SBX daemon and check the state
again:

```bash
sbx daemon restart
sbx ls
```

Restarting the daemon interrupts activity in every local sandbox. If the target
still appears as running, retry `sbx stop gradle-ai-workspace` and check again.
Do not continue until the target is stopped and has no active sessions. The
`--force` option on `sbx env rm` only bypasses its confirmation prompt; it is
not a workaround for a stuck runtime.

Save the stopped sandbox under a unique local tag and confirm that the tag
exists:

```bash
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
sbx env rm .sbxenv.yaml
```

Update the permanent CPU, memory, kit, workspace, or other settings in
`.sbxenv.yaml`, but keep the existing name. For example:

```yaml
name: gradle-ai-workspace

sandboxOptions:
  cpus: 8
  memory: 32g
```

In SBX 0.43.0, the default memory allocation is 50% of host memory, clamped to
512 MiB–32 GiB. An explicit memory limit can be up to 75% of host memory (with
a 512 MiB floor). This environment explicitly requests `32g`; check
`sbx create --help` and your host's capacity before changing it. Disk capacities
are independent and must be supplied when the replacement is created:

```bash
# Root filesystem, private Docker data, and private control-repository clone.
DOCKER_SANDBOXES_ROOT_SIZE=90g \
DOCKER_SANDBOXES_DOCKER_SIZE=10g \
DOCKER_SANDBOXES_CLONED_WORKSPACE_SIZE=2g \
  sbx env create .sbxenv.yaml restore.sbxenv.yaml
```

The disk variables control different data:

- `DOCKER_SANDBOXES_ROOT_SIZE` contains `/home/agent/.gradle`,
  `/home/agent/projects`, installed packages, and most sandbox state;
- `DOCKER_SANDBOXES_DOCKER_SIZE` contains the private Docker daemon's images,
  containers, volumes, and Docker build cache under `/var/lib/docker`;
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
