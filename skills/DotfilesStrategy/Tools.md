# Dotfile manager tools, in depth

Per-tool mechanism, pros, cons, install, and gotchas. The mechanisms diverge enough that comparison-table cells flatten meaningful differences; read the tool-specific entries before recommending.

## chezmoi

**Mechanism**: Single Go binary. Source tree under `~/.local/share/chezmoi/` mirrors `$HOME` 1:1; per-file metadata (target's leading dot, mode, executable, encryption, templating) lives in source filename prefixes (`dot_`, `private_`, `executable_`, `encrypted_`, `run_`, `modify_`, etc.). `chezmoi apply` lays files down; `chezmoi diff` previews. Templates are Go's `text/template` with custom data sources for per-machine variation. See the [Chezmoi](../Chezmoi/SKILL.md) sibling skill for mechanics.

**Pros**: Templates for per-machine variance. First-class password-manager integration ([1Password, Bitwarden, pass, age, gopass][CMSECRETS]). Encrypted files via age or gpg. Run-once / run-onchange scripts for one-shot setup. Single-binary install, cross-platform (macOS, Linux, Windows, BSDs). Active development, [comparison table][CMTABLE] is the most comprehensive in the space.

**Cons**: Source state attributes are a small DSL — `private_dot_ssh/config` reads strangely the first dozen times. Go template syntax is verbose for trivial substitutions. Two locations to reason about (source dir + target `$HOME`).

**Install**: `brew install chezmoi`, or curl one-liner from [chezmoi.io][CHEZMOI]. Bootstrap a new machine with `chezmoi init --apply <github-user>`.

**Gotchas**: Files beginning with `.` in the source tree are ignored by chezmoi (different from how git treats them). Use `dot_` prefix instead. See the Chezmoi skill's "leading-dot ignore trap" section.

[CMSECRETS]: https://www.chezmoi.io/user-guide/password-managers/
[CMTABLE]: https://www.chezmoi.io/comparison-table/
[CHEZMOI]: https://www.chezmoi.io/

## GNU Stow

**Mechanism**: Perl script. Packages live in subdirectories of a stow directory (`~/dotfiles/`); `stow <package>` symlinks each file in `<package>/` into `~/` preserving the relative path. `stow -D <package>` removes them. From 1993, in Homebrew and most Linux distros.

**Pros**: Smallest possible mental model: directory contents become symlinks in target. Zero state, no daemon, no apply step. Easy to grep through your own repo. Composes well with git submodules per topic.

**Cons**: No templating, no per-machine differentiation, no secret handling. Adding a new file means moving it into the package then running `stow` again. Symlinks confuse some tools (notably some IDEs that don't follow symlinks consistently).

**Install**: `brew install stow`. See the [Stow manual][STOWMAN] for `--target` and `--dir` semantics.

**Gotchas**: `stow` refuses to clobber existing files (correctly). On first run against a populated `$HOME`, expect conflicts and resolve by moving files out of the way first. `--adopt` will pull existing files INTO your stow package, which is sometimes what you want but rarely what you mean to type.

[STOWMAN]: https://www.gnu.org/software/stow/manual/stow.html

## yadm

**Mechanism**: Bash wrapper around git. `yadm` commands proxy to a hidden `git` working tree rooted at `$HOME` with `.git` at `~/.local/share/yadm/repo.git`. Alt-files (`file##os.Darwin`, `file##hostname.macbook`) handle per-machine variation. Encryption via `~/.config/yadm/encrypt` + GPG.

**Pros**: Closest to "just use git". If you know git, you know 95% of yadm. Alt-file naming is unobtrusive. Hooks via `.local/share/yadm/hooks/`. Good for users who prefer convention over configuration.

**Cons**: Bash wrapper means small dependency-and-shell-quirk surface. Less popular than chezmoi or stow; smaller community for troubleshooting. Templates exist but are less ergonomic than chezmoi's.

**Install**: `brew install yadm`. See [yadm.io/docs/overview][YADMDOC].

**Gotchas**: The "use git as if you didn't have a $HOME" model means a stray `yadm add .` is dangerous in directories you don't expect. Most users alias to limit blast radius.

[YADMDOC]: https://yadm.io/docs/overview

## rcm

**Mechanism**: Suite of Bash scripts from thoughtbot. `rcup` symlinks files from `~/.dotfiles` (or `~/.rcm`) into `~/`. Host-specific files live under `host-<hostname>/`; tag-specific under `tag-<tag>/`. Templates supported via `.erb` files.

**Pros**: Lightweight. Tag-and-host model is explicit and obvious. Easy to read the source.

**Cons**: Slower release cadence than chezmoi or stow. Latest release at time of writing is [v1.3.6 (2022-12-30)][RCMREL]. Smaller community. No secret handling.

**Install**: `brew install rcm`. Read [thoughtbot/rcm][RCMREPO] for the model.

**Gotchas**: The `mkrc`/`rcup`/`rcdn` command set takes a few sessions to internalize. Worth it only if the tag/host model maps onto a real distinction.

[RCMREPO]: https://github.com/thoughtbot/rcm
[RCMREL]: https://github.com/thoughtbot/rcm/releases/tag/v1.3.6

## dotbot

**Mechanism**: Python script driven by `install.conf.yaml`. Directives include `link`, `create`, `clean`, `shell`. Each repo bundles a `dotbot` git submodule and an `install` script that runs `./dotbot -c install.conf.yaml`.

**Pros**: Explicit YAML config — what gets linked is in one file, easy to audit. `shell` directive runs setup commands. Cross-platform (Python). Active community.

**Cons**: YAML maintenance overhead grows with the number of files. Python dependency on the target machine. No native templating or secrets; rely on `shell` directives to glue in external tools.

**Install**: Vendored as a git submodule in your dotfiles repo (the canonical install path). See [anishathalye/dotbot][DOTBOT].

**Gotchas**: The submodule pattern means a fresh clone needs `git submodule update --init --recursive` before the first install. Easy to forget in bootstrap docs.

[DOTBOT]: https://github.com/anishathalye/dotbot

## home-manager (Nix)

**Mechanism**: Nix module system, declarative. Configuration is a `home.nix` file specifying packages, files, services. `home-manager switch` builds the closure and atomically swaps `$HOME` to point at it.

**Pros**: Fully declarative. Atomic switches (rollback by switching back). Packages and config in one file, in one language. Reproducible across machines that run Nix.

**Cons**: Requires the Nix package manager (which is itself a major commitment). Steep learning curve for Nix expressions. Build closures take disk space. Cross-team collaboration is harder if not everyone runs Nix.

**Install**: First install [Nix][NIX] (multi-user is canonical on macOS). Then `nix run home-manager/release-24.05 -- init --switch`. See [home-manager docs][HMDOCS].

**Gotchas**: Mixing home-manager with non-Nix dotfile workflows fights both tools. Commit fully or not at all.

[NIX]: https://nixos.org/download
[HMDOCS]: https://nix-community.github.io/home-manager/

## Bare git

**Mechanism**: Standard git, no extra tooling. Init a bare repo: `git init --bare $HOME/.dotfiles`. Define a shell alias: `alias config='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'`. Set `config config status.showUntrackedFiles no` to avoid drowning in `$HOME` content. Commit, push, clone, pull as normal git. Documented in [Atlassian's tutorial][ATLASSIAN] and originally popularized in a [2016 HN comment][SCBRA] by StreakyCobra.

**Pros**: Zero dependencies beyond git itself. Familiar workflow for git users. No tool to learn. Survives every package manager and OS.

**Cons**: No machine differentiation, no templating, no secret handling. The bare-repo alias is foot-gun adjacent — running `config add .` in the wrong directory commits unexpected files. Mental overhead of "is this a regular git command or my dotfiles command?"

**Install**: Already installed (it's just git).

**Gotchas**: `status.showUntrackedFiles no` is not optional — without it, every untracked file in `$HOME` appears in status. The bootstrap command on a new machine is non-trivial; pre-write it as a one-liner and stash it somewhere reachable (gist, README).

[ATLASSIAN]: https://www.atlassian.com/git/tutorials/dotfiles
[SCBRA]: https://news.ycombinator.com/item?id=11070797
