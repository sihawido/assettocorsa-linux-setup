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

# Versions
GE_version="9-20"
CSP_version="0.2.11"
SIMHUB_VERSION="9.11.13"

# Defining text styles for readablity
bold=$(echo -e "\033[1m")
warning=$(echo -e "\033[33m")
error=$(echo -e "${bold}\033[31m")
reset=$(echo -e "\033[0m")

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
function subprocess {
  output="$("$@" 2>&1)"
  status=$?
  if [[ $status != "0" ]]; then
    line=($(caller))
    echo "
${error}Encountered an error while running '$@' at line $line:${reset}
$output

${warning}If this is an issue, please report it on Github.${reset}
"
    exit 1
  fi
}

# Returns the executable for given string, supports aliases.
function get-exec {
  local cmd="$1"
  if ! declare -p BASH_ALIASES >/dev/null; then
    declare -A BASH_ALIASES=()
  fi
  local cmd_alias="${BASH_ALIASES[$1]-}"
  local cmd_which="$(which $cmd 2>/dev/null)"
  local cmd_which_status="$?"
  if [[ "$cmd_alias" != "" ]]; then
    echo "$cmd_alias"
  elif [[ "$cmd_which_status" == "0" ]] && [[ "$cmd_which" != "" ]]; then
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

# Required packages
required_packages=("wget" "tar" "unzip" "glib2" "protontricks")

# Supported distros
supported_apt=("debian" "ubuntu" "linuxmint" "pop" "zorin")
supported_dnf=("fedora" "nobara" "ultramarine")
supported_arch=("arch" "endeavouros" "steamos" "cachyos" "artix")
supported_opensuse=("opensuse-tumbleweed")
supported_slackware=("slackware" "salix")
supported_gentoo=("gentoo")
supported_void=("void")

# Checking distro compatability
source "/etc/os-release"
subprocess is-set "ID"
subprocess is-set "NAME"
if ! is-set "ID_LIKE"; then
  ID_LIKE="undefined"
fi
if [[ ${supported_dnf[*]} =~ "$ID" ]] || [[ ${supported_dnf[*]} =~ "$ID_LIKE" ]]; then
  pm_install="dnf install"
elif [[ ${supported_apt[*]} =~ "$ID" ]] || [[ ${supported_apt[*]} =~ "$ID_LIKE" ]]; then
  pm_install="apt install"
elif [[ ${supported_arch[*]} =~ "$ID" ]] || [[ ${supported_arch[*]} =~ "$ID_LIKE" ]]; then
  pm_install="pacman -S"
elif [[ ${supported_opensuse[*]} =~ "$ID" ]] || [[ ${supported_opensuse[*]} =~ "$ID_LIKE" ]]; then
  pm_install="zypper install"
elif [[ ${supported_slackware[*]} =~ "$ID" ]] || [[ ${supported_slackware[*]} =~ "$ID_LIKE" ]]; then
  pm_install="slackpkg install or sboinstall"
  required_packages=("wget" "tar" "infozip" "glib2" "protontricks")
elif [[ ${supported_gentoo[*]} =~ "$ID" ]] || [[ ${supported_gentoo[*]} =~ "$ID_LIKE" ]]; then
  required_packages=("net-misc/wget" "app-arch/tar" "app-arch/unzip" "dev-libs/glib2" "app-emulation/protontricks")
  pm_install="emerge"
elif [[ ${supported_void[*]} =~ "$ID" ]] || [[ ${supported_void[*]} =~ "$ID_LIKE" ]]; then
  required_packages=("wget" "tar" "unzip" "glib" "protontricks")
  pm_install="xbps-install -S"
else
  echo "\
$NAME is not currently supported.
You can open an issue on Github (https://github.com/sihawido/assettocorsa-linux-setup/issues) with your system details to add it as supported."
  exit 1
fi

# Checking if required packages are installed
for package in "${required_packages[@]}"; do
  bin="$(basename "$package")"
  if [[ "$bin" == "glib2" ]] || [[ "$bin" == "glib" ]]; then
    bin="gio"
  elif [[ "$bin" == "infozip" ]]; then
    bin="unzip"
  fi
  if ! get-exec "$bin" >/dev/null; then
    echo "$bin is not installed, run ${bold}sudo $pm_install $package${reset} to install."
    exit 1
  fi
done

# Checking temp dir
if [[ -e "temp/" ]]; then
  echo "'temp/' directory found inside current directory. It needs to be removed or renamed for this script to work."
  if ask "Move 'temp/' to trash?"; then
    subprocess gio trash "temp/"
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
STEAM_INSTALL="?"
if [[ -d "$NATIVE_STEAM_DIR" ]] && [[ -d "$FLATPAK_STEAM_DIR" ]]; then
  echo "Steam is installed both as a native package and Flatpak."
  PS3="Select which installation of Steam to use: "
  select installation_method in "Native" "Flatpak"; do
    # Converting to lowercase and getting the first word
    installation_method="$(echo ${installation_method,,} | awk '{print $1;}')"
    STEAM_INSTALL="$installation_method"
    break
  done
elif [[ -d "$NATIVE_STEAM_DIR" ]]; then
  echo "Native installation of Steam found."
  STEAM_INSTALL="native"
elif [[ -d "$FLATPAK_STEAM_DIR" ]]; then
  echo "Flatpak installation of Steam found."
  STEAM_INSTALL="flatpak"
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
SIMHUB_DIR="$AC_COMPATDATA/pfx/drive_c/Program Files (x86)/SimHub"

# Checking for potential disk issues
function check-disk {
  local dev_path="$(findmnt -no SOURCE --target "$AC_COMPATDATA")"
  local filesystem_type="$(lsblk -no fstype "$dev_path")"
  if [[ "$filesystem_type" == "ntfs" ]]; then
    echo "${warning}Assetto Corsa is installed on a NTFS partition. This will cause issues.${reset}"
  fi
  local available_space=($(df -P "$AC_COMPATDATA" | tail -1))
  available_space="${available_space[3]}"
  if ((available_space < 1000000)); then
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
      subprocess rm "$link_file"
    fi
  else
    return 1
  fi
}
# Checking if ProtonGE is installed
function check-proton {
  local ProtonGE="ProtonGE $GE_version"
  echo "$ProtonGE is the latest tested version that works. Using any other version may not work."
  if [[ -d "$COMPAT_TOOLS_DIR/GE-Proton$GE_version" ]]; then
    local string="Reinstall $ProtonGE?"
  else
    local string="Install $ProtonGE?"
  fi
  if ask "$string"; then
    install-proton
  fi
}
function install-proton {
  # Downloading
  echo "Downloading $ProtonGE..."
  subprocess wget -q "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton$GE_version/GE-Proton$GE_version.tar.gz" -P "temp/"
  # Removing previous install
  if [[ -d "$COMPAT_TOOLS_DIR/GE-Proton$GE_version" ]]; then
    echo "Removing previous installation of $ProtonGE..."
    subprocess rm -rf "$COMPAT_TOOLS_DIR/GE-Proton$GE_version"
  fi
  # Extracting
  echo "Installing $ProtonGE..."
  subprocess mkdir -p "$COMPAT_TOOLS_DIR"
  subprocess tar -xzf "temp/GE-Proton$GE_version.tar.gz" -C "temp/"
  subprocess cp -rfa "temp/GE-Proton$GE_version" "$COMPAT_TOOLS_DIR"
  subprocess rm -rf "temp/"
  echo "${bold}To enable ProtonGE for Assetto Corsa:
 1. Restart Steam
 2. Go to Assetto Corsa > Properties > Compatability
 3. Turn on 'Force the use of a specific Steam Play compatability tool'
 4. From the drop-down, select $ProtonGE.${reset}"
}
# Asking whether to delete wineprefix
function check-wineprefix {
  if [ -d "$AC_COMPATDATA/pfx" ]; then
    echo "Found existing Wineprefix, deleting it may solve AC not launching/crashing."
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
      subprocess rm -r "ac_configs/"
    else
      exit 2
    fi
  fi
  # Saving configs
  local ac_config_dir="$AC_COMPATDATA/pfx/drive_c/users/steamuser/Documents/Assetto Corsa"
  local cm_config_dir="$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager"
  subprocess mkdir "ac_configs/"
  if [[ -d "$ac_config_dir" ]]; then
    echo "Saving AC configs and presets..."
    subprocess cp -r "$ac_config_dir" "ac_configs/"
  fi
  if [[ -d "$cm_config_dir" ]]; then
    echo "Saving CM configs and presets..."
    subprocess cp -r "$cm_config_dir" "ac_configs/"
  fi
  # Deleting Wineprefix
  if [[ -d "$AC_COMPATDATA/pfx" ]]; then
    echo "Deleting Wineprefix..."
    subprocess rm -rf "$AC_COMPATDATA"
  fi
  # Copying back the saved configs
  local -i copied=0
  if [[ -d "ac_configs/Assetto Corsa" ]]; then
    echo "Copying saved AC configs and presets..."
    subprocess mkdir -p "$AC_COMPATDATA/pfx/drive_c/users/steamuser/Documents"
    subprocess cp -r "ac_configs/Assetto Corsa" "$ac_config_dir"
    copied+=1
  fi
  if [[ -d "ac_configs/AcTools Content Manager" ]]; then
    echo "Copying saved CM configs and presets..."
    subprocess mkdir -p "$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local"
    subprocess cp -r "ac_configs/AcTools Content Manager" "$cm_config_dir"
    copied+=1
  fi
  # Deleting the saved configs
  if [[ -d "ac_configs/" ]] && (($copied == 2)); then
    subprocess rm -r "ac_configs/"
  fi
  # Deleting Content Manager
  local ac_exe="$AC_COMMON/AssettoCorsa.exe"
  local ac_original_exe="$AC_COMMON/AssettoCorsa_original.exe"
  if [[ -f "$ac_original_exe" ]]; then
    echo "Deleting Content Manager..."
    subprocess rm "$ac_exe"
    subprocess mv "$ac_original_exe" "$ac_exe"
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
  # Installing cm
  echo "Installing Content Manager..."
  subprocess wget -q "https://acstuff.club/app/latest.zip" -P "temp/"
  subprocess unzip -q "temp/latest.zip" -d "temp/"
  if [[ -e "$AC_COMMON/AssettoCorsa.exe" ]] && [[ ! -e "$AC_COMMON/AssettoCorsa_original.exe" ]]; then
    subprocess mv -n "$AC_COMMON/AssettoCorsa.exe" "$AC_COMMON/AssettoCorsa_original.exe"
  fi
  subprocess rm "temp/latest.zip"
  subprocess cp -r "temp/"* "$AC_COMMON/"
  subprocess rm -rf "temp/"
  subprocess mv "$AC_COMMON/Content Manager.exe" "$AC_COMMON/AssettoCorsa.exe"
  # Installing fonts
  echo "Installing fonts required for Content Manager..."
  subprocess wget -q "https://files.acstuff.ru/shared/T0Zj/fonts.zip" -P "temp/"
  subprocess unzip -qo "temp/fonts.zip" -d "temp/"
  subprocess rm "temp/fonts.zip"
  subprocess cp -r "temp/system" "$AC_COMMON/content/fonts/"
  subprocess rm -rf "temp/"
  # Creating symlink
  echo "Creating symlink..."
  local link_from="$STEAM_DIR/config/loginusers.vdf"
  local link_to="$AC_COMPATDATA/pfx/drive_c/Program Files (x86)/Steam/config/loginusers.vdf"
  subprocess ln -sf "$link_from" "$link_to"
  # Adding ability to open acmanager uri links
  if [[ -f "$AC_DESKTOP" ]]; then
    mimelist="$HOME/.config/mimeapps.list"
    # Cleaning up previous modifications to mimeapps.list
    if [[ -f "$mimelist" ]]; then
      subprocess sed "s|x-scheme-handler/acmanager=Assetto Corsa.desktop;||g" -i "$mimelist"
      subprocess sed "s|x-scheme-handler/acmanager=Assetto Corsa.desktop||g" -i "$mimelist"
      subprocess sed '$!N; /^\(.*\)\n\1$/!P; D' -i "$mimelist"
    fi
    # Adding acmanager to mimeapps.list
    echo "Adding ability to open acmanager links..."
    subprocess sed "s|steam steam://rungameid/244210|$APPLAUNCH_AC|g" -i "$AC_DESKTOP"
    subprocess gio mime x-scheme-handler/acmanager "Assetto Corsa.desktop" 1>&/dev/null
    echo "Opening ${bold}acmanager://${reset} links will only work if Content Manager/Assetto Corsa is not open already."
  else
    echo "Assetto Corsa does not have a .desktop shortcut, URI links to CM will not work."
  fi
  echo "When starting Content Manager, set the root Assetto Corsa folder to ${bold}Z:$AC_COMMON${reset}"
}
# Checking if CSP is installed
function check-csp {
  # Getting CSP version
  local current_CSP_version=""
  local data_manifest_file="$AC_COMMON/extension/config/data_manifest.ini"
  if [[ -f "$data_manifest_file" ]]; then
    current_CSP_version="$(cat "$data_manifest_file" | grep "SHADERS_PATCH=" | sed 's/SHADERS_PATCH=//g')"
  fi
  # Asking
  if [[ $current_CSP_version == "$CSP_version" ]]; then
    local string="Reinstall CSP v$CSP_version?"
  else
    local string="Install CSP (Custom Shaders Patch) v$CSP_version?"
  fi
  if ask "$string"; then
    install-csp
  fi
}
function install-csp {
  # Adding dwrite dll override
  local reg_dwrite="$(echo "$(cat "$AC_COMPATDATA/pfx/user.reg")" | grep "dwrite")"
  if [[ $reg_dwrite == "" ]]; then
    echo "Adding DLL override 'dwrite'..."
    subprocess sed '/\"\*d3d11"="native\"/a \"dwrite"="native,builtin\"' "$AC_COMPATDATA/pfx/user.reg" -i
  else
    echo "DLL override 'dwrite' already exists."
  fi
  # Installing CSP
  echo "Downloading CSP..."
  subprocess wget -q "https://acstuff.club/patch/?get=$CSP_version" -P "temp/"
  echo "Installing CSP..."
  # For some reason the downloaded file name is weird so we have to rename it
  subprocess mv "temp/index.html?get=$CSP_version" "temp/lights-patch-v$CSP_version.zip" -f
  subprocess unzip -qo "temp/lights-patch-v$CSP_version.zip" -d "temp/"
  subprocess rm "temp/lights-patch-v$CSP_version.zip"
  subprocess cp -r "temp/." "$AC_COMMON"
  subprocess rm -rf "temp/"
  # Installing fonts for CSP
  echo "Installing fonts required for CSP... (this might take a while)"
  subprocess protontricks 244210 corefonts
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
  subprocess sed '/\[NAMES_WINE\]/,$d' "$cfg_file" -i
}

function check-dxvk {
  if ask "Install DXVK? (can improve performance in some cases)"; then
    install-dxvk
  fi
}
function install-dxvk {
  echo "Installing DXVK..."
  subprocess protontricks --no-background-wineserver 244210 dxvk
}

function check-simhub {
  if [[ -d "$SIMHUB_DIR" ]]; then
    local string="Reinstall SimHub $SIMHUB_VERSION?"
  else
    local string="Install SimHub $SIMHUB_VERSION?"
  fi
  if ask "$string"; then
    install-simhub
  fi
}
function install-simhub {
  echo "Downloading SimHub..."
  subprocess wget -q "https://github.com/SHWotever/SimHub/releases/download/$SIMHUB_VERSION/SimHub.$SIMHUB_VERSION.zip" -P "temp/"
  echo "Installing SimHub..."
  subprocess unzip -qo "temp/SimHub.$SIMHUB_VERSION.zip" -d "temp/"
  local installer="$(ls temp/SimHubSetup_*.exe | head -1)"
  subprocess protontricks-launch --appid 244210 "$(pwd)/$installer" /VERYSILENT /SUPPRESSMSGBOXES /DIR="C:\\Program Files (x86)\\SimHub"
  subprocess rm -rf "temp/"
  echo "Installing .NET Framework 4.8 (required by SimHub)..."
  subprocess protontricks 244210 dotnet48
  echo "Creating launcher script..."
  subprocess mkdir -p "$HOME/.local/bin"
  local launcher="$HOME/.local/bin/simhub"
  cat >"$launcher" <<LAUNCHEREOF
#! /usr/bin/env bash
exec protontricks-launch --appid 244210 "$SIMHUB_DIR/SimHubWPF.exe" "\$@"
LAUNCHEREOF
  subprocess chmod +x "$launcher"
  if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "${warning}$HOME/.local/bin is not in PATH. Add it or run SimHub with: ${bold}$launcher${reset}"
  fi
  echo "${bold}Start Assetto Corsa from Steam/Content Manager first, then start SimHub with: ${launcher}${reset}"
}

function get-zip-entry {
  local zip_file="$1"
  local filename="$2"
  local entry
  while IFS= read -r entry; do
    if [[ "$entry" == "$filename" ]] || [[ "$entry" == */"$filename" ]]; then
      echo "$entry"
      return 0
    fi
  done < <(unzip -Z -1 "$zip_file")
  return 1
}

function unzip-allow-backslash-warning {
  local output
  output="$(unzip "$@" 2>&1)"
  local status=$?
  if [[ "$status" == "0" ]]; then
    return 0
  fi
  if [[ "$status" == "1" ]] && [[ "$output" == *"appears to use backslashes as path separators"* ]]; then
    return 0
  fi
  line=($(caller))
  echo "
${error}Encountered an error while running 'unzip $@' at line $line:${reset}
$output

${warning}If this is an issue, please report it on Github.${reset}
"
  exit 1
}

function check-carplay-addon {
  if [[ ! -d "$SIMHUB_DIR" ]]; then
    return 1
  fi
  if ask "Install Apple CarPlay SimHub dashboard addon?"; then
    install-carplay-addon
  fi
}
function install-carplay-addon {
  local default_dir="$HOME/Downloads/Assetto Downloads/Carplay"
  echo "Enter path to folder containing ${bold}Apple-CarPlay.zip${reset} and ${bold}SimHubUDPConnector.zip${reset}:"
  read -ei "$default_dir" addon_dir || return 1
  addon_dir="$(echo "${addon_dir%"/"}" | sed "s|\~\/|$HOME\/|g")"

  local carplay_zip="$addon_dir/Apple-CarPlay.zip"
  local udpconnector_zip="$addon_dir/SimHubUDPConnector.zip"
  if [[ ! -f "$carplay_zip" ]] || [[ ! -f "$udpconnector_zip" ]]; then
    echo "${warning}Apple CarPlay addon install skipped.${reset}"
    echo "Required files:"
    echo " - $carplay_zip"
    echo " - $udpconnector_zip"
    return 1
  fi

  local simhubdash_entry
  simhubdash_entry="$(get-zip-entry "$carplay_zip" "Apple-CarPlay.simhubdash")" || {
    echo "${error}Apple-CarPlay.simhubdash was not found in $carplay_zip.${reset}"
    return 1
  }
  local dll_entry
  dll_entry="$(get-zip-entry "$udpconnector_zip" "DaZD.UDPConnector.dll")" || {
    echo "${error}DaZD.UDPConnector.dll was not found in $udpconnector_zip.${reset}"
    return 1
  }
  local ac_app_entry
  ac_app_entry="$(get-zip-entry "$udpconnector_zip" "SimHubUDPConnector/Assetto Corsa/app/SimHubUDPConnector.zip")" || {
    echo "${error}Assetto Corsa SimHubUDPConnector app zip was not found in $udpconnector_zip.${reset}"
    return 1
  }
  local torque_extension_entry
  torque_extension_entry="$(get-zip-entry "$carplay_zip" "TorquePowerExtensionMy.lua")" || {
    echo "${error}TorquePowerExtensionMy.lua was not found in $carplay_zip.${reset}"
    return 1
  }
  local font_entry
  font_entry="$(get-zip-entry "$carplay_zip" "SF-Pro.ttf")" || {
    echo "${error}SF-Pro.ttf was not found in $carplay_zip.${reset}"
    return 1
  }

  local cm_presets_dir="$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager/Presets/Custom Previews"
  local cm_preset_entries=()
  if [[ -d "$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager" ]]; then
    for preset in "preview_light.cmpreset" "preview_nolight.cmpreset"; do
      local preset_entry
      preset_entry="$(get-zip-entry "$carplay_zip" "$preset")" || {
        echo "${error}$preset was not found in $carplay_zip.${reset}"
        return 1
      }
      cm_preset_entries+=("$preset_entry")
    done
  fi

  echo "Installing Apple CarPlay SimHub dashboard addon..."
  subprocess mkdir -p "temp/carplay"
  subprocess unzip -qo "$carplay_zip" "$simhubdash_entry" -d "temp/carplay"
  subprocess mkdir -p "$SIMHUB_DIR/DashTemplates"
  unzip-allow-backslash-warning -qo "temp/carplay/$simhubdash_entry" -d "$SIMHUB_DIR/DashTemplates"
  subprocess unzip -jqo "$udpconnector_zip" "$dll_entry" -d "$SIMHUB_DIR"
  subprocess unzip -jqo "$udpconnector_zip" "$ac_app_entry" -d "temp/carplay"
  subprocess unzip -qo "temp/carplay/SimHubUDPConnector.zip" -d "$AC_COMMON"

  local extension_dir="$AC_COMMON/apps/lua/SimHubUDPConnector/extensions"
  subprocess mkdir -p "$extension_dir"
  subprocess unzip -jqo "$carplay_zip" "$torque_extension_entry" -d "$extension_dir"
  subprocess mkdir -p "$SIMHUB_DIR/DashFonts" "$AC_COMPATDATA/pfx/drive_c/windows/Fonts"
  subprocess unzip -jqo "$carplay_zip" "$font_entry" -d "$SIMHUB_DIR/DashFonts"
  subprocess unzip -jqo "$carplay_zip" "$font_entry" -d "$AC_COMPATDATA/pfx/drive_c/windows/Fonts"
  if ((${#cm_preset_entries[@]} > 0)); then
    subprocess mkdir -p "$cm_presets_dir"
    for preset_entry in "${cm_preset_entries[@]}"; do
      subprocess unzip -jqo "$carplay_zip" "$preset_entry" -d "$cm_presets_dir"
    done
  fi

  subprocess rm -rf "temp/"
  echo "${bold}Apple CarPlay addon installed. Post-install steps:
 1. Start Assetto Corsa first, then SimHub.
 2. In AC/CSP, enable the SimHub UDPConnector extension and activate TorquePowerExtensionMy.
 3. In SimHub, enable Media Information and set the dashboard's simulated keys to match AC controls.
 4. In Content Manager, generate previews twice using preview_light and preview_nolight.${reset}"
}

function check-generated-files {
  if [ ! -d "$AC_COMPATDATA/pfx/drive_c/Program Files (x86)/Steam/config" ]; then
    echo "\
${bold}Before proceeding, please do the following to generate the wineprefix:
 1. Launch Assetto Corsa with Proton-GE $GE_version
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
  check-simhub
  check-carplay-addon
)
echo
for func in "${OPTIONAL_STEPS[@]}"; do
  $func && echo
done
echo "${bold}All done!${reset}"
