#!/usr/bin/env bash
# Restores what the Windows backup put on the SSD: projects (full git history, dirty work,
# local branches), personal folders, secrets, Claude Code memory/settings, other CLI configs,
# VS Code + OBS settings, fonts and your API-key environment variables.
#
#   bash restore.sh                         finds the SSD backup by itself
#   bash restore.sh /path/to/linux-migration
#   bash restore.sh --with-models           also copy the ~98 GB Hugging Face model cache
set -uo pipefail

WITH_MODELS=0; SRC=""
for a in "$@"; do
  case "$a" in
    --with-models) WITH_MODELS=1 ;;
    *) SRC="$a" ;;
  esac
done
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$SRC" ]]; then
  if [[ -d "$KIT/../projects" ]]; then SRC="$(cd "$KIT/.." && pwd)"
  else SRC=$(ls -d /run/media/"$USER"/*/linux-migration 2>/dev/null | head -1); fi
fi
[[ -n "$SRC" && -d "$SRC/projects" ]] || { echo "Backup not found. Mount the SSD and pass its linux-migration folder."; exit 1; }
echo "Restoring from: $SRC"

WARN=()
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; WARN+=("$*"); }
command -v rsync >/dev/null || sudo pacman -S --needed --noconfirm rsync

# exFAT has no Unix permissions: normalise to 755 dirs / 644 files, then restore exec bits from git.
PERMS=--chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r
RS=(rsync -rt --info=progress2 "$PERMS")
P="$HOME/_Active_Projects"
C="$SRC/configs/home"
A="$SRC/configs/appdata"

step "1/8  Projects -> $P"
"${RS[@]}" "$SRC/projects/_Active_Projects/" "$P/"

step "2/8  Git: identity, worktree paths, exec bits, line endings"
if [[ -f "$C/.gitconfig" ]]; then
  for k in user.name user.email; do
    v=$(git config --file "$C/.gitconfig" "$k") && git config --global "$k" "$v"
  done
fi
# Windows checked files out with CRLF (core.autocrlf=true); 'input' keeps git status clean here.
git config --global core.autocrlf input
# Worktree links hold absolute Windows paths (gitdir: C:/Users/shubh/...). Point them at $HOME.
while IFS= read -r -d '' f; do
  sed -i -E "s#[Cc]:[/\\\\]+Users[/\\\\]+[^/\\\\]+#${HOME}#; s#\\\\#/#g" "$f"
done < <(find "$P" \( -name .git -type f -o -path '*/.git/worktrees/*/gitdir' \) -not -path '*/node_modules/*' -print0)
REPOS=()
while IFS= read -r -d '' g; do REPOS+=("$(dirname "$g")"); done \
  < <(find "$P" -maxdepth 7 -name .git -not -path '*/node_modules/*' -print0)
for r in "${REPOS[@]}"; do
  git -C "$r" ls-files -s 2>/dev/null | awk -F'\t' '$1 ~ /^100755/ {print $2}' |
    while IFS= read -r f; do [[ -f "$r/$f" ]] && chmod +x "$r/$f"; done
done
find "$P" \( -name gradlew -o -name '*.sh' \) -type f -not -path '*/node_modules/*' -exec chmod +x {} +
printf '\n  %-72s %s\n' REPO CHANGED-FILES
for r in "${REPOS[@]}"; do
  printf '  %-72s %s\n' "${r#"$P"/}" "$(git -C "$r" status --porcelain 2>/dev/null | wc -l)"
done
echo "  (Compare with $SRC/REPORT.md: the counts should match what Windows showed.)"

step "3/8  Personal folders + ~/tools"
for d in Desktop Documents Pictures Videos Downloads tools; do
  [[ -d "$SRC/home/$d" ]] && "${RS[@]}" "$SRC/home/$d/" "$HOME/$d/"
done
for d in "$HOME"/tools/*/; do
  [[ -f "$d/package.json" ]] || continue
  (cd "$d" && if [[ -f package-lock.json ]]; then npm ci --silent; else npm install --silent; fi) >/dev/null 2>&1 ||
    warn "npm install in $d"
done

step "4/8  Secrets: Android debug key, SSH, API-key env vars"
mkdir -p "$HOME/.android"
for f in debug.keystore adbkey adbkey.pub; do
  [[ -f "$SRC/secrets/$f" && ! -f "$HOME/.android/$f" ]] && install -m600 "$SRC/secrets/$f" "$HOME/.android/$f"
done
if [[ -d "$SRC/secrets/ssh" ]]; then
  mkdir -p "$HOME/.ssh" && cp -rn "$SRC/secrets/ssh/." "$HOME/.ssh/"
  chmod 700 "$HOME/.ssh"
  find "$HOME/.ssh" -type f -exec chmod 600 {} +
  find "$HOME/.ssh" -name '*.pub' -exec chmod 644 {} +
fi
ENVF="$HOME/.config/environment.d/50-from-windows.conf"
if [[ -f "$SRC/secrets/user-env-vars.txt" ]]; then
  mkdir -p "$(dirname "$ENVF")"; : > "$ENVF"; chmod 600 "$ENVF"
  SKIP='^(Path|PATH|PSModulePath|TEMP|TMP|OneDrive|OneDriveConsumer|ChocolateyLastPathUpdate|ANDROID_HOME|ANDROID_SDK_ROOT|CARGO_HOME|RUSTUP_HOME|GOPATH|C_INCLUDE_PATH|CPLUS_INCLUDE_PATH|HERMES_[A-Z_]*|WEBVIEW2_[A-Z_]*)$'
  while IFS='=' read -r k v; do
    k=${k#$'\ufeff'}; v=${v%$'\r'}
    if [[ -z "$k" || "$k" =~ $SKIP || "$v" =~ ^[A-Za-z]:\\ || "$v" == *\\* || "$v" == *\;* ]]; then
      echo "  skip  $k (Windows-only)"; continue
    fi
    printf '%s=%s\n' "$k" "$v" >> "$ENVF"; echo "  keep  $k"
  done < "$SRC/secrets/user-env-vars.txt"
fi

step "5/8  Claude Code: settings, skills, plugins, memory (moved to Linux paths)"
mkdir -p "$HOME/.claude"
rsync -rt "$PERMS" --ignore-existing \
  --exclude={daemon,daemon.lock,daemon.status.json,bridge-spawn,ide,shell-snapshots,session-env,chrome,telemetry,cache,downloads,paste-cache,jobs,sessions,security} \
  "$C/.claude/" "$HOME/.claude/"
if [[ -f "$C/.claude.json" ]]; then
  [[ -f "$HOME/.claude.json" ]] && cp "$HOME/.claude.json" "$HOME/.claude.json.before-restore"
  cp "$C/.claude.json" "$HOME/.claude.json"
fi
python3 "$KIT/lib/fix_windows_paths.py" "$HOME/.claude.json" "$HOME/.claude/settings.json" "$HOME"/.claude/plugins/*.json ||
  warn "Claude path rewrite"
python3 "$KIT/lib/rename_claude_projects.py" "$HOME/.claude/projects" || warn "Claude memory folder rename"

step "6/8  Other CLI configs (Codex, Gemini, Supabase, MCP auth, HyperFrames, opencode ...)"
for d in .codex .gemini .agents .hyperframes .colosseum-copilot .mcp-auth .supabase .pi .omniroute .kube \
         .claude-server-commander .nosus-preview .linkedin-toolkit .openclaw .grokbot .copilot .streamlit; do
  [[ -d "$C/$d" ]] && rsync -rt "$PERMS" --ignore-existing --exclude='.sandbox*' --exclude=.tmp --exclude=tmp "$C/$d/" "$HOME/$d/"
done
for d in opencode configstore colosseum cagent; do
  [[ -d "$C/.config/$d" ]] && rsync -rt "$PERMS" --ignore-existing "$C/.config/$d/" "$HOME/.config/$d/"
done
find "$HOME/.codex" "$HOME/.gemini" "$HOME/.config/opencode" -maxdepth 2 -name '*.json' -print0 2>/dev/null |
  xargs -0 -r python3 "$KIT/lib/fix_windows_paths.py" || true

step "7/8  VS Code settings, OBS scenes, fonts"
if [[ -d "$A/Code-User" ]]; then
  mkdir -p "$HOME/.config/Code/User"
  for f in settings.json keybindings.json; do
    [[ -f "$A/Code-User/$f" && ! -f "$HOME/.config/Code/User/$f" ]] && cp "$A/Code-User/$f" "$HOME/.config/Code/User/"
  done
  [[ -d "$A/Code-User/snippets" ]] && cp -rn "$A/Code-User/snippets" "$HOME/.config/Code/User/"
fi
if [[ -d "$A/obs-studio/basic" ]]; then
  mkdir -p "$HOME/.config/obs-studio" && cp -rn "$A/obs-studio/basic" "$HOME/.config/obs-studio/"
fi
mkdir -p "$HOME/.local/share/fonts"
cp -n "$SRC"/configs/fonts/* "$HOME/.local/share/fonts/" 2>/dev/null
fc-cache -f >/dev/null

step "8/8  Model cache"
if ((WITH_MODELS)); then
  "${RS[@]}" "$SRC/cache/huggingface/" "$HOME/.cache/huggingface/"
else
  echo "  Skipped. The ~98 GB Hugging Face cache stays on the SSD; re-run with --with-models to copy it."
fi

echo
if ((${#WARN[@]})); then
  printf '\033[1;33m%d item(s) need a look:\033[0m\n' "${#WARN[@]}"
  printf '  - %s\n' "${WARN[@]}"
else
  printf '\033[1;32mRestore complete.\033[0m\n'
fi
echo "Reboot (or log out and back in) so the environment variables apply, then sign in: see FINAL-STEPS.md."
