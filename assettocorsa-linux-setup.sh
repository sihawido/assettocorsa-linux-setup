#!/usr/bin/env bash
# =============================================================================
#  Assetto Corsa Linux Setup — Fully Automated Edition
#  Original: https://github.com/sihawido/assettocorsa-linux-setup
#  Improved: zero user input, progress bar, automatic Steam/wineprefix handling
# =============================================================================

set -euo pipefail
shopt -s expand_aliases

# ── Versions ──────────────────────────────────────────────────────────────────
GE_VERSION="9-20"
CSP_VERSION="0.2.11"
AC_APP_ID="244210"

# ── Colours & styles ──────────────────────────────────────────────────────────
BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
RESET="\033[0m"

# ── Progress bar ──────────────────────────────────────────────────────────────
TOTAL_STEPS=10
CURRENT_STEP=0
BAR_WIDTH=50
BAR_INIT=0   # set to 1 after first draw

progress_bar() {
  local label="$1"
  local pct=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
  local filled=$(( CURRENT_STEP * BAR_WIDTH / TOTAL_STEPS ))
  local empty=$(( BAR_WIDTH - filled ))
  local cols; cols=$(tput cols 2>/dev/null || echo 80)

  [[ $BAR_INIT -eq 1 ]] && printf "\033[2A"
  BAR_INIT=1

  printf "\r${BOLD}${CYAN}["
  printf "%0.s█" $(seq 1 "$filled")
  printf "%0.s░" $(seq 1 "$empty")
  printf "] %3d%%\033[0m\n" "$pct"

  local msg
  msg=$(printf "  %-${cols}s" "▶  $label")
  printf "${DIM}%s${RESET}\n" "${msg:0:$cols}"
}

step() {
  CURRENT_STEP=$(( CURRENT_STEP + 1 ))
  progress_bar "$1"
}

# ── Logging ───────────────────────────────────────────────────────────────────
log_info()    { printf "  ${GREEN}✔${RESET}  %s\n" "$*"; }
log_warn()    { printf "  ${YELLOW}⚠${RESET}  %s\n" "$*"; }
log_error()   { printf "  ${RED}✖${RESET}  %s\n" "$*" >&2; }
log_section() { printf "\n${BOLD}${CYAN}══ %s ══${RESET}\n" "$*"; }

# ── Error trap ────────────────────────────────────────────────────────────────
on_error() {
  local rc=$? line=${BASH_LINENO[0]} cmd="$BASH_COMMAND"
  printf "\n${BOLD}${RED}✖ Fatal error (exit %d) at line %d:${RESET}\n  %s\n" \
    "$rc" "$line" "$cmd" >&2
  printf "  ${YELLOW}Report at: https://github.com/sihawido/assettocorsa-linux-setup/issues${RESET}\n\n" >&2
  cleanup
  exit "$rc"
}
trap on_error ERR

# ── Run helper ────────────────────────────────────────────────────────────────
# Runs a command silently; on failure dumps output and exits.
run() {
  local out
  if ! out=$("$@" 2>&1); then
    log_error "Command failed: $*"
    printf "%s\n" "$out" >&2
    exit 1
  fi
}

# ── Temp dir ──────────────────────────────────────────────────────────────────
TMPDIR_AC=""
cleanup() {
  [[ -n "$TMPDIR_AC" && -d "$TMPDIR_AC" ]] && rm -rf "$TMPDIR_AC"
}
trap cleanup EXIT

make_tmpdir() {
  TMPDIR_AC="$(mktemp -d /tmp/ac-setup-XXXXXX)"
}

# ── Guards ────────────────────────────────────────────────────────────────────
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  log_error "Do not run this script as root."
  exit 1
fi

if ! bash -n "$0" 2>/dev/null; then
  log_error "Script has syntax errors — aborting."
  exit 1
fi

# =============================================================================
#  DISTRO & PACKAGE DETECTION
# =============================================================================
log_section "Detecting distribution"

# shellcheck source=/dev/null
source /etc/os-release
: "${ID:=}" "${NAME:=Unknown}" "${ID_LIKE:=undefined}"

declare -A PM_MAP=(
  [fedora]="dnf install -y"         [nobara]="dnf install -y"
  [ultramarine]="dnf install -y"    [debian]="apt-get install -y"
  [ubuntu]="apt-get install -y"     [linuxmint]="apt-get install -y"
  [pop]="apt-get install -y"        [zorin]="apt-get install -y"
  [arch]="pacman -S --noconfirm"    [endeavouros]="pacman -S --noconfirm"
  [steamos]="pacman -S --noconfirm" [cachyos]="pacman -S --noconfirm"
  [opensuse-tumbleweed]="zypper install -y"
  [slackware]="slackpkg install"    [salix]="slackpkg install"
  [gentoo]="emerge"                 [void]="xbps-install -Sy"
)

PM_CMD=""
for key in "$ID" $ID_LIKE; do
  [[ -n "${PM_MAP[$key]+_}" ]] && { PM_CMD="${PM_MAP[$key]}"; break; }
done

if [[ -z "$PM_CMD" ]]; then
  log_error "$NAME is not supported."
  printf "  Open an issue at https://github.com/sihawido/assettocorsa-linux-setup/issues\n"
  exit 1
fi
log_info "Detected: $NAME  (package manager: ${PM_CMD%% *})"

case "$ID" in
  slackware|salix) REQUIRED=("wget" "tar" "infozip" "glib2" "protontricks") ;;
  gentoo)          REQUIRED=("net-misc/wget" "app-arch/tar" "app-arch/unzip" "dev-libs/glib" "app-emulation/protontricks") ;;
  void)            REQUIRED=("wget" "tar" "unzip" "glib" "protontricks") ;;
  *)               REQUIRED=("wget" "tar" "unzip" "glib2" "protontricks") ;;
esac

MISSING=()
for pkg in "${REQUIRED[@]}"; do
  bin="$(basename "$pkg")"
  [[ "$bin" == "glib2" || "$bin" == "glib" ]] && bin="gio"
  [[ "$bin" == "infozip" ]] && bin="unzip"
  command -v "$bin" &>/dev/null || MISSING+=("$pkg")
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  log_error "Missing required packages: ${MISSING[*]}"
  printf "  Install with:  sudo %s %s\n" "$PM_CMD" "${MISSING[*]}"
  exit 1
fi
log_info "All required packages present"

# =============================================================================
#  STEAM DETECTION
# =============================================================================
log_section "Locating Steam"

NATIVE_STEAM_DIR="$HOME/.local/share/Steam"
if [[ ! -d "$NATIVE_STEAM_DIR" ]]; then
  _link="$(readlink "$HOME/.steam/root" 2>/dev/null || true)"
  [[ -n "$_link" ]] && NATIVE_STEAM_DIR="$_link"
fi
FLATPAK_STEAM_DIR="$HOME/.var/app/com.valvesoftware.Steam/data/Steam"

STEAM_INSTALL=""
if [[ -d "$NATIVE_STEAM_DIR" && -d "$FLATPAK_STEAM_DIR" ]]; then
  log_warn "Both native and Flatpak Steam found — using native."
  STEAM_INSTALL="native"
elif [[ -d "$NATIVE_STEAM_DIR" ]]; then
  STEAM_INSTALL="native"
elif [[ -d "$FLATPAK_STEAM_DIR" ]]; then
  STEAM_INSTALL="flatpak"
else
  log_error "No Steam installation found. Install Steam first."
  exit 1
fi

if [[ "$STEAM_INSTALL" == "native" ]]; then
  STEAM_DIR="$NATIVE_STEAM_DIR"
  STEAM_CMD="steam"
  APPLAUNCH_AC="steam -applaunch $AC_APP_ID"
  APPLAUNCH_AC_DESKTOP="steam -applaunch $AC_APP_ID %u"
else
  STEAM_DIR="$FLATPAK_STEAM_DIR"
  STEAM_CMD="flatpak run com.valvesoftware.Steam"
  APPLAUNCH_AC="flatpak run com.valvesoftware.Steam -applaunch $AC_APP_ID"
  APPLAUNCH_AC_DESKTOP="flatpak run com.valvesoftware.Steam -applaunch $AC_APP_ID %u"
fi
log_info "Steam ($STEAM_INSTALL) → $STEAM_DIR"

# Derived paths
AC_COMMON="$STEAM_DIR/steamapps/common/assettocorsa"
COMPAT_TOOLS_DIR="$STEAM_DIR/compatibilitytools.d"
STEAM_LIBRARY_VDF="$STEAM_DIR/steamapps/libraryfolders.vdf"
AC_DESKTOP="$HOME/.local/share/applications/Assetto Corsa.desktop"

# =============================================================================
#  LOCATE ASSETTO CORSA
# =============================================================================
log_section "Locating Assetto Corsa"

if [[ -f "$STEAM_LIBRARY_VDF" ]]; then
  while IFS= read -r lib_path; do
    candidate="${lib_path}/steamapps/common/assettocorsa"
    [[ -d "$candidate" ]] && { AC_COMMON="$candidate"; break; }
  done < <(grep '"path"' "$STEAM_LIBRARY_VDF" | awk -F'"' '{print $4}')
fi

if [[ ! -d "$AC_COMMON" ]]; then
  log_error "Assetto Corsa not found. Install it via Steam first, then re-run."
  exit 1
fi
log_info "Found AC at: $AC_COMMON"

STEAMAPPS="${AC_COMMON%"/common/assettocorsa"}"
AC_COMPATDATA="$STEAMAPPS/compatdata/$AC_APP_ID"

# =============================================================================
#  DISK HEALTH CHECK
# =============================================================================
log_section "Checking disk"

partition_info=( $(df -Tk "$AC_COMMON" | tail -n 1) )
fs_type="${partition_info[1]}"
avail="${partition_info[4]}"

[[ "$fs_type" == "ntfs" ]] && log_warn "AC is on NTFS — this will likely cause issues." || true
[[ "$avail" -lt 1000000 ]] && log_warn "Less than 1 GB free on AC partition." || true
log_info "Filesystem: $fs_type  |  Available: $(( avail / 1024 )) MB"

# =============================================================================
#  FIRST-RUN DETECTION
# =============================================================================
STEAM_CFG_IN_PFX="$AC_COMPATDATA/pfx/drive_c/Program Files (x86)/Steam/config"
FIRST_RUN=0
[[ ! -d "$STEAM_CFG_IN_PFX" ]] && FIRST_RUN=1

# =============================================================================
#  STEAM HELPERS
# =============================================================================

# Returns PIDs of any running Steam process.
steam_pids() {
  pgrep -x steam 2>/dev/null || pgrep -f "com.valvesoftware.Steam" 2>/dev/null || true
}

# Gracefully shut down Steam, force-kill after 15 s if needed.
kill_steam() {
  local pids
  pids="$(steam_pids)"
  if [[ -n "$pids" ]]; then
    log_warn "Closing Steam (needed to apply compatibility settings)…"
    if [[ "$STEAM_INSTALL" == "native" ]]; then
      steam -shutdown &>/dev/null || true
    else
      flatpak run com.valvesoftware.Steam -shutdown &>/dev/null || true
    fi
    local waited=0
    while [[ -n "$(steam_pids)" && $waited -lt 15 ]]; do
      sleep 1; waited=$(( waited + 1 ))
    done
    pids="$(steam_pids)"
    [[ -n "$pids" ]] && kill -9 $pids 2>/dev/null || true
    sleep 1
    log_info "Steam closed"
  fi
}

# Write GE-Proton compat tool into every user's localconfig.vdf so AC picks
# it up automatically on next Steam start — no GUI interaction needed.
set_proton_ge_in_config() {
  local tool_name="GE-Proton${GE_VERSION}"
  local userdata_dir="$STEAM_DIR/userdata"
  [[ ! -d "$userdata_dir" ]] && {
    log_warn "No userdata dir found — set ProtonGE via Steam UI after install."
    return
  }

  local changed=0
  for cfg in "$userdata_dir"/*/config/localconfig.vdf; do
    [[ -f "$cfg" ]] || continue

    if grep -q "\"$AC_APP_ID\"" "$cfg" 2>/dev/null; then
      if grep -A10 "\"$AC_APP_ID\"" "$cfg" | grep -q "CompatToolName"; then
        sed -i "/\"CompatToolName\"/s/\"[^\"]*\"$/\"$tool_name\"/" "$cfg"
      else
        sed -i "/\"$AC_APP_ID\"/{n;s/{/{\n\t\t\t\t\"CompatToolName\"\t\t\"$tool_name\"/}" "$cfg" 2>/dev/null || true
      fi
      log_info "Set CompatToolName → $tool_name in localconfig.vdf"
    else
      log_warn "App $AC_APP_ID not in localconfig.vdf — ProtonGE will be set after first AC launch registers the app."
    fi
    changed=1
  done

  if [[ $changed -eq 0 ]]; then
    log_warn "No localconfig.vdf found — set ProtonGE via Steam UI."
  fi
}

# Start Steam detached and wait up to 30 s for it to come up.
launch_steam() {
  log_info "Starting Steam…"
  nohup $STEAM_CMD &>/dev/null &
  disown

  local waited=0
  while [[ -z "$(steam_pids)" && $waited -lt 30 ]]; do
    sleep 1; waited=$(( waited + 1 ))
  done
  [[ -z "$(steam_pids)" ]] && { log_error "Steam failed to start."; exit 1; }

  # Extra time for Steam to finish initialising its IPC socket
  sleep 6
  log_info "Steam is running"
}

# Launch AC and block until the Wineprefix Steam config dir appears.
launch_ac_and_wait_for_prefix() {
  log_info "Launching Assetto Corsa to generate Wineprefix…"
  log_info "This can take 5–15 minutes — please do not close this terminal."

  $APPLAUNCH_AC &>/dev/null &
  disown

  local waited=0
  local max_wait=900   # 15-minute ceiling

  while [[ ! -d "$STEAM_CFG_IN_PFX" && $waited -lt $max_wait ]]; do
    sleep 5
    waited=$(( waited + 5 ))
    (( waited % 30 == 0 )) && printf "  ${DIM}  … waiting for Wineprefix (%ds elapsed)${RESET}\r" "$waited" || true
  done
  printf "\n"

  if [[ ! -d "$STEAM_CFG_IN_PFX" ]]; then
    log_error "Wineprefix was not created after ${max_wait}s."
    printf "  Launch AC manually once, exit it, then re-run this script.\n"
    exit 1
  fi

  log_info "Wineprefix generated — closing Assetto Corsa…"
  sleep 3

  local ac_pid
  ac_pid="$(pgrep 'AssettoCorsa.ex' 2>/dev/null || true)"
  [[ -n "$ac_pid" ]] && kill "$ac_pid" 2>/dev/null || true
  sleep 4
  log_info "Assetto Corsa closed"
}

# =============================================================================
#  BEGIN INSTALL — initialise progress bar
# =============================================================================
make_tmpdir
printf "\n\n"
CURRENT_STEP=0
progress_bar "Starting…"

# =============================================================================
#  STEP 1 — PROTON-GE
# =============================================================================
step "Installing GE-Proton${GE_VERSION}"

GE_DIR="$COMPAT_TOOLS_DIR/GE-Proton${GE_VERSION}"
GE_TAR="$TMPDIR_AC/GE-Proton${GE_VERSION}.tar.gz"
GE_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton${GE_VERSION}/GE-Proton${GE_VERSION}.tar.gz"

[[ -d "$GE_DIR" ]] && { log_info "Reinstalling GE-Proton${GE_VERSION}…"; run rm -rf "$GE_DIR"; }

log_info "Downloading GE-Proton${GE_VERSION}…"
run wget -q "$GE_URL" -O "$GE_TAR"
run mkdir -p "$COMPAT_TOOLS_DIR"
run tar -xzf "$GE_TAR" -C "$COMPAT_TOOLS_DIR"
log_info "GE-Proton${GE_VERSION} installed"

# =============================================================================
#  STEP 2 — CLOSE STEAM, WRITE PROTON CONFIG
# =============================================================================
step "Configuring Steam compatibility layer"

if [[ $FIRST_RUN -eq 1 ]]; then
  printf "\n"
  printf "  ${BOLD}${YELLOW}┌─────────────────────────────────────────────────────┐${RESET}\n"
  printf "  ${BOLD}${YELLOW}│  Steam will now be closed to apply Proton settings. │${RESET}\n"
  printf "  ${BOLD}${YELLOW}│  It will restart automatically in a few seconds.    │${RESET}\n"
  printf "  ${BOLD}${YELLOW}└─────────────────────────────────────────────────────┘${RESET}\n\n"
  sleep 3

  kill_steam
  set_proton_ge_in_config

  # ── STEP 3 — Launch Steam + AC to generate Wineprefix ──────────────────────
  step "Generating Wineprefix via first AC launch"
  launch_steam
  launch_ac_and_wait_for_prefix

else
  log_info "Wineprefix already exists — skipping first-run AC launch"
  step "Wineprefix generation (already done)"
fi

# =============================================================================
#  STEP 4 — STOP AC + CM SHORTCUT CLEANUP
# =============================================================================
step "Cleaning up start-menu shortcut"

ac_pid="$(pgrep 'AssettoCorsa.ex' 2>/dev/null || true)"
[[ -n "$ac_pid" ]] && { kill "$ac_pid" 2>/dev/null || true; sleep 2; }

LINK_FILE="$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Content Manager.lnk"
if [[ -f "$LINK_FILE" ]]; then
  run rm "$LINK_FILE"
  log_info "Removed CM start-menu shortcut (can cause crashes)"
else
  log_info "No CM shortcut present"
fi

# =============================================================================
#  STEP 5 — WINEPREFIX RESET (preserves configs)
# =============================================================================
step "Resetting Wineprefix (preserving configs)"

AC_CFG_DIR="$AC_COMPATDATA/pfx/drive_c/users/steamuser/Documents/Assetto Corsa"
CM_CFG_DIR="$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager"
BACKUP_DIR="$TMPDIR_AC/ac_configs"

if [[ -d "$AC_COMPATDATA/pfx" ]]; then
  run mkdir -p "$BACKUP_DIR"
  [[ -d "$AC_CFG_DIR" ]] && { log_info "Backing up AC configs…"; run cp -r "$AC_CFG_DIR" "$BACKUP_DIR/"; }
  [[ -d "$CM_CFG_DIR" ]] && { log_info "Backing up CM configs…"; run cp -r "$CM_CFG_DIR" "$BACKUP_DIR/"; }

  AC_EXE="$AC_COMMON/AssettoCorsa.exe"
  AC_ORIG="$AC_COMMON/AssettoCorsa_original.exe"
  if [[ -f "$AC_ORIG" ]]; then
    run rm -f "$AC_EXE"
    run mv "$AC_ORIG" "$AC_EXE"
    log_info "Restored original AssettoCorsa.exe"
  fi

  log_info "Deleting Wineprefix…"
  run rm -rf "$AC_COMPATDATA"

  if [[ -d "$BACKUP_DIR/Assetto Corsa" ]]; then
    run mkdir -p "$AC_COMPATDATA/pfx/drive_c/users/steamuser/Documents"
    run cp -r "$BACKUP_DIR/Assetto Corsa" "$AC_CFG_DIR"
    log_info "Restored AC configs"
  fi
  if [[ -d "$BACKUP_DIR/AcTools Content Manager" ]]; then
    run mkdir -p "$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local"
    run cp -r "$BACKUP_DIR/AcTools Content Manager" "$CM_CFG_DIR"
    log_info "Restored CM configs"
  fi
else
  log_info "No existing Wineprefix to reset"
fi

# =============================================================================
#  STEP 6 — CONTENT MANAGER
# =============================================================================
step "Installing Content Manager"

log_info "Downloading Content Manager…"
CM_ZIP="$TMPDIR_AC/cm_latest.zip"
run wget -q "https://acstuff.club/app/latest.zip" -O "$CM_ZIP"
log_info "Extracting…"
run unzip -q "$CM_ZIP" -d "$TMPDIR_AC/cm"
rm -f "$CM_ZIP"

AC_EXE="$AC_COMMON/AssettoCorsa.exe"
AC_ORIG="$AC_COMMON/AssettoCorsa_original.exe"
[[ -f "$AC_EXE" && ! -f "$AC_ORIG" ]] && run mv -n "$AC_EXE" "$AC_ORIG"
run cp -r "$TMPDIR_AC/cm/." "$AC_COMMON/"
run mv "$AC_COMMON/Content Manager.exe" "$AC_EXE"

log_info "Downloading CM fonts…"
FONTS_ZIP="$TMPDIR_AC/fonts.zip"
run wget -q "https://files.acstuff.ru/shared/T0Zj/fonts.zip" -O "$FONTS_ZIP"
run unzip -qo "$FONTS_ZIP" -d "$TMPDIR_AC/fonts"
rm -f "$FONTS_ZIP"
run cp -r "$TMPDIR_AC/fonts/system" "$AC_COMMON/content/fonts/"

log_info "Creating Steam login symlink…"
LINK_FROM="$STEAM_DIR/config/loginusers.vdf"
LINK_TO="$AC_COMPATDATA/pfx/drive_c/Program Files (x86)/Steam/config/loginusers.vdf"
run mkdir -p "$(dirname "$LINK_TO")"
run ln -sf "$LINK_FROM" "$LINK_TO"

if [[ -f "$AC_DESKTOP" ]]; then
  MIMELIST="$HOME/.config/mimeapps.list"
  if [[ -f "$MIMELIST" ]]; then
    sed -i "s|x-scheme-handler/acmanager=Assetto Corsa.desktop;||g" "$MIMELIST"
    sed -i "s|x-scheme-handler/acmanager=Assetto Corsa.desktop||g"  "$MIMELIST"
    sed -i '$!N; /^\(.*\)\n\1$/!P; D' "$MIMELIST"
  fi
  run sed -i "s|steam steam://rungameid/$AC_APP_ID|$APPLAUNCH_AC_DESKTOP|g" "$AC_DESKTOP"
  gio mime x-scheme-handler/acmanager "Assetto Corsa.desktop" &>/dev/null || true
  log_info "Registered acmanager:// URI scheme"
else
  log_warn "No .desktop shortcut — acmanager:// links won't work"
fi

log_info "Content Manager installed"
printf "  ${BOLD}Tip:${RESET} On first CM launch set AC root to ${BOLD}Z:${AC_COMMON}${RESET}\n"

# =============================================================================
#  STEP 7 — CUSTOM SHADERS PATCH
# =============================================================================
step "Installing Custom Shaders Patch v${CSP_VERSION}"

USER_REG="$AC_COMPATDATA/pfx/user.reg"
if [[ -f "$USER_REG" ]] && ! grep -q '"dwrite"' "$USER_REG"; then
  log_info "Adding dwrite DLL override…"
  run sed -i '/\"*d3d11"="native"/a \"dwrite"="native,builtin\"' "$USER_REG"
else
  log_info "dwrite DLL override already present"
fi

log_info "Downloading CSP…"
CSP_DL="$TMPDIR_AC/csp.zip"
run wget -q "https://acstuff.club/patch/?get=${CSP_VERSION}" -O "$CSP_DL"
log_info "Extracting CSP…"
run unzip -qo "$CSP_DL" -d "$TMPDIR_AC/csp"
rm -f "$CSP_DL"
run cp -r "$TMPDIR_AC/csp/." "$AC_COMMON"

log_info "Installing corefonts via protontricks (may take a while)…"
protontricks "$AC_APP_ID" corefonts &>/dev/null || log_warn "protontricks corefonts exited non-zero (usually harmless — continuing)"
log_info "CSP v${CSP_VERSION} installed"

# =============================================================================
#  STEP 8 — CSP INPUT MAPPING FIX
# =============================================================================
step "Applying CSP input mapping fix"

CSP_ALT_MAP="$AC_COMMON/extension/config/data_alt_mapping.ini"
if [[ -f "$CSP_ALT_MAP" ]] && grep -q '\[NAMES_WINE\]' "$CSP_ALT_MAP"; then
  run sed -i '/\[NAMES_WINE\]/,$d' "$CSP_ALT_MAP"
  log_info "Removed [NAMES_WINE] section from data_alt_mapping.ini"
else
  log_info "No input mapping fix needed"
fi

# =============================================================================
#  STEP 9 — DXVK
# =============================================================================
step "Installing DXVK"

log_info "Running protontricks dxvk…"
protontricks --no-background-wineserver "$AC_APP_ID" dxvk &>/dev/null || log_warn "protontricks dxvk exited non-zero (usually harmless — continuing)"
log_info "DXVK installed"

# =============================================================================
#  STEP 10 — RELAUNCH STEAM AND OPEN ASSETTO CORSA
# =============================================================================
step "Launching Assetto Corsa"

# Restart Steam cleanly so all config changes are loaded
kill_steam
sleep 2
launch_steam

log_info "Launching Assetto Corsa (Content Manager)…"
$APPLAUNCH_AC &>/dev/null &
disown

# =============================================================================
#  ALL DONE
# =============================================================================
printf "\n${BOLD}${GREEN}╔══════════════════════════════════════════╗${RESET}\n"
printf "${BOLD}${GREEN}║  ✔  Assetto Corsa setup complete!        ║${RESET}\n"
printf "${BOLD}${GREEN}╚══════════════════════════════════════════╝${RESET}\n\n"
printf "  ${BOLD}First Content Manager launch:${RESET}\n"
printf "  • Set AC root folder to ${BOLD}Z:${AC_COMMON}${RESET}\n\n"
