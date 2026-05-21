# Reference repos and online resources

Battle-tested dotfile repos worth studying for layout patterns, plus the aggregators and tool-vs-tool resources that drive most conversations in the space. Star counts drift; this is curated for *influence* and *pattern density*, not popularity.

## Repos worth studying

### mathiasbynens/dotfiles

[github.com/mathiasbynens/dotfiles][BYNENS]. The reference repo for macOS-specific dotfile work. Pure bash, plain shell scripts, no manager. Most cited for `.macos` — a ~500-line script of `defaults write` calls that has been the genre's de facto reference since the early 2010s. Patterns to copy: the `.macos` structure (preamble guard + sectioned `defaults write`), the `brew.sh` separation, the `.aliases`/`.functions`/`.exports` split.

Mental model: this is one developer's preferences captured in a snapshot. The technique is reusable; the content is theirs. Don't copy `.macos` wholesale.

### holman/dotfiles

[github.com/holman/dotfiles][HOLMAN]. Zach Holman's repo, the one that popularized the "topical" layout: each directory under the repo root is one topic (`zsh/`, `git/`, `ruby/`), each topic owns its own install logic. Patterns to copy: topic-based organization, `*.symlink` convention (any file ending in `.symlink` gets symlinked to `$HOME` minus the suffix), `*.zsh` and `*.path` and `*.completion.zsh` topic-loading patterns.

The custom install script feels old-school today. The organizing principle is what matters.

### thoughtbot/dotfiles

[github.com/thoughtbot/dotfiles][THOUGHTBOT]. Paired with rcm. Opinionated toward Ruby/Rails development, but the tag-and-host pattern (`tag-osx/`, `host-laptop/`) translates regardless of language. Patterns to copy: clean separation of "shared", "tag", and "host" files; small focused configs over megaliths.

### skwp/dotfiles (YADR)

[github.com/skwp/dotfiles][YADR]. "Yet Another Dotfiles Repo" — vim-heavy, opinionated, an early example of a curated developer environment shipped as a dotfiles repo. Patterns to copy: organizing vim plugins as submodules, modular plugin loading, custom keybindings indexed by mnemonic. Worth reading for the vim configuration even if you don't adopt the whole repo.

### jessfraz/dotfiles

[github.com/jessfraz/dotfiles][JESSFRAZ]. Jessie Frazelle's repo. Linux-heavy, container-oriented, security-focused. Patterns to copy: aggressive use of containerized dev environments via `dockerfiles/`, scripted system bootstrap, security-paranoid sshd/gpg configs.

### LukeSmithxyz/voidrice

[github.com/LukeSmithxyz/voidrice][LUKE]. Terminal-heavy, suckless-tool-centric (dwm/st), Linux-only. Patterns to copy: the LARBS (Luke's Auto Rice Bootstrapping Script) approach of one-command install via curl-bash. Read with skepticism — opinionated to the point of being a worldview, not a template.

## Aggregators and curated lists

- [dotfiles.github.io][HUB] — the canonical hub since 2014. Lists managers, examples, articles, and editor tips. Start here for any "what do other people do?" question.
- [github.com/webpro/awesome-dotfiles][AWESOME] — Awesome-list curation. Hand-picked repos, tools, and resources. Good complement to the hub.
- [reddit.com/r/unixporn][UNIXPORN] — visual showcase. Less useful for code patterns, more useful for "what's possible aesthetically" with terminal-first environments. Most ricers publish their dotfiles in the comments.

## Tool-vs-tool comparisons

- [chezmoi.io/comparison-table/][CMTABLE] — most comprehensive feature matrix. Skews favorable to chezmoi (they wrote it) but the underlying capability table is accurate. Use for "does X support templating?" lookup.
- [yadm.io/docs/related_software/][YADMREL] — yadm's own comparison; smaller set, less editorial.
- StreakyCobra's [bare-git approach][SCBRA] (2016) — the original HN comment that popularized the bare-git method. Worth reading once for the elegance of the idea even if you don't adopt it.

## Methodological notes

When sending a user to a reference repo, name the pattern they're meant to copy, not just the repo. "Copy mathiasbynens" is a 500-file ask; "copy the `.macos` preamble guard and section split" is a 10-line ask.

When the user has an existing dotfiles repo, the answer to "should I switch to <repo>?" is almost always "no, study their patterns and apply selectively." Whole-repo adoption rarely survives first contact with a user's actual needs.

[BYNENS]: https://github.com/mathiasbynens/dotfiles
[HOLMAN]: https://github.com/holman/dotfiles
[THOUGHTBOT]: https://github.com/thoughtbot/dotfiles
[YADR]: https://github.com/skwp/dotfiles
[JESSFRAZ]: https://github.com/jessfraz/dotfiles
[LUKE]: https://github.com/LukeSmithxyz/voidrice
[HUB]: https://dotfiles.github.io/
[AWESOME]: https://github.com/webpro/awesome-dotfiles
[UNIXPORN]: https://www.reddit.com/r/unixporn/
[CMTABLE]: https://www.chezmoi.io/comparison-table/
[YADMREL]: https://yadm.io/docs/related_software
[SCBRA]: https://news.ycombinator.com/item?id=11070797
