# Windows → Linux app map

Built from `inventory/installed-programs.csv` and `inventory/store-apps.csv` on 2026-10-10.

| Windows | Linux | How |
|---|---|---|
| Android Studio 2026.1 | `android-studio` (AUR) | heavy.txt. Flutter builds don't need it: SDK + cmdline-tools come from bootstrap |
| Arduino IDE 2.3.10 / Cloud Agent | `arduino-ide-bin` (AUR), `arduino-cli` | heavy.txt; Cloud Agent: use the web editor |
| Blender 5.2.2 | `blender` | heavy.txt |
| Brave | `brave-bin` (AUR) | heavy.txt |
| Google Chrome | `google-chrome` (AUR) | apps.txt; sign in to sync |
| Microsoft Edge | not installed | use Chrome |
| Cloudflare / cloudflared | `cloudflared` | core.txt (WARP client, if that's what "Cloudflare 1.0" was: `cloudflare-warp-bin` from AUR) |
| Deno, Go, Rust, Node 24, Python 3.13 | `deno`, `go`, `rustup`, `mise` (node@24), `python` + `uv` | core.txt |
| .NET SDK 10 | `dotnet-sdk` | heavy.txt |
| Docker Desktop | `docker` engine + compose + buildx | socket-activated: no 6 GB VM sitting in RAM |
| Figma + Figma Agent | figma.com in Chrome (install as app) | for local fonts: `figma-agent-linux` (AUR) |
| FreeCAD 1.1.3 | `freecad` | heavy.txt |
| Git, GitHub CLI | `git`, `git-lfs`, `github-cli` | core.txt |
| Google Cloud SDK | `google-cloud-cli` (AUR) | apps.txt |
| Inkscape | `inkscape` | apps.txt |
| KiCad 10 | `kicad`, `kicad-library` | heavy.txt |
| LibreOffice 26.2 | `libreoffice-fresh` | heavy.txt |
| Logi Options+ | `solaar` | apps.txt |
| OpenJDK 17 + 21 | `jdk17-openjdk`, `jdk21-openjdk` | 21 is default (`archlinux-java`) |
| OBS Studio | `obs-studio` | scenes/profiles restored by restore.sh |
| PowerToys | niri itself (tiling, launcher, shortcuts) | |
| Quick Share | `rquickshare-bin` (AUR) | apps.txt |
| UltiMaker Cura | `cura-bin` (AUR) | heavy.txt |
| VLC | `vlc` | apps.txt |
| VS Code + 14 extensions | `visual-studio-code-bin` (AUR) | extensions + settings restored |
| Visual Studio Build Tools | `base-devel`, `clang`, `cmake`, `ninja` | core.txt |
| Windows Terminal | `foot` (or whatever CachyOS's niri setup ships) | core.txt |
| WhatsApp, NotebookLM, Copilot | web apps in Chrome | |
| OpenAI Codex app | `@openai/codex` CLI | npm-global.txt |
| Claude desktop app | Claude Code CLI + claude.ai | no official Linux desktop app |
| scoop: 7zip, ffmpeg, gcc, ripgrep, rustup, supabase | `7zip`, `ffmpeg`, `base-devel`, `ripgrep`, `rustup`, `supabase-bin` | |
| npm globals (gemini-cli, firebase-tools, vercel, opencode, ...) | same, via npm | npm-global.txt |
| Global pip (torch cu126, faster-whisper, elevenlabs, ...) | `~/.venvs/tools` | `bootstrap.sh --with-ml` |
| Ollama (OLLAMA_* env vars) | `ollama-cuda` | heavy.txt |
| NVIDIA App / Control Panel | `nvidia-prime` (`prime-run`), `nvidia-settings` | driver installed by CachyOS |
| ASUS Armoury/AURA/MyASUS | kernel asus-wmi (80% charge limit service, power profiles) | optional: `asusctl` (AUR) for keyboard RGB |
| Revo Uninstaller | `pacman -Rns <pkg>` | |
| TeighaX, Grok Bot, SimpleMD, Paint, Snipping Tool | not ported | niri has built-in screenshots (Print key) |
