# Starship References

Curated inspiration for `~/Developer/N4M3Z/dotfiles/config/starship.toml`. Generated 2026-05-13.

The current local config aims for a p10k "classic darkest" two-line layout in the tokyo-night palette (os, directory, git on the powerline; cmd_duration, status, jobs, direnv on the right; character on line two). The entries below provide drop-in starting points and reference techniques (transient prompt, right-aligned fill, custom characters, language version display).

## Quick reference

Browse the official preset gallery: <https://starship.rs/presets/>. Apply any preset with:

    starship preset <name> -o ~/Developer/N4M3Z/dotfiles/config/starship.toml

Preview without overwriting:

    starship preset <name> -o - | less

## Official presets

| Preset | Description | Page | Screenshot | TOML |
| ------ | ----------- | ---- | ---------- | ---- |
| tokyo-night | Two-line, segmented powerline in the tokyo-night palette (the user's current theme family). | [Page](https://starship.rs/presets/tokyo-night) | [PNG](https://starship.rs/presets/img/tokyo-night.png) | [TOML](https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/tokyo-night.toml) |
| pastel-powerline | Soft pastel powerline, demonstrates path substitution (M365Princess inspired). | [Page](https://starship.rs/presets/pastel-powerline) | [PNG](https://starship.rs/presets/img/pastel-powerline.png) | [TOML](https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/pastel-powerline.toml) |
| gruvbox-rainbow | Heavy multi-segment powerline (OS, user, dir, git, runtimes, docker, time) in gruvbox. | [Page](https://starship.rs/presets/gruvbox-rainbow) | [PNG](https://starship.rs/presets/img/gruvbox-rainbow.png) | [TOML](https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/gruvbox-rainbow.toml) |
| catppuccin-powerline | Catppuccin-flavored powerline (mocha by default, swap palette to change flavour). | [Page](https://starship.rs/presets/catppuccin-powerline) | [PNG](https://starship.rs/presets/img/catppuccin-powerline.png) | [TOML](https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/catppuccin-powerline.toml) |
| jetpack | Pseudo-minimalist two-line prompt slated to become the future default. | [Page](https://starship.rs/presets/jetpack) | [PNG](https://starship.rs/presets/img/jetpack.png) | [TOML](https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/jetpack.toml) |
| pure-preset | Emulates Sindre Sorhus' Pure prompt (clean, two-line, minimal symbols). | [Page](https://starship.rs/presets/pure-preset) | [PNG](https://starship.rs/presets/img/pure-preset.png) | [TOML](https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/pure-preset.toml) |
| nerd-font-symbols | Swaps default module icons for Nerd Font glyphs across the board. | [Page](https://starship.rs/presets/nerd-font) | [PNG](https://starship.rs/presets/img/nerd-font-symbols.png) | [TOML](https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/nerd-font-symbols.toml) |
| bracketed-segments | Wraps every module's segment in brackets instead of "via", "on", etc. | [Page](https://starship.rs/presets/bracketed-segments) | [PNG](https://starship.rs/presets/img/bracketed-segments.png) | [TOML](https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/bracketed-segments.toml) |
| no-nerd-font | Drops Nerd Font glyphs for environments without patched fonts. | [Page](https://starship.rs/presets/no-nerd-font) | (no published image) | [TOML](https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/no-nerd-font.toml) |
| plain-text-symbols | All-ASCII fallback (useful over flaky SSH or non-UTF terminals). | [Page](https://starship.rs/presets/plain-text) | (no published image) | [TOML](https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/plain-text-symbols.toml) |
| no-runtime-versions | Hides language runtime versions (good for containers, CI shells). | [Page](https://starship.rs/presets/no-runtimes) | (no published image) | [TOML](https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/no-runtime-versions.toml) |
| no-empty-icons | Suppresses module icons when the underlying toolset is not detected. | [Page](https://starship.rs/presets/no-empty-icons) | (no published image) | [TOML](https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/no-empty-icons.toml) |

## Tokyo Night style configs (matches current ccline palette)

| Source | Description | TOML |
| ------ | ----------- | ---- |
| [starship.rs/presets/tokyo-night](https://starship.rs/presets/tokyo-night) | Official tokyo-night preset, multi-segment two-line with OS, user, directory, git, runtimes. | [Raw TOML](https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/tokyo-night.toml) |
| [PR #5342 (VictorPLopes)](https://github.com/starship/starship/pull/5342) | Pending refresh to the official tokyo-night preset: OS-aware icons plus user module. | (review diff) |
| [gist: CalumMackenzie-Chambers](https://gist.github.com/CalumMackenzie-Chambers/8d60d7c242c8a0b1ec906a42be2fff06) | Two-line tokyo-night prompt with most modules enabled by default. | (gist source) |
| [gist: latenitecoding](https://gist.github.com/latenitecoding/161ca8276e214c1cfe044ad874a8190d) | Compact tokyo-night starship config, single file. | (gist source) |
| [siddrs/dotfiles (tokyo-night branch)](https://github.com/siddrs/dotfiles/tree/tokyo-night) | Full tokyo-night rice (i3, kitty, polybar, starship-git) for an Arch i3wm setup. | (browse repo) |
| [Petronella: Tokyo Night Setup Guide 2026](https://petronellatech.com/blog/tokyo-night-theme-setup-guide-2026/) | Full-system tokyo-night guide with the canonical tokyo-night hex palette (`#7aa2f7`, `#bb9af7`, `#e0af68`). | n/a |

## Powerline-style p10k-likes

| Source | Description | TOML |
| ------ | ----------- | ---- |
| [DEV: How to Configure Starship to Look Exactly Like P10K (Warp + macOS)](https://dev.to/therubberduckiee/how-to-configure-starship-to-look-exactly-like-p10k-zsh-warp-h9h) | Walkthrough by Warp DevRel, builds a p10k clone module by module. | (inline in post) |
| [Hashir: Powerlevel10k is on Life Support, Hello Starship](https://hashir.blog/2025/06/powerlevel10k-is-on-life-support-hello-starship/) | Migration narrative, recommends catppuccin-powerline as the closest p10k substitute. | n/a |
| [Discussion #6138: Powerline inspired prompt](https://github.com/starship/starship/discussions/6138) | Community starter with `prev_bg` / `prev_fg` color chaining, segmented OS, user, dir, git, langs, cloud, docker, time. | (inline in thread) |
| [Discussion #2567 (p10k repo)](https://github.com/romkatv/powerlevel10k/discussions/2567) | p10k maintainer notes "lean" style is closest to Starship default; recommended Wizard options listed. | n/a |
| [gist: notheotherben: A Powerline configuration for Starship.rs](https://gist.github.com/notheotherben/92302a60f8599ba73f1c2840f3c6d455) | Single-file powerline config with arrow separators and git status badges. | (gist source) |
| [Russ McKendrick: My Starship Prompt Setup](https://russmckendrick.medium.com/my-starship-prompt-setup-e505b872d531) | Gruvbox powerline arrows, evolved from p10k. Full TOML linked from the post. | [Raw TOML](https://raw.githubusercontent.com/russmckendrick/dotfiles/main/starship.toml) |

## Minimalist / Pure-style

| Source | Description | TOML |
| ------ | ----------- | ---- |
| [starship.rs/presets/pure-preset](https://starship.rs/presets/pure-preset) | Official emulation of Sindre Sorhus' Pure. | [Raw TOML](https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/pure-preset.toml) |
| [starship.rs/presets/jetpack](https://starship.rs/presets/jetpack) | Pseudo-minimal, slated future default; two-line, light on icons. | [Raw TOML](https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/jetpack.toml) |
| [amanhimself: My Starship prompt setup](https://amanhimself.dev/blog/my-starship-prompt-setup/) | Minimal prompt walkthrough with module-by-module config snippets. | n/a |

## Particularly striking community configs

| Source | What makes it interesting | TOML |
| ------ | ------------------------- | ---- |
| [Maroc02/awesome-starship-prompts](https://github.com/Maroc02/awesome-starship-prompts) | Curated gallery of community prompts with screenshots and config links (good browse target). | (per entry) |
| [Stellar Hub](https://stellar-hub.vercel.app/) | Browser-side theme gallery spanning catppuccin, dracula, gruvbox, monokai, nord, rose pine, solarized, tokyo night. | (one-line install per theme) |
| [Discussion #1107: Share your setup](https://github.com/starship/starship/discussions/1107) | Long-running thread where Starship users post screenshots and configs; useful for browsing styles in the wild. | (per post) |
| [dracula/starship](https://github.com/dracula/starship) | Official Dracula port: ships a palette TOML and a full theme TOML with a lambda prompt. | [Raw TOML](https://raw.githubusercontent.com/dracula/starship/master/starship.toml) |
| [grantbevis/dracula-starship](https://github.com/grantbevis/dracula-starship) | Community Dracula variant ("spooky"), single-file. | [Raw TOML](https://raw.githubusercontent.com/grantbevis/dracula-starship/master/starship.toml) |
| [draculatheme.com/starship-powerline-preset](https://draculatheme.com/starship-powerline-preset) | Dracula's own powerline derivative, inspired by catppuccin-powerline plus pastel-powerline. | (download from page) |
| [catppuccin/starship](https://github.com/catppuccin/starship) | Official Catppuccin palettes; set `palette = "catppuccin_mocha"` and pull palette tables from the repo. | [Raw mocha palette](https://raw.githubusercontent.com/catppuccin/starship/main/themes/mocha.toml) |
| [fang2hou/starship-gruvbox-rainbow](https://github.com/fang2hou/starship-gruvbox-rainbow) | Gruvbox plus tokyo-night plus pastel-powerline hybrid; precursor to the official gruvbox-rainbow preset. | (browse repo) |
| [zaid-hassan/nordic-starship-toml](https://github.com/zaid-hassan/nordic-starship-toml) | Nordic palette derived from pastel-powerline (with two Dracula accents to round out the palette). | (browse repo) |
| [thecaffeinedev/dotfiles starship.toml](https://github.com/thecaffeinedev/dotfiles/blob/main/starship.toml) | M1 MacBook setup, compact prompt with cloud and k8s segments. | [Raw TOML](https://raw.githubusercontent.com/thecaffeinedev/dotfiles/main/starship.toml) |
| [gist: 3ayazaya](https://gist.github.com/3ayazaya/d87c70c5f30a6e28f15dfc84ca95fc68) | Popular recent gist (April 2026). Demonstrates extensive module formatting. | (gist source) |
| [gist: AntreasAntoniou](https://gist.github.com/AntreasAntoniou/3bfe47d51e915e93517ce335c2b1f98b) | "Creativity, Warmth, and Efficiency" config emphasizing color theory and density. | (gist source) |
| [gist: sttamper](https://gist.github.com/sttamper/ff69056e8cb94be9397a2c5508e57018) | Self-titled "best starship configuration ever" (judge for yourself). | (gist source) |
| [gist: ryo-ARAKI](https://gist.github.com/ryo-ARAKI/48a11585299f9032fa4bda60c9bba593) | Academic and research workflow tilt: julia, conda, time, version control. | (gist source) |
| [j0shuaS/nerds-and-brackets](https://github.com/j0shuaS/nerds-and-brackets) | Combines nerd-font-symbols icons with bracketed-segments wrapping. | (browse repo) |
| [Practicalli Engineering Playbook: starship-prompt](https://practical.li/engineering-playbook/os/command-line/shell/starship-prompt/) | Curated engineer's guide with annotated module choices (Clojure-leaning). | n/a |

## Modules and advanced techniques

| Technique | Reference |
| --------- | --------- |
| Transient prompt (zsh manual workaround) | [Discussion #5950](https://github.com/starship/starship/discussions/5950) and [olets/zsh-transient-prompt](https://github.com/olets/zsh-transient-prompt) for any-prompt support. Pattern: `add-zsh-hook precmd` plus `starship prompt --profile transient`. |
| Transient prompt (PowerShell, native) | [Gilbert Sanchez: Starship Transient Prompt setup](https://gilbertsanchez.com/posts/prompt-starship/). |
| `right_format` (single line, supported in zsh, fish, bash, elvish, xonsh, cmd, nushell) | [Advanced Configuration](https://starship.rs/advanced-config/) and [Discussion #5435](https://github.com/starship/starship/discussions/5435). |
| `$fill` module for right alignment on multi-line prompts | [Official format docs](https://starship.rs/config/) (search "fill"). Pattern: `format = "$all\\$fill\\$time\\$line_break\\$character"`. See [@StarshipPrompt tweet](https://x.com/StarshipPrompt/status/1440380145861226496). Useful when `right_format` would land on the wrong line. |
| Custom characters and `repeat` / `shlvl` (multi-arrow prompt) | [Advanced Configuration](https://starship.rs/advanced-config/) shows the `[shlvl]` plus `repeat = true` pattern to produce ❯❯❯ colored by exit status. |
| Language version display, per-module `format` and `symbol` overrides | [Configuration reference](https://starship.rs/config/) covers every language module (`nodejs`, `python`, `rust`, etc.) with format strings. |
| Continuation prompt for unterminated input | [Advanced Configuration](https://starship.rs/advanced-config/) (`continuation_prompt` setting). |
| `--profile` flag for per-context prompts | [Advanced Configuration](https://starship.rs/advanced-config/). Same `starship.toml`, different output table per profile (minimal in scrollback, rich on live line). |
| Benchmarking modules | `starship timings` (built-in). Drop slow modules; typical render budget is 5-15ms. |
| Explaining what is rendering | `starship explain` (built-in) for diagnosing unknown symbols. |

## How to A/B test

    starship preset <name> -o ~/Developer/N4M3Z/dotfiles/config/starship.toml && chezmoi apply

Useful candidates (in escalating density):

| Run | Effect |
| --- | ------ |
| `starship preset tokyo-night -o ...` | Reset to the official tokyo-night baseline for direct comparison with current config. |
| `starship preset pastel-powerline -o ...` | Switch palette while keeping the powerline structure. |
| `starship preset gruvbox-rainbow -o ...` | Most "loaded" segmented prompt (runtimes, docker, time inline). |
| `starship preset catppuccin-powerline -o ...` | Closest p10k feel per the Hashir migration write-up. |
| `starship preset jetpack -o ...` | Forward-looking minimal default; useful sanity check. |
| `starship preset pure-preset -o ...` | Strip everything back to Pure-style for contrast. |

Preview before overwriting:

    starship preset <name> -o - | less

Validate after edits:

    starship config        # validate TOML syntax
    starship explain       # describe what each rendered module is
    starship print-config  # print the merged effective config
    starship timings       # measure per-module render time

## Sources

- [Starship Presets gallery (official)](https://starship.rs/presets/)
- [Starship Configuration reference](https://starship.rs/config/)
- [Starship Advanced Configuration](https://starship.rs/advanced-config/)
- [Starship FAQ](https://starship.rs/faq/)
- [DeepWiki: Configuration Presets](https://deepwiki.com/starship/starship/4.4-configuration-presets)
- [Discussion #1107: Share your setup](https://github.com/starship/starship/discussions/1107)
- [Discussion #5435: NewLine and Right Prompt](https://github.com/starship/starship/discussions/5435)
- [Discussion #5950: Enable transient in zsh](https://github.com/starship/starship/discussions/5950)
- [Discussion #6138: Powerline inspired prompt](https://github.com/starship/starship/discussions/6138)
