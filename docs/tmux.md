# tmux: your terminal workspace

## 1. What tmux is, and why the prefix key matters

**tmux** is a *terminal multiplexer*. That sounds technical, but the idea is simple: it is a program that runs inside your terminal window and lets you split that one window into several *panes* (side-by-side or stacked shells), organize them into named *windows* (like tabs), and group windows into *sessions*.

The practical payoff is that a session **survives disconnects**. If you start tmux over SSH and your laptop sleeps, your Wi-Fi drops, or you close the window, the tmux server keeps running on the remote machine. When you reconnect and re-attach (`tmux attach`), everything is exactly where you left it — no lost scrollback, no half-finished commands killed. This is why tmux is the standard tool for anyone doing real work over SSH or in a terminal all day.

Structure, from big to small:

- **Session** — a named workspace that keeps running when you detach.
- **Window** — like a browser tab inside a session. Each session can have many.
- **Pane** — a split inside a window. Each pane runs its own shell or program.

### The prefix key, in plain language

tmux must intercept some keystrokes *before* the program inside the pane (usually your shell) sees them. But the terminal keyboard is already crowded: many keys are shortcuts for the shell itself. In particular, the shell uses **emacs-style line-editing keys** (the default for bash and zsh):

- **C-a** (Control + A) — jump the cursor to the **start of the line**
- **C-e** (Control + E) — jump to the **end of the line**
- **C-b** (Control + B) — move the cursor **back one character**

So tmux cannot just grab C-a or C-b by themselves — they are already spoken for. Instead, tmux uses a **prefix key**: you press one key to say "next key is for tmux", then a second key for the actual command. The prefix is a bit like a shift key for tmux: it turns otherwise-normal keys into commands.

Our config uses **C-a as the prefix** (a classic choice — see the keybinding conventions in section 2). Because C-a is also the shell's "start of line" shortcut, we add one rule to remove the conflict:

```
bind C-a send-prefix
```

This line means: **press C-a twice** — the first C-a tells tmux "a tmux command is coming", the second C-a is caught by `bind C-a send-prefix` and forwarded to the shell as a *real* C-a. So:

- `C-a` then `c` → tmux command (new window)
- `C-a` then `C-a` → a literal C-a reaches your shell, where it works as "jump to start of line" as usual

This "double-press to pass the prefix through" convention exists in many tmux setups for exactly this reason: it keeps a busy key working for both tmux and the shell.

## 2. The tmux ecosystem, classified

tmux itself is a lean core. Almost everything that makes it comfortable — themes, save/restore, clipboard integration — comes from **plugins**. Here is the whole field, grouped by what each tool does, with the star counts and license facts that matter (stars as of 2026-08-08).

### Plugin managers

A plugin manager installs, updates, and loads other tmux plugins for you.

- **tpm** (tmux plugin manager) — 14,984★, active, MIT license — **the standard**. You list plugins in your `tmux.conf` with `set -g @plugin '...'` lines, and tpm installs them on first run and updates them with a keystroke.
- **tundle** — 77★, dead — an older alternative that is no longer maintained; no reason to use it today.
- **TUI upstarts: tmuxpanel / tpack / ahiru-tpm** — too new to judge. Watch them if you like, but they have no track record yet.

### Base configs

Full configuration packs that give you a sane, modern tmux out of the box.

- **gpakosz/.tmux ("Oh My Tmux!")** — 25,272★, active, MIT — the all-in-one power config: sensible defaults, a powerline-style status bar, C-a as a secondary prefix, and per-user overrides via a `.tmux.conf.local` file so you can customize without forking.
- **tmux-sensible** — 2,215★, MIT — a small set of base settings ("sensible" options) that appears in most dotfiles, including the mainstream stack in section 4.
- **erikw/tmux-powerline** — 3,829★, BSD-3 — a segment framework for building status bars; heavier and more configurable than a theme, useful mainly if you want to build your own bar.

### Themes

Themes change how the status bar and borders look.

- **catppuccin/tmux** — 3,135★, active, MIT — the de-facto default theme. Needs tmux ≥ 3.2. Uses hex colors, which get *approximated* on Terminal.app (see section 5). Our config uses it with the `mocha` flavour.
- **dracula/tmux** — 852★, active, MIT — the Dracula palette, popular in editors.
- **nord** — 1,196★, stale-ish, 256-color friendly — the Nord palette; works exactly on 256-color terminals because it sticks to the 256-color space.
- **jimeh/tmux-themepack** — 1,754★, **no license file** — a grab-bag of themes; the missing license is a legal red flag.
- **rose-pine** — 274★, active, MIT — the Rosé Pine palette.
- **tokyo-night** — 570★, **NOASSERTION license** — the Tokyo Night palette; the license field is unasserted, so treat it with care.
- **gruvbox** — 697★, GPL-3.0 — the Gruvbox palette; GPL applies if you redistribute.

### Utility plugins

These add real functionality — save/restore, clipboard, search, and more.

- **tmux-resurrect** — 12,989★ — save and restore tmux sessions (windows, panes, even running programs) across restarts. Ubiquitous; tmux still has **no native equivalent** (see section 3).
- **tmux-continuum** — 4,044★ — automatic save/restore on an interval, so a crash or reboot loses nothing. On macOS, the auto-start feature needs launchd.
- **tmux-yank** — 3,095★ — copy to the system clipboard from tmux. Works locally via `pbcopy`; note that **OSC 52** (the terminal-protocol way to set the clipboard) is **not supported by Terminal.app**, so yanking over a remote SSH session won't reach your local clipboard there.
- **tmux-fingers** — 1,458★, Crystal build — vimium-style hints: press a key, every "copyable" thing on screen gets a letter, type it, done.
- **tmux-thumbs** — 1,092★, Rust build — the same idea as tmux-fingers, implemented in Rust.
- **tmux-copycat** — 1,204★ — regex search across scrollback; partly superseded by tmux's native search.
- **tmux-prefix-highlight** — 672★ — flashes the status bar when you've pressed the prefix; built into catppuccin, so we don't need it separately.
- **tmux-cpu** — 535★ — CPU usage in the status bar.
- **tmux-battery** — 572★ — battery percentage in the status bar (handy on a laptop).
- **tmux-sessionx** — 1,357★, GPL-3.0 — an fzf-based session switcher with popup mode.
- **tmuxinator** — 13,697★, Ruby — launch predefined session layouts from a YAML file.
- **tmuxp** — 4,553★, Python — the Python-flavored equivalent of tmuxinator: YAML session layouts.
- **vim-tmux-navigator** — 6,266★ — lets `C-h`/`C-j`/`C-k`/`C-l` move the focus across vim *and* tmux panes seamlessly. Only needed if you are a vim user.
- **tmux-MacOSX-pasteboard** — legacy — fixed old macOS clipboard quirks; unnecessary on modern macOS.

### Keybinding conventions

The community has settled on a few idioms, and different configs choose different sides:

- **C-b is the community default prefix.** It is what upstream tmux ships with.
- **C-a is the screen heritage prefix.** GNU screen (tmux's ancestor) used C-a, and oh-my-tmux supports it as a secondary prefix. We use C-a as our prefix — it's closer to the home row and doesn't collide with vim's C-b scrolling if you use vim.
- **Vim-style h/j/k/l pane navigation** is the convention in oh-my-tmux and the pain-control configs: with the prefix pressed, `h`/`j`/`k`/`l` move to the pane left/down/up/right instead of `C-arrow` keys.
- **Split key conventions vary**: tmux-sensible uses `|` for a vertical split and `-` for a horizontal split; oh-my-tmux uses `-` and `_`. Our config follows tmux-sensible's spirit but uses tmux's classic `%` and `"` (section 6).

## 3. What tmux 3.x can do natively (no plugin needed)

Each new tmux release has folded popular plugin features into the core. The native features that matter (with the version that introduced them):

- **display-popup** (tmux 3.2) — run a command in a small floating popup window in the middle of your session. This is what powers tools like tmux-sessionx's popup mode.
- **display-menu** (tmux 3.2) — a real menu you can open with the prefix; items can run commands, so you can build a right-click-style menu with zero plugins.
- **choose-tree filters and previews** — the session/window switcher can filter by typing and preview panes, replacing the old bare lists.
- **Floating panes** (tmux 3.7) — panes that float over the session instead of being tiled, useful for quick scratch shells and popup-style tooling.
- **switch-mode** (3.8 dev) — a dev-build feature for switching between input modes; not yet in a stable release.
- **Builtin themes** (3.8 dev) — tmux is gaining its own theming system; also still in development.

**What is still NOT native: session restore.** There is no built-in way to save a session to disk and bring it back after a reboot. That is exactly what **tmux-resurrect** (manual save/restore) and **tmux-continuum** (automatic save/restore) do — which is why they stay in our stack.

## 4. The mainstream day-to-day stack

The conventional 2025–26 setup, based on the evidence above (star counts) and converging recommendations across recent guides, is:

**tmux 3.7 (via Homebrew) + tpm + tmux-sensible + catppuccin + tmux-resurrect + tmux-continuum + tmux-yank**

Each piece is the most-starred, most-maintained option in its category: tpm at 14,984★ dwarfs every other plugin manager; tmux-sensible is the base config in "most dotfiles"; catppuccin (3,135★) is the de-facto theme; resurrect (12,989★) and continuum (4,044★) are the only real save/restore pair; tmux-yank (3,095★) is the standard clipboard plugin. Prefix-highlight comes built into catppuccin, tmux-sessionx + fzf is the optional switcher upgrade, and vim-tmux-navigator only enters the stack for vim users. This is exactly the stack our config in section 6 installs.

## 5. Terminal, theme, and font evaluation

This section is your review material for the upcoming choice: which terminal, theme, and font to run. It is written to be read before you decide, so it stays neutral and complete.

### Terminal.app (the built-in macOS terminal)

Free, preinstalled, zero setup — but with real limitations:

- **No truecolor** — it only supports 256 colors. Modern themes (catppuccin, dracula, …) are defined in *truecolor* hex values, so on Terminal.app those colors get **approximated** to the nearest 256-color entry. The look is close but never exact.
- **No italics** — italics render as plain or oblique text depending on the app.
- **No OSC 52** — OSC 52 is the terminal protocol a program uses to say "please put this in the system clipboard". Without it, tmux-yank cannot copy to your *local* clipboard when you are on a **remote SSH session**; local copies still work through `pbcopy`.
- **NO font fallback to user-installed fonts** — this one is verified: when the profile font lacks a glyph (a character), Terminal.app does *not* fall back to other fonts you have installed; CoreText resolves to LastResort (a font of last resort), so the glyph renders as a box. This is exactly why the nerd-font icons currently display as boxes: the profile font is a non-nerd font, and the nerd glyphs cannot be pulled from the installed nerd font. The consequence: **the profile font itself must be a nerd font** — there is no other way to get icons on Terminal.app.

### iTerm2 (free, one brew cask)

The mainstream Mac terminal, and the fix for every Terminal.app limitation above:

- **Truecolor + italics** — catppuccin and friends render at full fidelity.
- **OSC 52 support** — tmux-yank works over remote SSH too.
- **Font fallback** — missing glyphs fall back to other installed fonts, so nerd icons render even if the profile font is a plain one (though our setup picks a nerd font anyway).

It is free, installs with one Homebrew cask, and is the de-facto Mac developer terminal. The trade-off is a larger settings surface — more to configure, more to learn.

### WezTerm / Ghostty / Kitty

The same fidelity class as iTerm2 (truecolor, italics, OSC 52, font fallback), with newer and smaller communities. They are fine terminals; for this evaluation they are mentioned as options, not recommended — iTerm2's maturity and mainstream status cover the same ground.

### Themes

- **catppuccin mocha** — the mainstream pick, defined in hex; needs truecolor for full fidelity (approximated on Terminal.app).
- **nord** — the 256-color-exact option: on Terminal.app it renders precisely, since it stays inside the 256-color space. Less flashy than catppuccin.
- **dracula / tokyo-night / rose-pine / gruvbox** — alternative palettes, all hex-based (so also approximated on Terminal.app).

### Fonts

The three candidate families, all nerd fonts (patched with icon glyphs so the tmux status bar and prompt icons render):

- **JetBrains Mono Nerd Font** — the default pick. Clean, readable, no ligatures (ligatures are the joined "=>"-style glyphs some fonts add); the safest everyday choice.
- **Meslo LG Nerd Font** — the classic companion to Powerlevel10k (a popular zsh theme); slightly wider, a familiar look to many dotfile setups.
- **Fira Code Nerd Font** — includes *ligatures*, which change how code appears (pairs like `!=` and `=>` render as single joined glyphs). Great if you like that, surprising if you don't.

(If the iTerm2 route is chosen, any of these works; iTerm2's font fallback also means a plain text font would still render icons.)

## 6. Keybinding cheat sheet (our config)

This is the exact config we will install (tmux.conf): prefix **C-a**, tpm plugins (sensible, catppuccin mocha, resurrect, continuum with 15-minute auto-save, yank), vim-style pane navigation, and a catppuccin-mocha status bar.

| Keys | What happens |
|---|---|
| `C-a` | **Prefix.** Press first, then the command key. |
| `C-a` `c` | New window (like a new tab). |
| `C-a` `%` | Split pane **vertically** (left | right). |
| `C-a` `"` | Split pane **horizontally** (top / bottom). |
| `C-a` `h` / `j` / `k` / `l` | Move to the pane **left / down / up / right** (vim-style). |
| `C-a` `C-s` | **Save** the session now (tmux-resurrect). |
| `C-a` `C-r` | **Restore** the session (tmux-resurrect; continuum also restores automatically). |
| `C-a` `C-a` | **Literal C-a** to the shell — "jump to start of line" works as usual. |
| `C-a` `?` | List all key bindings. |
| Wheel up / `PgUp` | **Scroll up** through the pane's history (copy mode; `q` exits, scrolling to the bottom exits too). |
| `C-a` `[` | Enter copy mode manually (arrows/`h`/`j`/`k`/`l` move, `q` exits). |
| `tmux attach` | Re-attach to your session after a disconnect (sessions survive — see section 1). |

Two notes:

- **Plugins auto-install on first run.** The config's final line (`run '~/.tmux/plugins/tpm/tpm'`) makes tpm install everything in the plugin list the first time tmux starts (needs network). If it ever needs a manual nudge: `~/.tmux/plugins/tpm/scripts/install_plugins.sh`.
- The editor warning: omp's `Ctrl+G` draft-editing feature uses `$VISUAL`/`$EDITOR`; install.sh sets them (`code --wait` by default, `vim`/`nano` as one-word alternatives) so the editor opens without a warning.

---

**TL;DR** — tpm + tmux-sensible + catppuccin (mocha) + tmux-resurrect + tmux-continuum + tmux-yank, prefix `C-a`.
