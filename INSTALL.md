# Windows → CachyOS + niri: your final steps

Everything on this SSD was prepared while you were at the gym. You need about **45–60 minutes**, most of it waiting.
Total hands-on time is roughly 15 minutes.

**Read this on your phone during Parts 2–4** (the laptop will be busy): it's also `INSTALL.md` in your private repo
https://github.com/https-shubhamsahu/dotfiles

## What's on this SSD (`linux-migration/`)

| Folder | What |
|---|---|
| `projects/_Active_Projects` | All projects with full `.git` history, uncommitted work and local branches (rebuildable folders like `node_modules`, `.venv`, `build` skipped) |
| `home/` | Desktop, Documents, Downloads, Pictures, Videos, `tools` (google-flow MCP), `_Development_Tools`, `esp`, `supabase`, OneDrive copy |
| `secrets/` | Play upload keystores + `key.properties`, all `.env` files, Android debug key, your API-key environment variables. **This drive is not encrypted: keep it safe.** |
| `configs/` | `~/.claude` (memory, skills, plugins, settings), `.claude.json`, Codex/Gemini/Supabase/MCP-auth/HyperFrames configs, VS Code + OBS settings, fonts |
| `cache/huggingface` | Your ~32 GB of downloaded models (MusicGen, faster-whisper, Qwen3-TTS, Chatterbox, MossFormer2), so you don't re-download them |
| `inventory/` | Every Windows program, store app, npm/pip package, VS Code extension and Android SDK piece |
| `installer/` | CachyOS ISO (260809) + Ventoy 1.1.18, both **checksum-verified** |
| `linux-setup/` | `bootstrap.sh` (installs everything), `restore.sh` (puts your stuff back). Also on GitHub as the private repo `https-shubhamsahu/dotfiles` |
| `REPORT.md` | What was verified, and what was intentionally left behind |

---

## Part 1: Make the installer USB (Windows, 5 min)

1. Plug in the **pen drive** (8 GB+). It will be erased.
2. Run **`D:\linux-migration\installer\ventoy-1.1.18\Ventoy2Disk.exe`** (already extracted and verified) → allow the admin prompt.
3. In **Device**, pick the **pen drive**. Check the size: it must **not** be the 466 GB SSD.
4. Click **Install** → confirm both warnings.
5. Copy `D:\linux-migration\installer\cachyos-desktop-linux-260809.iso` onto the pen drive (the drive named **Ventoy**).
6. **Eject and unplug the external SSD now**, so the installer can't touch it.

## Part 2: Install CachyOS (about 20 min)

7. Restart. While it boots, tap **F2** to open the BIOS.
   - Press **F7** (Advanced Mode) → **Security** → **Secure Boot** → **Secure Boot Control: Disabled**.
   - If you see **Advanced → VMD setup menu → Enable VMD controller**, set it to **Disabled** (otherwise Linux can't see the disk; Windows is being wiped anyway).
   - **F10** to save and exit.
8. While it restarts, tap **Esc** → pick the **USB / UEFI pen drive** entry → Ventoy menu → **cachyos-desktop-linux-260809.iso** → **Boot in normal mode** → first CachyOS entry.
9. In the live desktop, connect **Wi-Fi**, then in **CachyOS Hello** click **Launch Installer**.
10. Installer choices:
    - Location **Asia/Kolkata**, keyboard **English (US)**
    - Partitions: **Erase disk** → the **Micron 2400 (477 GB)** disk → filesystem **btrfs** → swap **No swap** (zram replaces it)
    - Bootloader: keep the default
    - Desktop: **Niri**
    - User: username **`shubh`** (keeps every project path and your Claude memory working). Pick a password.
11. **Install** → when done, **Restart** and pull out the pen drive.

## Part 3: Set everything up (30–60 min, mostly unattended)

12. Log in. niri shows its shortcut list at first login (**Super + Shift + /** brings it back). Open a terminal (**Super + T** in niri's default config).
13. If Wi-Fi isn't connected: run `nmtui`.
14. Plug in the external SSD and mount it:
    ```bash
    lsblk -f
    ```
    Find the **465 G exfat** partition (for example `sda1`), then:
    ```bash
    udisksctl mount -b /dev/sda1
    ```
15. Run the setup (asks for your password once, then installs everything):
    ```bash
    cd /run/media/$USER/*/linux-migration/linux-setup && bash bootstrap.sh
    ```
    It ends with a list of anything that failed (usually zero to a couple of AUR packages; re-running is safe).
16. Put your files back:
    ```bash
    bash restore.sh
    ```
    It prints every repo with its count of changed files. They should match the table in `REPORT.md`.
    Add `--with-models` to also copy the 32 GB model cache.
17. **Reboot.**

## Part 4: Sign in (5 min)

```bash
gh auth login
```
```bash
gh auth setup-git
```
```bash
claude
```
Then sign into Chrome (bookmarks, passwords and extensions come back via sync), and as needed `firebase login`, `vercel login`, `gcloud auth login`.
Supabase, Codex, Gemini and the MCP auth configs were restored, so try them before logging in again.

## Part 5: Quick checks

```bash
free -h && swapon --show && systemctl is-active earlyoom
```
Idle RAM should be around 1 GB, with a zram swap device and earlyoom `active`.
```bash
prime-run nvidia-smi
```
Shows the RTX 4060. Use `prime-run <app>` for renders, MusicGen or Parakeet; everything else stays on the Intel GPU (cooler and quieter, with longer battery).
```bash
flutter doctor
```
```bash
adb devices
```
Plug in your phone with USB debugging on. Use the phone instead of the emulator: it saves 2–4 GB of RAM.

## Optional extras

- `bash bootstrap.sh --with-ml` builds `~/.venvs/tools` with CUDA torch and your Windows Python packages (~6 GB).
- Heavy apps (Android Studio, Blender, FreeCAD, KiCad, Cura, LibreOffice, Arduino IDE, Brave, .NET, Ollama) are installed by default. Next time, `--lean` skips them.
- **Keep this SSD untouched for 2 weeks.** It's your only copy of the Windows-era state.
