#! /usr/bin/env bash

# Checks for unbound variables
set -u

# Checking for errors before executing
bash -n "$0"
status="$?"
if [[ "$status" != "0" ]]; then
  exit "$status"
fi

# Enables usage of aliases inside the script
shopt -s expand_aliases

# Preventing from running as root
if [[ $USER == "root" ]]; then
  echo "Please do not run as root."
  exit 1
fi

# Constants
GE_VERSION="9-20"
CSP_VERSION="0.2.11"
REPO_LINK="https://github.com/sihawido/assettocorsa-linux-setup"

# Defining text styles for readablity
bold=$(echo -e "\033[1m")
warning=$(echo -e "\033[33m")
error=$(echo -e "${bold}\033[31m")
reset=$(echo -e "\033[0m")

function hyperlink {
  local text="$1"
  local link="$2"
  printf "\e]8;;${link}\e\\${text}\e]8;;\e\\"
}

# Provides a yes/no prompt.
function ask {
  while true; do
    read -rp "$* [y/n]: " yn
    case $yn in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
    esac
  done
}

# Executes given command, exits with an error if the command fails.
function run {
  output="$("$@" 2>&1)"
  status=$?
  if [[ $status != "0" ]]; then
    line=($(caller))
    echo "
${error}Encountered an error while running '$@' at line $line:${reset}
$output

${warning}If this is an issue, please report it on Github.${reset}
"
    exit "$status"
  fi
}

# Returns the executable for given string, supports aliases.
function getbin {
  local cmd="$1"
  if ! declare -p BASH_ALIASES > /dev/null; then
    declare -A BASH_ALIASES=()
  fi
  local cmd_alias="${BASH_ALIASES[$1]-}"
  local cmd_which="$(which $cmd 2> /dev/null)"
  local cmd_which_status="$?"
  if [[ "$cmd_alias" != "" ]]; then
    echo "$cmd_alias"
  elif [[ "$cmd_which_status" == "0" ]] && [[ "$cmd_which" != ""  ]]; then
    echo "$cmd_which"
  else
    return 1
  fi
}

# Retruns 0 if the given variable is set, otherwise returns 1.
function is-set {
  varname="$1"
  if [[ -z "${!varname+x}" ]]; then
    return 1
  fi
  return 0
}

function get-os-release-var {
  local name="$1"
  run bash -c "source /etc/os-release; echo \"\$$name\""
}

function check-deps {
  # Defining dependencies
  local deps=("wget" "tar" "unzip" "glib2" "winetricks" "protontricks")
  # Defining supported distros
  local supported_debian=("debian" "ubuntu" "linuxmint" "pop" "zorin" "neon")
  local supported_fedora=("fedora" "nobara" "ultramarine")
  local supported_arch=("arch" "endeavouros" "steamos" "cachyos" "artix")
  local supported_opensuse=("opensuse-tumbleweed")
  local supported_slackware=("slackware" "salix")
  local supported_gentoo=("gentoo")
  local supported_void=("void")
  # Getting info about user's distro
  local distro_id="$(get-os-release-var ID)"
  local distro_name="$(get-os-release-var NAME)"
  local distro_id_like="$(get-os-release-var ID_LIKE)"
  if [[ "$distro_id_like" != "" ]]; then
    distro_id="$distro_id_like"
  fi
  # Matching user's distro to supported distros
  if [[ ${supported_fedora[*]} =~ "$distro_id" ]]; then
    pm_install="dnf install"
  elif [[ ${supported_debian[*]} =~ "$distro_id" ]]; then
    pm_install="apt install"
  elif [[ ${supported_arch[*]} =~ "$distro_id" ]]; then
    pm_install="pacman -S"
  elif [[ ${supported_opensuse[*]} =~ "$distro_id" ]]; then
    pm_install="zypper install"
  elif [[ ${supported_slackware[*]} =~ "$distro_id" ]]; then
    pm_install="slackpkg install or sboinstall"
    deps=("wget" "tar" "infozip" "glib2" "protontricks")
  elif [[ ${supported_gentoo[*]} =~ "$distro_id" ]]; then
    pm_install="emerge"
    deps=(
      "net-misc/wget"
      "app-arch/tar"
      "app-arch/unzip"
      "dev-libs/glib2"
      "app-emulation/protontricks"
    )
  elif [[ ${supported_void[*]} =~ "$distro_id" ]]; then
    deps=("wget" "tar" "unzip" "glib" "protontricks")
    pm_install="xbps-install -S"
  else
    echo "\
$NAME is not currently supported.
You can open an issue on $(hyperlink "Github" "$REPO_LINK/issues") \
with your system details to add it as supported."
    exit 1
  fi
  # Checking if dependencies are installed
  for package in "${deps[@]}"; do
    bin="$(basename "$package")"
    if [[ "$bin" == "glib2" ]] || [[ "$bin" == "glib" ]]; then
      bin="gio"
    elif [[ "$bin" == "infozip" ]]; then
      bin="unzip"
    fi
    if ! getbin "$bin" > /dev/null; then
      install_command="${bold}sudo $pm_install $package${reset}"
      echo "$bin is not installed, run $install_command to install."
      exit 1
    fi
  done
}
check-deps

# Checking temp dir
if [[ -e "temp/" ]]; then
  echo "'temp/' directory found inside current directory."
  echo "It needs to be removed or renamed for this script to work."
  if ask "Move 'temp/' to trash?"; then
    run gio trash "temp/"
  else
    exit 1
  fi
fi

# Getting steam installation path
NATIVE_STEAM_DIR="$HOME/.local/share/Steam"
if [[ ! -d "$NATIVE_STEAM_DIR" ]]; then
  out="$(readlink "$HOME/.steam/root")"
  status="$?"
  if [[ "$status" == "0" ]]; then
    NATIVE_STEAM_DIR="$out"
  fi
fi

FLATPAK_STEAM_DIR="$HOME/.var/app/com.valvesoftware.Steam/data/Steam"

# Support for Snap installation of Steam
# User data in snap is generally in 'common', but we check the requested 'current' symlink as well
SNAP_STEAM_DIR="$HOME/snap/steam/common/.local/share/Steam"
if [[ ! -d "$SNAP_STEAM_DIR" ]] && [[ -d "$HOME/snap/steam/current/.local/share/Steam" ]]; then
  SNAP_STEAM_DIR="$HOME/snap/steam/current/.local/share/Steam"
fi

STEAM_INSTALL="?"
AVAILABLE_INSTALLS=()

[[ -d "$NATIVE_STEAM_DIR" ]] && AVAILABLE_INSTALLS+=("Native")
[[ -d "$FLATPAK_STEAM_DIR" ]] && AVAILABLE_INSTALLS+=("Flatpak")
[[ -d "$SNAP_STEAM_DIR" ]] && AVAILABLE_INSTALLS+=("Snap")

if [[ ${#AVAILABLE_INSTALLS[@]} -gt 1 ]]; then
  echo "Multiple Steam installations found."
  PS3="Select which installation of Steam to use: "
  select installation_method in "${AVAILABLE_INSTALLS[@]}"; do
    # Converting to lowercase and getting the first word
    installation_method="$(echo ${installation_method,,} | awk '{print $1;}')"
    STEAM_INSTALL="$installation_method"
    break
  done
elif [[ ${#AVAILABLE_INSTALLS[@]} -eq 1 ]]; then
  echo "${AVAILABLE_INSTALLS[0]} installation of Steam found."
  STEAM_INSTALL="$(echo ${AVAILABLE_INSTALLS[0],,} | awk '{print $1;}')"
else
  echo "Steam installation not found."
  exit 1
fi

if [[ "$STEAM_INSTALL" == "native" ]]; then
  STEAM_DIR="$NATIVE_STEAM_DIR"
  APPLAUNCH_AC="steam -applaunch 244210 %u"
elif [[ "$STEAM_INSTALL" == "flatpak" ]]; then
  STEAM_DIR="$FLATPAK_STEAM_DIR"
  APPLAUNCH_AC="flatpak run com.valvesoftware.Steam -applaunch 244210 %u"
elif [[ "$STEAM_INSTALL" == "snap" ]]; then
  STEAM_DIR="$SNAP_STEAM_DIR"
  APPLAUNCH_AC="snap run steam -applaunch 244210 %u"
else
  echo "Invalid STEAM_INSTALL '$STEAM_INSTALL'"
  exit 1
fi

# Setting paths dependent on STEAM_DIR
AC_COMMON="$STEAM_DIR/steamapps/common/assettocorsa"
COMPAT_TOOLS_DIR="$STEAM_DIR/compatibilitytools.d"
STEAM_LIBRARY_VDF="$STEAM_DIR/steamapps/libraryfolders.vdf"
# Setting universal paths
AC_DESKTOP="$HOME/.local/share/applications/Assetto Corsa.desktop"

# Getting path to Assetto Corsa
function ac-path-prompt {
  echo "Enter path to ${bold}steamapps/common/assettocorsa${reset}:"
  while :; do
    read -ei "$PWD/" path &&
    # Converting '~/directory/' to '/home/user/directory'
    local path="$(echo "${path%"/"}" | sed "s|\~\/|$HOME\/|g")"
    if [[ -d "$path" ]] && [[ $(basename "$path") == "assettocorsa" ]]; then
      AC_COMMON="$path"
      break
    else
      echo "Invalid path."
    fi
    history -s "$path"
  done
}
# Getting path from libraryfolders.vdf config
if [ -f "$STEAM_LIBRARY_VDF" ]; then
  # Getting from Steam library paths
  path_list=$(grep 'path' "$STEAM_LIBRARY_VDF" | awk -F'"' '{print $4}')
  for path in $path_list; do
    path="${path}/steamapps/common/assettocorsa"
    if [[ -d "$path" ]]; then
      AC_COMMON="$path"
      break
    fi
  done
else
  echo "No steam library file found at: '$STEAM_LIBRARY_VDF'."
fi

if [[ -d "$AC_COMMON" ]]; then
  echo "Found ${bold}$AC_COMMON${reset}"
  if ! ask "Is that the right installation?"; then
    ac-path-prompt
  fi
else
  echo "Could not find Assetto Corsa in the default path."
  ac-path-prompt
fi

# Setting paths dependent on path to Assetto Corsa
STEAMAPPS="${AC_COMMON%"/common/assettocorsa"}"
AC_COMPATDATA="$STEAMAPPS/compatdata/244210"

# Checking for potential disk issues
function check-disk {
  local dev_path="$(findmnt -no SOURCE --target "$AC_COMPATDATA")"
  local filesystem_type="$(lsblk -no fstype "$dev_path")"
  if [[ "$filesystem_type" == "ntfs" ]]; then
    echo "${warning}Assetto Corsa is installed on a NTFS partition. This will cause issues.${reset}"
  fi
  local available_space=($(df -P "$AC_COMPATDATA" | tail -1))
  available_space="${available_space[3]}"
  if (( available_space < 1000000 )); then
    echo "${warning}The disk that Assetto Corsa is installed on has less than 1GB of free space.${reset}"
  fi
}
check-disk

# Checking if Assetto Corsa is running
ac_pid="$(pgrep "AssettoCorsa.ex")"
if [[ "$ac_pid" != "" ]]; then
  if ask "Assetto Corsa is running. Stop Assetto Corsa to proceed?"; then
    kill "$ac_pid"
  else
    exit 1
  fi
fi

# Optional steps:

# Asking whether to delete start menu shortcut which might cause content manager to crash
function check-start-menu-shortcut {
  local link_file="$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Content Manager.lnk"
  if [[ -f "$link_file" ]]; then
    echo "Start Menu Shortcut for Content Manager found. This might be causing crashes on start-up."
    if ask "Delete the shortcut?"; then
      run rm "$link_file"
    fi
  else
    return 1
  fi
}

# Checking if ProtonGE is installed
function check-proton {
  local ProtonGE="ProtonGE $GE_VERSION"
  printf "$ProtonGE is the latest tested version that works."
  echo " Using any other version may not work."
  if [[ -d "$COMPAT_TOOLS_DIR/GE-Proton$GE_VERSION" ]]; then
    local string="Reinstall $ProtonGE?"
  else
    local string="Install $ProtonGE?"
  fi
  if ask "$string"; then
    install-proton
  fi
}

function install-proton {
  local ge_repo_link="https://github.com/GloriousEggroll/proton-ge-custom"
  local ge_download_link="$ge_repo_link/releases/download"
  local ge_download_link="$ge_download_link/GE-Proton$GE_VERSION/GE-Proton$GE_VERSION.tar.gz"
  # Downloading
  echo "Downloading $ProtonGE..."
  run wget -q "$ge_download_link" -P "temp/"
  # Removing previous install
  if [[ -d "$COMPAT_TOOLS_DIR/GE-Proton$GE_VERSION" ]]; then
    echo "Removing previous installation of $ProtonGE..."
    run rm -rf "$COMPAT_TOOLS_DIR/GE-Proton$GE_VERSION"
  fi
  # Extracting
  echo "Installing $ProtonGE..."
  run mkdir -p "$COMPAT_TOOLS_DIR"
  run tar -xzf "temp/GE-Proton$GE_VERSION.tar.gz" -C "temp/"
  run cp -rfa "temp/GE-Proton$GE_VERSION" "$COMPAT_TOOLS_DIR"
  run rm -rf "temp/"
  echo "${bold}To enable ProtonGE for Assetto Corsa:
 1. Restart Steam
 2. Go to Assetto Corsa > Properties > Compatability
 3. Turn on 'Force the use of a specific Steam Play compatability tool'
 4. From the drop-down, select $ProtonGE.${reset}"
}

# Asking whether to delete wineprefix
function check-wineprefix {
  if [ -d "$AC_COMPATDATA/pfx" ]; then
    echo "Found existing Wineprefix. Deleting it may solve AC not launching/crashing."
    if ask "Delete existing Wineprefix and Content Manager? (preserves configs, presets and mods)"; then
      delete-wineprefix
    fi
  else
    return 1
  fi
}

function delete-wineprefix {
  # asking whether to get rid of previous configs
  if [[ -d "ac_configs/" ]]; then
    echo "Found previous save of AC and CM configs in ${bold}$PWD/ac_configs/${reset}."
    if ask "Delete previous saves to proceed?"; then
      run rm -r "ac_configs/"
    else
      exit 2
    fi
  fi
  # Saving configs
  local ac_config_dir="$AC_COMPATDATA/pfx/drive_c/users/steamuser/Documents/Assetto Corsa"
  local cm_config_dir="$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager"
  run mkdir "ac_configs/"
  if [[ -d "$ac_config_dir" ]]; then
    echo "Saving AC configs and presets..."
    run cp -r "$ac_config_dir" "ac_configs/"
  fi
  if [[ -d "$cm_config_dir" ]]; then
    echo "Saving CM configs and presets..."
    run cp -r "$cm_config_dir" "ac_configs/"
  fi
  # Deleting Wineprefix
  if [[ -d "$AC_COMPATDATA/pfx" ]]; then
    echo "Deleting Wineprefix..."
    run rm -rf "$AC_COMPATDATA"
  fi
  # Copying back the saved configs
  local -i copied=0
  if [[ -d "ac_configs/Assetto Corsa" ]]; then
    echo "Copying saved AC configs and presets..."
    run mkdir -p "$AC_COMPATDATA/pfx/drive_c/users/steamuser/Documents"
    run cp -r "ac_configs/Assetto Corsa" "$ac_config_dir"
    copied+=1
  fi
  if [[ -d "ac_configs/AcTools Content Manager" ]]; then
    echo "Copying saved CM configs and presets..."
    run mkdir -p "$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local"
    run cp -r "ac_configs/AcTools Content Manager" "$cm_config_dir"
    copied+=1
  fi
  # Deleting the saved configs
  if [[ -d "ac_configs/" ]] && (( $copied == 2 )); then
    run rm -r "ac_configs/"
  fi
  # Deleting Content Manager
  local ac_exe="$AC_COMMON/AssettoCorsa.exe"
  local ac_original_exe="$AC_COMMON/AssettoCorsa_original.exe"
  if [[ -f "$ac_original_exe" ]]; then
    echo "Deleting Content Manager..."
    run rm "$ac_exe"
    run mv "$ac_original_exe" "$ac_exe"
  fi
}

# Checking if Content Manager is installed
function check-content-manager {
  if [[ -f "$AC_COMMON/AssettoCorsa_original.exe" ]]; then
    local string="Reinstall Content Manager?"
  else
    local string="Install Content Manager?"
  fi
  if ask "$string"; then
    install-content-manager
  fi
}

function install-content-manager {
  echo "Installing Content Manager..."
  run wget -q "https://acstuff.club/app/latest.zip" -P "temp/"
  run unzip -q "temp/latest.zip" -d "temp/"
  if [[ -e "$AC_COMMON/AssettoCorsa.exe" ]] \
     && [[ ! -e "$AC_COMMON/AssettoCorsa_original.exe" ]]
  then
    run mv -n "$AC_COMMON/AssettoCorsa.exe" "$AC_COMMON/AssettoCorsa_original.exe"
  fi
  run rm "temp/latest.zip"
  run cp -r "temp/"* "$AC_COMMON/"
  run rm -rf "temp/"
  run mv "$AC_COMMON/Content Manager.exe" "$AC_COMMON/AssettoCorsa.exe"

  echo "Installing fonts required for Content Manager..."
  run wget -q "https://files.acstuff.ru/shared/T0Zj/fonts.zip" -P "temp/"
  run unzip -qo "temp/fonts.zip" -d "temp/"
  run rm "temp/fonts.zip"
  run cp -r "temp/system" "$AC_COMMON/content/fonts/"
  run rm -rf "temp/"

  echo "Creating symlink..."
  local link_from="$STEAM_DIR/config/loginusers.vdf"
  local link_to="$AC_COMPATDATA/pfx/drive_c/Program Files (x86)/Steam/config/loginusers.vdf"
  run ln -sf "$link_from" "$link_to"

  if [[ -f "$AC_DESKTOP" ]]; then
    local mimelist="$HOME/.config/mimeapps.list"
    # Cleaning up previous modifications to mimeapps.list
    if [[ -f "$mimelist" ]]; then
      run sed "s|x-scheme-handler/acmanager=Assetto Corsa.desktop;||g" -i "$mimelist"
      run sed "s|x-scheme-handler/acmanager=Assetto Corsa.desktop||g" -i "$mimelist"
      run sed '$!N; /^\(.*\)\n\1$/!P; D' -i "$mimelist"
    fi
    echo "Adding ability to open acmanager links..."
    run sed "s|steam steam://rungameid/244210|$APPLAUNCH_AC|g" -i "$AC_DESKTOP"
    run gio mime x-scheme-handler/acmanager "Assetto Corsa.desktop" 1>& /dev/null
    echo "Opening ${bold}acmanager://${reset} links will only work if Content Manager/Assetto Corsa is not open already."
  else
    echo "Assetto Corsa does not have a .desktop shortcut, URI links to CM will not work."
  fi
  echo "When starting Content Manager, set the root Assetto Corsa folder to ${bold}Z:$AC_COMMON${reset}"
}

function check-csp {
  local current_CSP_version=""
  local data_manifest_file="$AC_COMMON/extension/config/data_manifest.ini"
  if [[ -f "$data_manifest_file" ]]; then
    current_CSP_version="$(cat "$data_manifest_file" | grep "SHADERS_PATCH=" | sed 's/SHADERS_PATCH=//g')"
  fi

  if [[ $current_CSP_version == "$CSP_VERSION" ]]; then
    local string="Reinstall CSP v$CSP_VERSION?"
  else
    local string="Install CSP (Custom Shaders Patch) v$CSP_VERSION?"
  fi
  if ask "$string"; then
    install-csp
  fi
}

function install-csp {
  local reg_dwrite="$(echo "$(cat "$AC_COMPATDATA/pfx/user.reg")" | grep "dwrite")"
  if [[ $reg_dwrite == "" ]]; then
    echo "Adding DLL override 'dwrite'..."
    run sed '/\"\*d3d11"="native\"/a \"dwrite"="native,builtin\"' "$AC_COMPATDATA/pfx/user.reg" -i
  else
    echo "DLL override 'dwrite' already exists."
  fi

  echo "Downloading CSP..."
  run wget -q "https://acstuff.club/patch/?get=$CSP_VERSION" -P "temp/"
  echo "Installing CSP..."

  # For some reason the downloaded file name is weird so we have to rename it
  run mv -f "temp/index.html?get=$CSP_VERSION" "temp/lights-patch-v$CSP_VERSION.zip"
  run unzip -qo "temp/lights-patch-v$CSP_VERSION.zip" -d "temp/"
  run rm "temp/lights-patch-v$CSP_VERSION.zip"
  run cp -r "temp/." "$AC_COMMON"
  run rm -rf "temp/"

  echo "Installing fonts required for CSP... (this might take a while)"
  # Add the STEAM_DIR environment variable to the protontricks command so that it can find the Steam installation path.
  export STEAM_DIR="$STEAM_DIR"
  run protontricks 244210 corefonts
}

function check-csp-config {
  local cfg_file="$AC_COMMON/extension/config/data_alt_mapping.ini"
  if [[ ! -f "$cfg_file" ]]; then
    return
  fi
  local cfg_contents="$(cat "$cfg_file")"
  local NAMES_WINE_section="$(echo "$cfg_contents" | grep "\[NAMES_WINE\]")"
  if [[ "$NAMES_WINE_section" == "" ]]; then
    return
  fi
  echo "Resolve some input mapping issues?"
  if ask "(Only do this step if you have issues mapping your inputs)"; then
    fix-csp-config
  fi
}

function fix-csp-config {
  run sed '/\[NAMES_WINE\]/,$d' "$cfg_file" -i
}

function check-dxvk {
  if ask "Install DXVK? (can improve performance in some cases)"; then
    install-dxvk
  fi
}
function install-dxvk {
  echo "Installing DXVK..."
  run protontricks --no-background-wineserver 244210 dxvk
}

function check-generated-files {
  if [ ! -d "$AC_COMPATDATA/pfx/drive_c/Program Files (x86)/Steam/config" ]; then
    echo "\
${bold}Before proceeding, please do the following to generate the wineprefix:
 1. Launch Assetto Corsa with Proton-GE $GE_VERSION
 2. Wait until Assetto Corsa launches (it takes a while)
 3. Exit Assetto Corsa
Then start the script again, and skip the step relating to deleting the wineprefix.${reset}"
    exit 1
  else
    return 1
  fi
}

OPTIONAL_STEPS=(
  check-start-menu-shortcut
  check-proton
  check-wineprefix
  check-generated-files
  check-content-manager
  check-csp
  check-csp-config
  check-dxvk
)
echo
for func in "${OPTIONAL_STEPS[@]}"; do
  $func && echo
done
echo "${bold}All done!${reset}"
