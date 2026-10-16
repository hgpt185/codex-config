# codex-config

Put your **usage limits, context window usage, and session details** in the
footer of the [OpenAI Codex CLI](https://github.com/openai/codex) — so you can
see what you have left without pressing a key.

```
GPT-6.1-Sol default · main · ~/Projects/my-app · 272k window · Context 62% left · 5h 88% left · weekly 98% left · 128k used
```

That is: the model you're on, the branch you're on, where you are, how full
your context window is, **how much of your 5-hour and weekly plan limits are
left**, and how many tokens this session has burned.

## Why

Codex can already show you this — but only behind `/status`, a modal you have to
open, which covers up your conversation and closes again. The
`tui.status_line` setting makes the same information ambient: it lives at the
bottom of the terminal, updated live, all session long.

## Requirements

- Codex CLI with `tui.status_line` support — verified working on **0.162.1**
- macOS, Linux, or WSL
- Nothing else. No dependencies, no plugins, no shell profile changes.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/hgpt185/codex-config/main/install.sh | sh
```

Restart Codex. That's it.

### Pick a preset

The default `balanced` assumes a reasonably wide terminal. If you work in
split panes or a narrow window, use `minimal`:

```bash
curl -fsSL https://raw.githubusercontent.com/hgpt185/codex-config/main/install.sh | sh -s -- --preset minimal
```

| Preset | For | Items |
| --- | --- | --- |
| `minimal` | narrow terminals, split panes | model, context left, 5h limit |
| `balanced` | **default** — normal full-screen use | + branch, dir, window size, weekly limit, tokens used |
| `verbose` | wide terminals (120+ cols) | + run state, reasoning, fast mode, diff stats, PR, input/output tokens, permissions, approval mode, task progress, version |

### See it before you commit to it

```bash
git clone https://github.com/hgpt185/codex-config.git
cd codex-config
./install.sh --dry-run --preset verbose
```

`--dry-run` prints exactly what your `config.toml` would become and writes
nothing.

### Install by hand

If you'd rather not pipe a script into your shell, clone and copy:

```bash
git clone https://github.com/hgpt185/codex-config.git
```

Then merge the `[tui]` block from `presets/balanced.toml` into
`~/.codex/config.toml`. **If a `[tui]` table already exists, replace it** —
TOML forbids defining the same table twice, and Codex will refuse to start
otherwise. (The installer handles this for you.)

To find your config file: `codex --help` mentions `$CODEX_HOME`, which defaults
to `~/.codex`. Set `CODEX_HOME` yourself if you keep it elsewhere.

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/hgpt185/codex-config/main/install.sh | sh -s -- --uninstall
```

This removes only the `[tui]` table and leaves the rest of your config alone. A
timestamped backup is written next to your `config.toml` either way.

### All installer options

```
-p, --preset <name>   minimal | balanced | verbose   (default: balanced)
-n, --dry-run         print the result, write nothing
-u, --uninstall       remove the managed [tui] block
-c, --codex-home DIR  use DIR instead of $CODEX_HOME or ~/.codex
-h, --help
```

## Customise

### The easy way

Inside a Codex session, type:

```
/statusline
```

That's an interactive picker with a live preview — toggle items on and off, and
reorder them with the arrow keys. It writes your choice to `config.toml` for
you. `/status` shows the full rate-limit panel with exact reset times.

### The file way

Edit the `status_line` array in `~/.codex/config.toml`:

```toml
[tui]
status_line = [
  "model-with-reasoning",
  "git-branch",
  "context-remaining",
  "five-hour-limit",
  "weekly-limit",
]
```

Items render **left to right, joined by ` · `**. Order is the order you list
them.

## Available status line items

### Usage and cost

| Item | Renders as | Notes |
| --- | --- | --- |
| `five-hour-limit` | `5h 88% left` | Primary plan limit. Hidden until the API reports it |
| `weekly-limit` | `weekly 98% left` | Secondary plan limit |
| `used-tokens` | `128k used` | Blended tokens for the session; hidden when zero |
| `total-input-tokens` | `12k in` | |
| `total-output-tokens` | `3.1k out` | |
| `thread-credits` | `4.2 credits` | Enterprise workspaces only |
| `estimated-thread-cost` | `$0.18` | Enterprise workspaces only |

### Context window

| Item | Renders as |
| --- | --- |
| `context-remaining` | `Context 62% left` |
| `context-used` | `Context 38% used` |
| `context-window-size` | `272k window` |

### Model

| Item | Renders as |
| --- | --- |
| `model-with-reasoning` | `GPT-6.1-Sol default` |
| `model-name` | `GPT-6.1-Sol` |
| `reasoning` | `high` |
| `fast-mode` | `Fast on` / `Fast off` |
| `daybreak` | `Daybreak on` / `off` |

### Location and git

| Item | Renders as | Notes |
| --- | --- | --- |
| `current-dir` | `~/Projects/my-app` | Shortened home-relative |
| `project-name` | `my-app` | Project root, if detected |
| `git-branch` | `main` | Hidden outside a git repo |
| `branch-changes` | `+12 -3` | vs. the default branch |
| `pull-request-number` | `PR #123` | |
| `hostname` | `laptop` | |

### Session

| Item | Renders as |
| --- | --- |
| `status` (or `run-state`) | `Ready` / `Working` / `Thinking` |
| `thread-title` | Current thread title |
| `thread-name` | Current thread name |
| `thread-id` | Full UUID |
| `task-progress` | Latest `update_plan` progress |
| `codex-version` | `0.162.1` |
| `raw-output` | `raw output` when raw scrollback is on |

### Safety

| Item | Renders as |
| --- | --- |
| `permissions` | Active permission profile or sandbox mode |
| `approval-mode` | Active approval policy |

## Troubleshooting

**`sh: line NNN: syntax error`.**
`raw.githubusercontent.com` caches aggressively, so right after a release you
can be served the *previous* version of `install.sh`. It catches up in a few
minutes. To bypass it entirely:

```bash
git clone https://github.com/hgpt185/codex-config.git
cd codex-config && ./install.sh
```

Or pin to a known-good commit:
`https://raw.githubusercontent.com/hgpt185/codex-config/<commit-sha>/install.sh`

**The footer looks unchanged.**
Restart Codex — the config is read at startup. Inside a session, `/statusline`
shows a live preview so you can confirm the items are wired up.

**One of my items isn't showing.**
Codex **silently ignores** unrecognised status line identifiers — no error, no
warning. If an item is missing, check the spelling against the tables above.
The installer warns about unknown identifiers, and
`./scripts/verify-sync.sh` validates every item in this repo.

**The line is truncated.**
On narrow terminals Codex elides the middle of the status line. Drop
`current-dir` first — it's the widest item. `minimal` exists for exactly this.

**`five-hour-limit` / `weekly-limit` don't appear at startup.**
They come from rate-limit headers on the API response, so they're empty until
your first turn completes. They show up right after.

**`model-name` is rejected but it's in the table above.**
Newer builds accept it; some older ones only accept `model-with-reasoning`,
which works everywhere. Prefer `model-with-reasoning`.

**I have a `[tui]` table already.**
The installer removes the old one before appending, so duplicates are fine. If
you merged by hand and Codex now refuses to start with a TOML parse error,
you've defined `[tui]` twice — delete the older copy.

## What the installer does

1. Backs up `config.toml` to `config.toml.backup-<timestamp>`
2. Strips any existing `[tui]` and `[tui.*]` tables (avoids duplicate-table errors)
3. Appends the chosen preset
4. Preserves your file's permissions (`0600` if it was already private)

It never touches any other part of your config, and it never reads or writes
`auth.json`.

## Repository layout

```
config.toml            portable config — the 'balanced' preset
presets/
  minimal.toml
  balanced.toml
  verbose.toml
install.sh             installer; presets are embedded here
scripts/verify-sync.sh keeps install.sh and the .toml files in sync
```

## Contributing

`install.sh` embeds the presets so `curl | sh` works in one round trip, which
means they also exist as readable files. If you edit a preset, run:

```bash
./scripts/verify-sync.sh
```

It checks that every status line identifier is real and that the embedded
presets still match `presets/*.toml`. Pull requests that skip this will fail
the check.

## License

MIT — see [LICENSE](LICENSE).
