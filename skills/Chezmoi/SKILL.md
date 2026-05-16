---
name: Chezmoi
version: 0.1.0
description: "chezmoi dotfile engine reference: source state attributes, the leading-dot ignore trap, special files, the difference between hooks, scripts, and interpreters, and the verified command set. USE WHEN editing chezmoi config, debugging chezmoi apply or diff, weighing chezmoi against stow or a Makefile, adding new dotfiles to a chezmoi-managed repo, or reasoning about why chezmoi requires the dot_ prefix."
sources:
    - https://www.chezmoi.io/reference/
    - https://www.chezmoi.io/reference/source-state-attributes/
    - https://www.chezmoi.io/reference/configuration-file/
    - https://www.chezmoi.io/reference/configuration-file/hooks/
    - https://www.chezmoi.io/reference/configuration-file/interpreters/
    - https://www.chezmoi.io/reference/special-files/chezmoiroot/
    - https://www.chezmoi.io/reference/special-files/chezmoiexternal-format/
    - https://www.chezmoi.io/user-guide/frequently-asked-questions/design/
---

# Chezmoi

chezmoi manages a single source tree whose structure mirrors `$HOME` one-to-one. Per-file metadata (deploy target's leading dot, file mode, encryption, executable bit) is encoded in the source filename itself via prefix attributes. There is no sidecar config that maps source paths to target paths; the prefix is the metadata.

This skill captures what each piece of the surface area actually does, the traps that bite repeatedly, and the difference between three concepts that sound similar.

## Source state attributes

Every source file may carry one or more prefix attributes. The most consequential is `dot_`:

| Prefix         | Effect                                                                   |
| -------------- | ------------------------------------------------------------------------ |
| `dot_`         | Rename to leading dot at apply. `dot_zshrc` deploys to `~/.zshrc`.        |
| `private_`     | Set target mode to 600 (rwx for owner only).                              |
| `readonly_`    | Remove write permissions on the target.                                   |
| `executable_`  | Set mode 755.                                                             |
| `empty_`       | Keep target even if its content is empty (normal default removes empty).  |
| `exact_`       | On directories: remove unmanaged children.                                |
| `encrypted_`   | Decrypt content at apply (paired with `chezmoi.toml` `encryption` config).|
| `symlink_`     | Source content is the target of a symlink, not file content.              |
| `create_`      | Create target only if absent. Never overwrite.                            |
| `modify_`      | Source is a script that emits the target's new content.                   |
| `run_`         | Source is a script that runs at apply. Variants: `_once_`, `_onchange_`.  |
| `before_`/`after_` | Run timing relative to file updates.                                  |
| `external_`    | Ignore attribute parsing for child entries.                               |
| `literal_`     | Stop attribute parsing for this filename. For collisions with the words above. |

Prefixes compose left-to-right: `private_dot_ssh/config` deploys to `~/.ssh/config` at mode 600. See the [source state attributes reference][SSA] for the canonical list.

## The leading-dot ignore trap

From the [source state attributes reference][SSA]:

> "chezmoi ignores all files and directories in the source directory that begin with a `.`"

Exception: files literally named `.chezmoi*` (the configuration files documented below).

This means you CANNOT have a literal `.zshrc` in your source directory. chezmoi refuses to see it. The `dot_` prefix is the ONLY mechanism for landing a leading dot on the target. A source file named `zshrc` (no dot, no prefix) deploys to `~/zshrc` (no leading dot), which is almost never what you want.

The `literal_` attribute and `.literal` suffix exist to disambiguate filenames that collide with attribute names (e.g. a file genuinely named `dot_something_real`). They do NOT bypass the leading-dot ignore rule.

This design is load-bearing. Three open feature requests asked for an escape hatch ([#753][I753], [#1313][I1313], [discussion #2673][D2673]); all were declined.

## Special files

| File                       | Purpose                                                                  |
| -------------------------- | ------------------------------------------------------------------------ |
| `.chezmoiroot`             | Subdirectory to read source state from. Relocates root, not naming.       |
| `.chezmoiignore`           | Glob list of source paths to skip on apply. Templated.                    |
| `.chezmoiexternal.<fmt>`   | External archives, files, or git-repos to fetch into source state.        |
| `.chezmoidata.<fmt>`       | Static template data available as `.varname` in `.tmpl` files.            |
| `.chezmoitemplates/`       | Named templates includable via `{{ template "name" }}`.                   |
| `.chezmoiscripts/`         | Scripts that run without being deployed as files.                         |
| `.chezmoiversion`          | Minimum chezmoi version this source state requires.                       |

`.chezmoiexternal` only supports four URL types: `file`, `archive`, `archive-file`, `git-repo`. There is no "loose local directory" mode.

## Hooks vs scripts vs interpreters

The terms collide. They are different things.

**Hooks** ([reference][HOOKS]) are commands fired by `chezmoi.toml` configuration around events: per-command `.pre` / `.post`, plus `read-source-state.pre/post`, `git-auto-commit.pre/post`, `git-auto-push.pre/post`. Hooks are always run (including under `--dry-run`). They observe events. **They cannot rewrite source-to-target mappings.**

**Scripts** are source-state files with the `run_` attribute. They execute during apply. Three flavors:
- `run_NAME.sh` runs every apply.
- `run_once_NAME.sh` runs at most once (chezmoi tracks via sha256).
- `run_onchange_NAME.sh` runs when the rendered content changes (use template `include` + `sha256sum` of dependent files to force re-runs).

Scripts can do arbitrary work but do not change chezmoi's deployment logic.

**Interpreters** ([reference][INTERP]) is a Windows-only config section that routes script extensions (`.py`, `.rb`, `.pl`) to an interpreter binary. Native execution on Windows is limited to `.bat`, `.cmd`, `.com`, `.exe`. Irrelevant on macOS and Linux. Does not affect file naming.

## Command cheat sheet

Verified against installed `chezmoi --help`:

| Command                            | Purpose                                                                |
| ---------------------------------- | ---------------------------------------------------------------------- |
| `chezmoi apply --source .`         | Deploy from current dir to `$HOME`. Idempotent.                          |
| `chezmoi diff --source .`          | Preview pending changes as a unified diff.                               |
| `chezmoi managed --source .`       | List managed target paths. Use to confirm what would be deployed.        |
| `chezmoi target-path SOURCE`       | Print the target path for a given source path. Debug source/target maps. |
| `chezmoi verify --source .`        | Exit 0 if destination matches target state, non-zero otherwise.          |
| `chezmoi add ~/.zshrc`             | Adopt an existing dotfile. Copies it into source and renames to `dot_zshrc`. |
| `chezmoi edit ~/.zshrc`            | Edit the source file backing a target with `$EDITOR`.                    |
| `chezmoi merge ~/.zshrc`           | Three-way merge between source, target, and destination state.           |
| `chezmoi cd`                       | Launch a shell in the source directory.                                  |
| `chezmoi init`                     | Initialize source dir and apply on a fresh machine.                      |
| `chezmoi update`                   | Pull source repo and apply.                                              |
| `chezmoi doctor`                   | Diagnose installation, paths, encryption setup.                          |
| `chezmoi edit-config`              | Edit `chezmoi.toml`.                                                     |

When the source directory is not at chezmoi's default location (`~/.local/share/chezmoi`), pass `--source <dir>` to every command.

## Common gotchas

1. **`.chezmoiignore` omissions deploy unintended files.** Every file at the repo root not listed in `.chezmoiignore` becomes a target. New repo-root files are born deployable. Audit with `chezmoi managed --source .` after every restructure; the output should match expectations exactly.

2. **The `run_onchange_` script prefix does not preempt deployment.** Both the script and the rendered file (with `.tmpl` stripped) land in the target unless either is in `.chezmoiignore`. The `_onchange_` part controls when the script runs; it does nothing about file deployment.

3. **Hand-rolled bash install scripts inside chezmoi are an antipattern.** If you find yourself writing a `run_onchange_install-shell.sh.tmpl` that copies source files to dotted targets, you are reimplementing what `dot_` does natively. The duality (blacklist source in `.chezmoiignore`, copy by hand in bash) is brittle. Either commit to native `dot_*` naming or drop chezmoi for a Makefile.

4. **`mode = "symlink"` in `chezmoi.toml`** ([design FAQ][DESIGN]) makes apply produce symlinks back to source for non-templated, non-encrypted, non-executable files. Edit source and the deployed file follows. Source files still need `dot_` prefix.

5. **Secrets in a separate private repo defeat half of chezmoi's value.** chezmoi's case for managing secrets is the `pass`, `1password`, `keyring`, or `age` template functions. If you keep secrets in a `dotfiles-private` git repo and symlink it at install time, you are paying chezmoi's tax without using its secret-resolution feature.

6. **`chezmoi diff` quirk: scripts show as "new file".** A `run_*` script that would execute on apply appears in `chezmoi diff` output as if it were a file deployment. Cross-check with `chezmoi managed --source .` to see which entries are real deploy targets vs script invocations.

## Constraints

- The `dot_` prefix is the only encoding for leading-dot targets. No config override exists.
- chezmoi ignores source files starting with `.` (except `.chezmoi*`).
- Hooks observe events; they cannot rewrite source-to-target mapping.
- Interpreters affect Windows script execution only.
- One source root per chezmoi instance. No per-package directories.
- Templates can vary file contents per-machine, not source path to target path.

## When NOT to use chezmoi

Consider stow, yadm, or a hand-rolled Makefile when:

- You actively dislike the `dot_*` rename convention.
- You want per-package source directories (`zsh/`, `ghostty/`).
- You are not using templating for per-machine variance.
- You are not using a chezmoi-supported secret backend (`pass`, `1Password`, `keyring`, `age`).
- Your secrets live in a separate git repo (you have already accepted the stow tradeoff).

[SSA]: https://www.chezmoi.io/reference/source-state-attributes/
[HOOKS]: https://www.chezmoi.io/reference/configuration-file/hooks/
[INTERP]: https://www.chezmoi.io/reference/configuration-file/interpreters/
[DESIGN]: https://www.chezmoi.io/user-guide/frequently-asked-questions/design/
[I753]: https://github.com/twpayne/chezmoi/issues/753
[I1313]: https://github.com/twpayne/chezmoi/issues/1313
[D2673]: https://github.com/twpayne/chezmoi/discussions/2673
