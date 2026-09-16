[← Back to the README](../README.md)

# Credentials and authentication

Each developer uses their own identity and credentials. GitHub authentication is
configured automatically from the host login used during setup. Configure commit
signing and Develocity access separately when your project requires them.

- [GitHub authentication](#github-authentication) — uses your host GitHub CLI login.
- [Commit signing](#commit-signing) — register a key once, configure Git per sandbox.
- [Develocity access key](#develocity-access-key) — provision once per sandbox.

## GitHub authentication

**Frequency:** Sign in with `gh auth login` on the host during initial setup;
authenticate again if that login expires or is revoked.

The environment resolves GitHub credentials automatically from your host login.
You do not need to run `gh auth login` inside the sandbox.
The [`.sbxenv.yaml`](../.sbxenv.yaml) file declares the GitHub secret using:

```yaml
secrets:
  github:
    command: gh auth token
```

The command executes on each developer's host. The token itself is not stored
in this repository or copied into the sandbox. Do not replace it with a literal
token value.

## Commit signing

**Frequency:** Register each key once per GitHub account; configure Git once per sandbox.

Docker forwards the host SSH agent into the sandbox, so Git can sign commits
without copying a private key into the environment or this repository.

First, on the host, inspect the fingerprint of the intended public key, load
its private key, and confirm that the same fingerprint appears in the agent:

```bash
ssh-keygen -lf ~/.ssh/id_ed25519.pub # Show the intended public key's fingerprint.
ssh-add ~/.ssh/id_ed25519            # Load its private key into the host SSH agent.
ssh-add -l                           # List fingerprints available through the agent.
```

Replace `id_ed25519` with the path to the key you intend to use. Register its
public key with GitHub as a signing key using the CLI:

```bash
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "SBX sandbox commit signing" # Add the public key as a GitHub signing key.
```

Alternatively, in the GitHub UI, open `Profile picture → Settings`, then
under `Access` select [SSH and GPG keys](https://github.com/settings/keys) →
`New SSH key`. Select `Signing Key` as the key type, paste the public key, and
add it.

An SSH key already registered for authentication must be registered a second
time as a signing key. Registering the key is a one-time, per-user operation;
the shared setup cannot make that change to a developer's GitHub account.

Next, connect to the sandbox and inspect both the fingerprints and complete
public keys forwarded by the host agent:

```bash
ssh gradle-ai-workspace.sbx # Connect to the sandbox.
ssh-add -l                  # List forwarded key fingerprints.
ssh-add -L                  # Show the complete forwarded public keys.
```

Copy the selected public key exactly as shown by `ssh-add -L`, then configure
Git inside the sandbox. The following public key is only an example; replace it
with the complete selected public key:

```bash
git config --global gpg.format ssh                                                # Use SSH signatures.
git config --global user.signingkey 'key::ssh-ed25519 AAAAC3... developer@example.com' # Select the public signing key.
git config --global commit.gpgsign true                                           # Sign commits automatically.
```

Also ensure `git config --global user.email` is an email associated with the
GitHub account. New commits are now signed automatically.

If `ssh-add -L` inside the sandbox reports no identities, load the key on the
host and reconnect. GitHub displays `Verified` after a commit signed by the
registered key is pushed.

## Develocity access key

**Frequency:** Once per sandbox.

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
