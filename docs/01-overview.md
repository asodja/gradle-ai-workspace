[← Back to the README](../README.md)

# How the workspace works

This is a configuration repository, not a parent checkout for development
repositories. It intentionally contains only the environment, its installation
kit, and this documentation. Development repositories are cloned independently
inside the sandbox rather than added here as submodules or mounted from the
host.

One long-lived sandbox holds every project, agent, and build cache. The host
keeps only this configuration repository, an SSH client, and the editor.

```text
  HOST (developer machine)
  ┌───────────────────────────────────────────────────────────┐
  │  ai-workspace/  — this repository, configuration only     │
  │    .sbxenv.yaml           sandbox, resources, secrets     │
  │    kits/gradle-tools/     JDKs, native build tools, Vim   │
  │                                                           │
  │  gh auth token  ─────────────────►  github secret         │
  │  editor / AI workspace app  ─────►  ssh *.sbx             │
  └───────────────┬──────────────────────────────┬────────────┘
                  │ Create environment           │ SSH
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
  │  tools    Java 8/17/25, build-essential, Python 3, Vim    │
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

The first creation installs `build-essential`, `curl`, Python 3, Vim, Java 8,
Java 17, and Java 25 on top of Docker's Ubuntu-based sandbox image. Gradle
detects all three JDK installations under `/usr/lib/jvm` for toolchain
selection. Java 8 comes from Ubuntu's `universe` component, which the base
image enables by default. Later starts retain installed packages, private
repositories, Gradle caches, and toolchains.

Every project and agent in this sandbox shares `/home/agent/.gradle`. Gradle's
dependency cache, wrapper distributions, downloaded toolchains, and local build
cache therefore remain available across projects and sandbox restarts.

Clone each repository once per sandbox. The clones survive restarts and are
deleted with the environment, so push or fetch anything that must outlive it.

GitHub credentials come from each developer's host login. See
[Credentials and authentication](03-credentials.md) for GitHub authentication,
commit signing, and Develocity access.

## Security boundary

Keep `workspace.clone: true`. Changing it to direct mode would let agents write
to this host checkout, including future environment configuration.

Clone mode still exposes this host repository read-only at
`/run/sandbox/source`, including ignored and untracked files. Do not store
credentials or other sensitive files anywhere beneath this repository.

All projects and agents inside `gradle-ai-workspace` share one trust boundary.
Use separate sandboxes when projects must not see or affect one another.
