#!/usr/bin/env bash
# One-shot setup for CachyOS + niri on the ASUS TUF F15 (FX507VV: i7-13620H, 16 GB, RTX 4060).
# Re-runnable: every step checks first; failures are collected and listed at the end.
#
#   bash bootstrap.sh             everything you used on Windows
#   bash bootstrap.sh --lean      skip the heavy GUI apps in packages/heavy.txt
#   bash bootstrap.sh --with-ml   also build ~/.venvs/tools (torch CUDA + your Windows pip set, ~6 GB)
set -uo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$HOME/bootstrap-$(date +%Y%m%d-%H%M).log"
exec > >(tee -a "$LOG") 2>&1

LEAN=0; WITH_ML=0
for a in "$@"; do
  case "$a" in
    --lean) LEAN=1 ;;
    --with-ml) WITH_ML=1 ;;
    *) echo "Unknown option: $a"; exit 1 ;;
  esac
done

FAILED=()
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; FAILED+=("$*"); }
have() { command -v "$1" >/dev/null 2>&1; }
list() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$1"; }

[[ $EUID -eq 0 ]] && { echo "Run as your normal user; the script calls sudo itself."; exit 1; }
grep -qi cachyos /etc/os-release || echo "Note: this doesn't look like CachyOS, continuing anyway."

sudo -v || exit 1
( while sleep 50; do sudo -n true; kill -0 $$ 2>/dev/null || exit; done ) 2>/dev/null &

# Splits a list into repo packages (pacman) and AUR packages (paru) automatically.
install_list() {
  local repo=() aur=() p
  while read -r p; do
    if pacman -Si "$p" >/dev/null 2>&1; then repo+=("$p"); else aur+=("$p"); fi
  done < <(list "$1")
  if ((${#repo[@]})); then
    sudo pacman -S --needed --noconfirm "${repo[@]}" || {
      echo "  batch failed, retrying one at a time"
      for p in "${repo[@]}"; do sudo pacman -S --needed --noconfirm "$p" || warn "pacman: $p"; done
    }
  fi
  for p in "${aur[@]}"; do
    paru -S --needed --noconfirm --skipreview "$p" || warn "AUR: $p"
  done
}

step "1/9  System update"
sudo pacman -Syu --noconfirm || warn "pacman -Syu"
have paru || sudo pacman -S --needed --noconfirm paru || warn "paru"

step "2/9  Packages"
install_list "$KIT/packages/core.txt"
install_list "$KIT/packages/apps.txt"
((LEAN)) || install_list "$KIT/packages/heavy.txt"
if ! pacman -Qq power-profiles-daemon >/dev/null 2>&1 && ! pacman -Qq tuned-ppd >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm power-profiles-daemon || warn "power-profiles-daemon"
fi
have niri || install_list <(printf 'niri\nxwayland-satellite\n')

step "3/9  Memory: zram swap + earlyoom (the OOM fix)"
if ! swapon --show=NAME --noheadings | grep -q zram; then
  sudo install -Dm644 "$KIT/config/zram-generator.conf" /etc/systemd/zram-generator.conf
  sudo systemctl daemon-reload
  sudo systemctl start systemd-zram-setup@zram0.service || warn "zram"
fi
swapon --show
sudo install -Dm644 "$KIT/config/earlyoom" /etc/default/earlyoom
sudo systemctl disable --now systemd-oomd.service systemd-oomd.socket >/dev/null 2>&1
sudo systemctl enable --now earlyoom || warn "earlyoom"
sudo systemctl restart earlyoom >/dev/null 2>&1
sudo install -Dm644 "$KIT/config/journald-size.conf" /etc/systemd/journald.conf.d/size.conf
sudo systemctl restart systemd-journald

step "4/9  Laptop: 80% charge limit, power profiles, NVIDIA offload, SSD trim"
if ls /sys/class/power_supply/BAT*/charge_control_end_threshold >/dev/null 2>&1; then
  sudo install -Dm644 "$KIT/config/battery-charge-limit.service" /etc/systemd/system/battery-charge-limit.service
  sudo systemctl daemon-reload
  sudo systemctl enable --now battery-charge-limit.service || warn "battery charge limit"
else
  warn "battery charge limit not exposed by this kernel (skipped)"
fi
[[ -f /usr/lib/systemd/system/power-profiles-daemon.service ]] && sudo systemctl enable --now power-profiles-daemon.service
sudo systemctl enable --now fstrim.timer
if lspci | grep -qi nvidia && ! pacman -Qq | grep -q '^nvidia'; then
  { have chwd && sudo chwd -a; } || warn "NVIDIA driver missing: run 'sudo chwd -a' and reboot"
fi

step "5/9  Docker (socket-activated: zero RAM until you use it)"
sudo systemctl disable --now docker.service >/dev/null 2>&1
sudo systemctl enable --now docker.socket || warn "docker.socket"
id -nG "$USER" | grep -qw docker || sudo usermod -aG docker "$USER"

step "6/9  Languages: Java 21 (+17), Node 24, Rust, Python"
sudo archlinux-java set java-21-openjdk || warn "archlinux-java set java-21-openjdk"
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
mise use -g node@24 || warn "mise node@24"
if have npm; then
  npm config set fund false
  npm config set update-notifier false
  list "$KIT/packages/npm-global.txt" | xargs -r npm install -g || warn "npm globals (see log)"
fi
rustup default stable >/dev/null || warn "rustup default stable"
if ((WITH_ML)); then
  PY="$HOME/.venvs/tools/bin/python"
  uv venv "$HOME/.venvs/tools" --python 3.13 || warn "uv venv"
  uv pip install --python "$PY" torch torchaudio --index-url https://download.pytorch.org/whl/cu126 || warn "torch (CUDA)"
  uv pip install --python "$PY" -r "$KIT/packages/python-tools.txt" || warn "python tools"
fi

step "7/9  Flutter + Android SDK (Android Studio optional)"
export ANDROID_HOME="$HOME/Android/Sdk"
FLUTTER_DIR="$HOME/development/flutter"
if [[ ! -d "$FLUTTER_DIR/.git" ]]; then
  git clone -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR" || warn "flutter clone"
fi
export PATH="$FLUTTER_DIR/bin:$ANDROID_HOME/platform-tools:$PATH"

SDKM="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
if [[ ! -x "$SDKM" ]]; then
  url=$(curl -fsSL https://developer.android.com/studio | grep -oE 'https://dl\.google\.com/android/repository/commandlinetools-linux-[0-9]+_latest\.zip' | head -1)
  tmp=$(mktemp -d)
  if [[ -n "$url" ]] && curl -fsSL "$url" -o "$tmp/clt.zip" && unzip -q "$tmp/clt.zip" -d "$tmp"; then
    mkdir -p "$ANDROID_HOME/cmdline-tools" && mv "$tmp/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  else
    warn "Android cmdline-tools download (get it from developer.android.com/studio#command-line-tools-only)"
  fi
  rm -rf "$tmp"
fi
if [[ -x "$SDKM" ]]; then
  yes | "$SDKM" --licenses >/dev/null 2>&1
  while read -r p; do
    "$SDKM" --install "$p" >/dev/null || warn "sdkmanager: $p"
  done < <(list "$KIT/packages/android-sdk.txt")
fi
if have flutter; then
  flutter config --no-analytics --jdk-dir=/usr/lib/jvm/java-21-openjdk --android-sdk="$ANDROID_HOME" >/dev/null || warn "flutter config"
  yes | flutter doctor --android-licenses >/dev/null 2>&1
  flutter precache --android >/dev/null || warn "flutter precache"
  echo "  $(flutter --version 2>/dev/null | head -1)   (Windows had 3.47.6)"
fi
[[ -f "$HOME/.gradle/gradle.properties" ]] || install -Dm644 "$KIT/config/gradle.properties" "$HOME/.gradle/gradle.properties"

step "8/9  Editors, Claude Code, session environment"
if have code; then
  while read -r e; do
    code --install-extension "$e" --force >/dev/null 2>&1 || warn "VS Code extension: $e"
  done < <(list "$KIT/packages/vscode-extensions.txt")
fi
have claude || { curl -fsSL https://claude.ai/install.sh | bash || warn "Claude Code install"; }
install -Dm644 "$KIT/config/environment.d/10-dev.conf" "$HOME/.config/environment.d/10-dev.conf"
install -Dm644 "$KIT/config/shell/10-session-env.fish" "$HOME/.config/fish/conf.d/10-session-env.fish"
grep -q 'environment-d-generator' "$HOME/.bashrc" 2>/dev/null || cat "$KIT/config/shell/bashrc-snippet.sh" >> "$HOME/.bashrc"
fc-cache -f >/dev/null

step "9/9  Git defaults"
git config --global core.autocrlf input
git config --global init.defaultBranch main
git lfs install >/dev/null
have gh && gh auth status >/dev/null 2>&1 && gh auth setup-git

echo
if ((${#FAILED[@]})); then
  printf '\033[1;33m%d item(s) need a look:\033[0m\n' "${#FAILED[@]}"
  printf '  - %s\n' "${FAILED[@]}"
else
  printf '\033[1;32mAll steps succeeded.\033[0m\n'
fi
echo "Full log: $LOG"
echo "Next: bash restore.sh, then reboot (docker group and the new PATH apply after a fresh login)."
