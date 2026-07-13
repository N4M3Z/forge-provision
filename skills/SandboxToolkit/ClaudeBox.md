# Claude Code in the box

The harness runs in full inside the VM: file tools, hooks, MCP servers, settings, and history all live behind the wall. This is the configuration Anthropic documents as the isolation boundary for unattended runs, and it equally suits running the entire harness day-to-day as a security layer.

## Image

Minimal and templated with native OCI build args; save as `Containerfile` (in forge-provision: `scripts/sandbox/claude-box/Containerfile`):

```dockerfile
ARG BASE_IMAGE=docker.io/library/node:22-slim

FROM ${BASE_IMAGE}

ARG APT_PACKAGES="git ca-certificates"

RUN apt-get update \
    && apt-get install -y --no-install-recommends ${APT_PACKAGES} \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

USER node

WORKDIR /work
```

Build from the directory containing the Containerfile; variants need build args, not file edits. Rebuild to refresh the pinned Claude Code version:

```sh
container builder start -m 4g
container build -t claude-box -f Containerfile .
container build -t claude-box-py --build-arg APT_PACKAGES="git ca-certificates python3" -f Containerfile .
```

The user inside is non-root (`USER node`): the CLI rejects `--dangerously-skip-permissions` as root, project-local installs (`npm install` into `/work`) succeed, and system installs (`apt-get`) deliberately fail. Bake recurring toolchains into the image via build args instead.

## Auth

Two paths. Interactive: log in on first run (the OAuth URL prints in the terminal); credentials then live only inside the box. Headless: generate a one-year token with `claude setup-token` and keep it in a secret manager such as pass as the source of truth.

When the secret manager prompts per read (a YubiKey touch policy, for instance), cache the token once a year into a chmod-600 env file and hand it to runs with `--env-file`; the token then never enters the shell environment or argv:

```sh
mkdir -p ~/.config/containers
printf 'CLAUDE_CODE_OAUTH_TOKEN=%s\n' "$(pass show anthropic/claude-oauth-token)" > ~/.config/containers/claude-box.env
chmod 600 ~/.config/containers/claude-box.env
```

Add `~/.config/containers` to the harness sandbox's `denyRead` so host Bash subprocesses cannot read the cached tokens, and keep the directory out of dotfiles management; its contents are regenerable from the secret manager. Runs below show the export form; substitute `--env-file ~/.config/containers/claude-box.env` for `-e CLAUDE_CODE_OAUTH_TOKEN` when using the cache.

## Run modes

Mount an explicit absolute project path, never bare `$PWD`: `$PWD` mounts whatever directory you launched from, so running from the home directory hands the box your entire home at `/work` (writable, under `--dangerously-skip-permissions`). Supervised and disposable (state dies with the VM):

```sh
container run --rm -it -m 4g -e CLAUDE_CODE_OAUTH_TOKEN \
    -v "/path/to/project:/work" -w /work \
    claude-box claude
```

Persistent harness (login, settings, and history survive across runs in a named volume; the host still exposes only the project):

```sh
container volume create claude-home-<project>
container run --rm -it -m 4g \
    -v claude-home-<project>:/home/node \
    -v "/path/to/project:/work" -w /work \
    claude-box claude
```

Autonomous (`--dangerously-skip-permissions` is safe here because the VM wall replaces the permission system):

```sh
container run --rm -m 4g -e CLAUDE_CODE_OAUTH_TOKEN \
    -v "/path/to/project:/work" -w /work \
    claude-box claude --dangerously-skip-permissions -p "<prompt>" --output-format stream-json
```

Review the aftermath with `git diff` in the mounted project; with `--rm` the VM itself leaves nothing behind.

## Home volumes

Named volumes are runtime-managed: pick names, not paths (they live under the runtime's app root). Convention: **one volume per project**, named `claude-home-<project>`.

Fresh volumes mount root-owned while the image runs as `node`, so every new home volume needs a one-time ownership fix before anything can persist in it (without this, login saves and settings writes fail with permission denied):

```sh
container run --rm -u root -v claude-home-<project>:/home/node claude-box chown -R node:node /home/node
```

Per-project is load-bearing, not taste. Claude Code keys per-project state by path and every box mounts its project at `/work`, so a home volume shared across projects collides their histories. Per-project volumes also isolate state between workloads: a run in one project cannot read another's history, and with token auth the volume carries only settings and history, no credentials.

Lifecycle by name only:

```sh
container volume ls                              # inventory
container volume rm claude-home-<project>        # retire a project's state
```

Never `container volume prune`: detached volumes count as unreferenced, and `--rm` boxes detach on exit, so prune deletes every idle home volume at once.

## Redaction variant (claude-box-redact)

A variant bakes the forge-redact PII/secret redaction proxy into the box: Claude
routes through the proxy on loopback inside the VM, secrets hard-block, and PII is
replaced with consistent surrogates before anything egresses. The agent's egress and
credential boundary is Claude Code's own native sandbox, baked to
`/etc/claude-code/managed-settings.json`. Reasoning in
[VIRT-0003](<../../docs/decisions/VIRT-0003 In-sandbox PII redaction.md>).

Build the base `claude-box` first, then the variant. `redact build` uses this
directory as the build context (its tracked files in place), assembles the two
inputs that are not tracked (the forge-redact wheel and your GPG public key), builds,
and removes them:

```sh
make redact build                 # recipient defaults to your default GPG key
make redact build <recipient>     # or name a key
```

The Presidio plus spaCy model layer is large, so the first build is slow; the
builder VM is bumped to `-m 4g`. The build fails if the recipient key does not
resolve, so a misconfigured box never reaches runtime.

`redact run` decrypts the master vault on the host (one YubiKey touch) into a seed
mounted read-only at `/seed`, runs the box with the project at `/work` and a capture
dir at `/capture`, then promotes the updated, re-encrypted vault back to the master:

```sh
make redact run                                 # interactive
scripts/sandbox/claude-box/redact run -p "..."  # one-shot (claude args)
```

Surrogates stay consistent across runs and you keep one reversible master vault at
`~/.local/state/forge/presidio/vault.gpg` (`gpg --decrypt` to un-blind); the private
key never enters the VM, and Claude Code's native sandbox `denyRead`s the in-VM
`/seed` so the agent cannot read the map. The variant is **disposable mode only**: do
not mount a `claude-home-<project>` volume at `/home/node`, it would shadow the baked
policy, sandbox settings, public key, and proxy CA.
sandbox settings, public key, and proxy CA.
