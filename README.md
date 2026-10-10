# dotfiles: CachyOS + niri setup

Rebuilds my dev machine (ASUS TUF F15 FX507VV, 16 GB RAM, RTX 4060) on CachyOS with niri,
tuned to stop out-of-memory freezes: zram swap, earlyoom, socket-activated Docker, capped Gradle,
desktop on the Intel GPU with `prime-run` for the RTX 4060.

```bash
bash bootstrap.sh          # packages, toolchains (Flutter, Android SDK, JDK 21/17, Node 24, Rust, Go), Claude Code
bash restore.sh <backup>   # projects, secrets, Claude memory/settings, configs from a migration backup
```

| Path | What |
|---|---|
| `bootstrap.sh` | Re-runnable installer; `--lean` skips heavy apps, `--with-ml` builds the CUDA Python venv |
| `restore.sh` | Restores a `linux-migration/` backup; rewrites Windows paths (git worktrees, Claude config, MCP servers) |
| `packages/` | pacman/AUR lists (auto-detected), npm globals, VS Code extensions, Android SDK pieces, Python tools |
| `config/` | earlyoom, zram fallback, journald cap, 80% charge limit, Gradle limits, session environment |
| `lib/` | Windows → Linux path fixers for JSON configs and Claude project folders |
| `docs/app-map.md` | What replaced each Windows app |

No secrets live in this repo. Keys, `.env` files and keystores stay on the backup drive.
