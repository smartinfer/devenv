# devenv

**Anjan Goswami's dev setup for Mac Pros**
SmartInfer, Inc.

A single, auditable, Homebrew-free developer environment for Apple silicon Macs — polyglot toolchains, formal-methods tooling, AI coding agents, and local ML inference, with every install disclosed before it happens and removable afterwards.

Built for a MacBook Pro M5 Max / 128 GB, but nothing here is specific to that machine beyond a few notes about the Neural Accelerators.

---

## Why this exists

Package managers are convenient until you have seven language toolchains, and then they become the problem. Homebrew wants to own your Python, your Node, your Rust, and your JVM — but each of those languages already has a version manager that does the job better, and mixing the two produces shadowed binaries and version drift that take an afternoon to diagnose.

This repository takes the other approach:

1. **No Homebrew.** No sudo, except where Apple requires it.
2. **Everything under `$HOME`.** One directory per tool, no shared prefix.
3. **Every install is registered** with its filesystem roots and an exact purge command. Nothing is untraceable.
4. **Language runtimes come from that language's own manager**, never from a general-purpose one.
5. **Libraries are never global.** Only runtimes, compilers, and CLIs.

The result: `dev purge --all` genuinely returns the machine to where it started, and `dev registry` can always tell you what is on disk and how much space it takes.

---

## Quick start

```bash
git clone <your-remote> ~/tools/devenv
cd ~/tools/devenv

./test/run-tests.sh      # hermetic, no network, no installs — must pass first
./dev check              # what's installed and what isn't
./dev plan               # full disclosure of what an install would change
./dev install 00-base    # start here; wires the shell
```

The test suite is not optional decoration. It verifies bash 3.2 compatibility (macOS ships bash 3.2), that every item declares a purge command, that no `curl` call can pipe an HTTP error page into a shell, and that `plan`, `check`, and `--dry-run` write nothing. If it fails, don't run `dev`.

---

## Commands

```
dev check [targets]          What's installed, what isn't. The default.
dev plan [targets]           Full footprint disclosure. No prompts, no writes.
dev install [targets]        Check, disclose, prompt per item, install.
dev clean-install <target>   Purge, then install.
dev status [--commands]      Overview, deferrals, failures, and how to fix them.
dev purge <item>             Remove one item.
dev purge --cluster <name>   Remove a cluster.
dev purge --all              Remove everything (typed confirmation).
dev registry                 What's on disk, where, and how big.
dev doctor                   Correctness: PATH order, shadowing, Apple's python.
dev clusters                 List clusters and their items.
dev log [n]                  Tail the most recent log.
dev help
```

Flags: `--yes`, `--dry-run`, `--verbose`, `--no-color`, `--retry-deferred`.

A **target** is a cluster (`20-systems`), a cluster suffix (`systems`), or an item (`rust`). No target means everything, in cluster order.

---

## Nothing installs without asking

Every item shows its complete footprint before you decide. Six categories, and only the ones that apply are printed:

```
  rust  [missing]
  ──────────────────────────────────────────────────────────────────
  Rust via rustup — rustc, cargo, clippy, rustfmt, rust-analyzer
  ──────────────────────────────────────────────────────────────────
  HOME     ~/.rustup                    toolchains ~380MB
           ~/.cargo                     cargo home and bin ~70MB
  SHELL    path.zsh                     $HOME/.cargo/bin
  NETWORK  https://sh.rustup.rs
  SYSTEM   none
  APPS     none
  RECEIPT  none
  ──────────────────────────────────────────────────────────────────
  PURGE    rustup self uninstall -y
  ──────────────────────────────────────────────────────────────────
  [i]nstall  [s]kip for now  [n]ever  [d]etails  [q]uit →
```

| Category | Means |
|---|---|
| **HOME** | Directories created under `$HOME`, with sizes |
| **SHELL** | Which generated file in `shell/` changes, and how |
| **NETWORK** | The URL or registry that will be contacted |
| **SYSTEM** | Anything outside `$HOME` — always needs sudo, always flagged |
| **APPS** | Anything landing in `/Applications` |
| **RECEIPT** | A `pkgutil` receipt or LaunchAgent created |

`SHELL` never names your dotfiles directly. Everything writes into `shell/*.zsh` inside this repository; your `.zshenv`, `.zprofile`, and `.zshrc` are touched exactly once, during `00-base`, and that prompt shows the three lines verbatim first.

**Nothing ever touches `.bash_profile` or `.bashrc`.** macOS's login shell is zsh; its bash is 3.2 from 2007.

`--yes` skips prompts but **refuses to auto-approve any item with a SYSTEM or APPS footprint.** Those always ask.

---

## Skipping: "not now" vs "never"

| Choice | Recorded | Re-prompted? | Counted as open work? |
|---|---|---|---|
| `[s]` skip for now | `deferred.tsv`, mode `later` | Only with `--retry-deferred` or by naming it | Yes |
| `[n]` never | `deferred.tsv`, mode `never` | Only by naming it explicitly | No |

Both accept an optional one-line note, so six weeks later `dev status` says *"deferred — deciding Scryer vs SWI"* rather than showing an unexplained gap.

Skipping is sticky by design. A skipped item is not re-offered on the next `dev install` — it's counted in the summary and nothing more. **Failures are different** and do get retried automatically, since a failure is usually a stale URL or a flaky network.

`dev status --commands` prints copy-pasteable install commands for everything outstanding — the `dev` command, the manual equivalent, and an alternative where one exists — so you are never dependent on this script to make progress.

---

## The PATH problem on macOS, and why it's `.zprofile`

macOS has `/etc/paths.d`, and it is the wrong tool. `path_helper` **appends** your entries after the system defaults, so `/usr/bin` ends up ahead of `~/.local/bin` and Apple's `/usr/bin/python3` wins. It also needs sudo, lives outside `$HOME`, and can't run the shell hooks that `mise`, `opam`, and `direnv` require.

Worse: **macOS's `/etc/zprofile` runs `path_helper` on every login shell**, rebuilding PATH from scratch and demoting anything set in `.zshenv`. This is why the common "just put it in `.zshenv`" advice quietly fails on a Mac.

Zsh's startup order:

| File | Login shell | Interactive | Script / `zsh -c` |
|---|:-:|:-:|:-:|
| `.zshenv` | ✓ | ✓ | ✓ |
| `/etc/zprofile` → **path_helper** | ✓ | | |
| `.zprofile` | ✓ | | |
| `.zshrc` | ✓ | ✓ | |

So:

- **`shell/env.zsh`** ← `.zshenv` — environment variables only. This is the *only* file non-interactive shells read, which is why API keys belong here (AI agents spawn non-interactive shells).
- **`shell/path.zsh`** ← `.zprofile` — PATH, applied *after* `path_helper` so the prepends survive. Idempotent and de-duplicating, and also sourced from `env.zsh` so agent shells get it too.
- **`shell/interactive.zsh`** ← `.zshrc` — hooks, aliases, completions.

All three are **generated** from `state/shellents.tsv`, which is why purging an item removes its PATH entry exactly, with no leftovers.

> **GUI caveat.** Apps launched from Finder or the Dock inherit PATH from launchd, not from any shell. Cursor and VS Code will not see `~/.local/bin` unless you launch them from a terminal or set their integrated terminal to login-shell mode. No rc file can fix this.

---

## Clusters

Numbered so dependency order is visible in the filename.

| # | Cluster | Contents |
|---|---|---|
| 00 | `base` | Command Line Tools, shell wiring |
| 10 | `managers` | mise (runtimes), uv (Python) |
| 20 | `systems` | Rust, Ninja, CMake |
| 21 | `python` | CPython 3.12/3.13, global CLIs |
| 22 | `functional` | OCaml (opam), Haskell (ghcup) |
| 23 | `scientific` | Julia (juliaup) + Metal.jl |
| 24 | `symbolic` | SBCL, Quicklisp, Prolog |
| 25 | `containers` | Docker Desktop, Docker CLI, Compose, Linux VM |
| 30 | `formal` | Quint, Apalache, Lean 4, Z3, Alloy, TLA+ |
| 40 | `agents` | Claude Code, Codex, Gemini CLI |
| 41 | `editors` | VS Code, Cursor |
| 45 | `cloud` | Google Cloud CLI (`gcloud`, `bq`, `gsutil`) |
| 50 | `web` | FrankenPHP, Composer, Caddy |
| 60 | `ml` | No installs — MLX GPU verification |
| 70 | `latex` | **Verify only** — never installs or modifies TeX |

Suggested order for a fresh machine:

```bash
./dev install 00-base 10-managers 21-python
./dev install 40-agents 41-editors
./dev install 20-systems 30-formal
./dev install 25-containers 45-cloud
./dev install 50-web 70-latex
./dev install 22-functional 23-scientific 24-symbolic
./dev status
```

Splitting it means a failure in one cluster doesn't cost you the rest.

---

## Design decisions worth knowing

**`mise.toml` is data; `dev` is logic.** The TOML declares prebuilt runtimes (Node, Go, JVM) and is symlinked to `~/.config/mise/config.toml`. A bad line there is a config error you fix by editing text. A bad line in `dev` is a bug. Keeping them separate means you can always tell which you're looking at.

**Python belongs to uv, and only uv.** Listing `python` in `mise.toml` *and* installing uv gives you two interpreter sets shadowing each other — the single most common way a Mac Python setup rots. uv owns interpreters, virtualenvs, tool installs, and cache. Purge all of Python everywhere with `dev purge uv`.

Per-project venvs are correct, not chaos. uv hardlinks from one content-addressed cache, so twenty projects sharing torch cost roughly one copy on disk. And for throwaway experiments you don't need a venv at all — PEP 723 inline metadata plus `uv run script.py` resolves, caches, and runs with nothing to name or clean up.

**SBCL comes from a prebuilt tarball, not mise.** mise's SBCL plugin compiles from source, bootstraps via ECL on macOS, and needs zstd with `CPATH`/`LIBRARY_PATH` set — which on a Mac means a package manager. Its own README recommends against it.

**Java survives only as a dependency.** Apalache, Alloy, and TLA+ are JVM tools, and Quint's model checker *is* Apalache. mise installs a pinned Temurin LTS into one directory; you never write Java.

**PHP is FrankenPHP.** macOS stopped bundling PHP in Monterey. FrankenPHP is a single static binary containing the runtime and a web server — no extension hell, deletable in one `rm`.

**No hardcoded version inside a `/latest/download/` URL.** That pattern 404s the moment upstream cuts a release, because the path resolves to the newest release but the filename is pinned to an old one. Assets are resolved from the GitHub API instead. The test suite enforces this.

**`curl` always uses `-f`.** Without it, an HTTP 500 error page gets piped into `sh`. The test suite enforces this too.

---

## Local ML on Apple silicon

MLX is the only framework that uses the M5 GPU Neural Accelerators, and only on **macOS 26.2 or later**. Below that you keep the memory-bandwidth gain but lose the roughly 4× prefill speedup. `dev install mlx-check` verifies this and warns if your OS is too old.

PyTorch's MPS backend works but runs mostly eager, with `torch.compile` fusions frequently falling back. Use it for model definition and CUDA-portability testing, not for speed.

JAX has no good Apple-silicon story: Apple's `jax-metal` is effectively abandoned, and the community `jax-mps` plugin pins hard to Python 3.13 and a specific jaxlib. If a JAX project matters, run it on a CUDA box.

These are never installable on Apple silicon — keep them behind a `[cuda]` extra: `vllm`, `triton`, `flash-attn`, `bitsandbytes`, `autoawq`, `deepspeed`, `faiss-gpu`, `nccl`.

GPU wired-memory ceiling (default is ~75 % of RAM):

```bash
sudo sysctl iogpu.wired_limit_mb=122880    # ~120GB of 128GB
```

Resets on reboot. **Never set 131072** — starving the OS hard-hangs the machine.

---

## Logging

Every invocation writes `state/logs/<timestamp>-<action>.log`, with `latest.log` symlinked to the most recent. Logs are ANSI-stripped, record every command executed with its exit code, and carry a header with the macOS version, architecture, shell, and the git SHA of this repository. Retention prunes to the last 30.

```bash
./dev log          # last 200 lines of the most recent run
./dev log 1000
```

---

## Layout

```
devenv/
├── dev                   entrypoint — argv, commands, the 3-phase pipeline
├── lib/
│   ├── core.sh           paths, colours, logging, run/runsh
│   ├── item.sh           the item DSL, registry, deferrals, shell generation
│   ├── ui.sh             footprint cards, prompts, tables
│   └── install.sh        reusable installers (gh release, tarball, script)
├── clusters/*.sh         one file per cluster; declarative item definitions
├── shell/                GENERATED — env.zsh, path.zsh, interactive.zsh
├── state/                GENERATED — registry.tsv, deferred.tsv, logs/
├── test/run-tests.sh     hermetic self-tests
├── mise.toml             declarative runtime registry
└── README.md
```

`state/` and `shell/` are gitignored, except `deferred.tsv` — so a second Mac inherits your *decisions and notes* without inheriting a machine-specific installed-state.

## Adding a tool

Append an `item` block to the right cluster file and write its install function. The framework handles check, disclosure, prompting, verification, registry, and purge:

```bash
item name=foo \
  desc="One line describing what this is" \
  check='command -v foo' \
  version='foo --version' \
  method=gh-binary \
  home='~/.local/bin/foo:~5MB' \
  shell='' network='github.com/x/foo releases' \
  system='' apps='' receipt='' \
  purge='rm -f "$HOME/.local/bin/foo"' \
  manual='Download from github.com/x/foo/releases into ~/.local/bin' \
  install=install_foo

install_foo() { install_gh_bin x/foo 'darwin-arm64' foo; }
```

Then run `./test/run-tests.sh` — it checks that every item declares a description, check, method, purge, and a defined install function, and that no purge command targets an absolute root.

---

## Uninstalling everything

```bash
./dev purge --all      # runs every registered purge command, unwires the dotfiles
rm -rf ~/tools/devenv
```

TeX Live is registered but sits outside `$HOME` and needs sudo — deliberately, so it doesn't become unfindable a year later.

---

## Licence

MIT.
