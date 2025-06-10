#!/bin/bash
# Preventing from running as root
if [[ $USER == "root" ]]; then
  echo "Please do not run as root."
  exit 1
fi

# Useful variables
GE_version="9-20"; CSP_version="0.2.9"
## Defining text styles for readablity
bold=$(tput bold); normal=$(tput sgr0)
## Supported distros
supported_apt=("debian" "ubuntu" "linuxmint" "pop")
supported_dnf=("fedora" "nobara" "ultramarine")
supported_arch=("arch" "endeavouros" "steamos" "cachyos")
supported_opensuse=("opensuse-tumbleweed")
## Required native and flatpak packages
req_packages=("wget" "tar" "unzip" "glib2" "protontricks")
req_flatpaks=("")

# Setting paths
function set_paths_for {
  # Setting steam paths
  if [[ $1 == "steam" ]]; then
    # Setting native paths
    if [[ $2 == "native" ]]; then
      LOCAL="$HOME/.local"
      APPLAUNCH_AC="steam -applaunch 244210 %u"
    # Setting flatpak paths
    elif [[ $2 == "flatpak" ]]; then
      LOCAL="$HOME/.var/app/com.valvesoftware.Steam"
      APPLAUNCH_AC="flatpak run com.valvesoftware.Steam -applaunch 244210 %u"
    else
      Error "set_paths_for: '$1 $2' is not a valid option"
    fi
    # Setting universal paths
    AC_COMMON="$LOCAL/share/Steam/steamapps/common/assettocorsa"
    COMPAT_TOOLS_DIR="$LOCAL/share/Steam/compatibilitytools.d"
    AC_DESKTOP="$LOCAL/share/applications/Assetto Corsa.desktop"
  # Setting AC paths
  elif [[ $1 == "assettocorsa" ]]; then
    AC_COMMON="$2"
    STEAMAPPS="${AC_COMMON%"/common/assettocorsa"}"
    AC_COMPATDATA="$STEAMAPPS/compatdata/244210"
  else
    Error "set_paths_for: '$1' is not a valid option"
  fi
}

# Checking OS compatability
function get_release {
  os_release="$(cat /etc/os-release)"
  echo "$(echo $os_release | sed "s/.* $1=//g" | sed "s/$1=\"//g" |  sed "s/ .*//g" | sed "s/\"//g")"
}
function CheckOS {
  OS="$(get_release ID)"; OS_like="$(get_release ID_LIKE)"; OS_name="$(get_release NAME)"
  if [[ ${supported_dnf[*]} =~ "$OS" ]] || [[ ${supported_dnf[*]} =~ "$OS_like" ]]; then 
    pm_install="dnf install"; pm_list="dnf list --installed"
  elif [[ ${supported_apt[*]} =~ "$OS" ]] || [[ ${supported_apt[*]} =~ "$OS_like" ]]; then 
    pm_install="apt install"; pm_list="apt list --installed"
  elif [[ ${supported_arch[*]} =~ "$OS" ]] || [[ ${supported_arch[*]} =~ "$OS_like" ]]; then 
    pm_install="pacman -S"; pm_list="pacman -Q"
  elif [[ ${supported_opensuse[*]} =~ "$OS" ]] || [[ ${supported_opensuse[*]} =~ "$OS_like" ]]; then 
    pm_install="zypper install"; pm_list="zypper search --installed-only"
  else
    echo "$OS_name is not currently supported. Please open an issue to support it."
    exit 1
  fi
}

# Checking if Flatpak and Flathub is set up
function CheckFlathub {
  if [[ $(flatpak remotes) != *"flathub"* ]]; then
    echo "Flatpak is either not installed or the Flathub remote is not configured.
  Refer to ${bold}https://flathub.org/setup${normal} to set-up Flatpak."
    exit 1
  fi
}

# Checking if required packages are installed
function CheckDependencies {
  installed_packages=($($pm_list))
  installed_flatpaks=($(flatpak list --columns=application))
  for package in ${req_packages[@]}; do
    if [[ ${installed_packages[@]} != *$package* ]]; then
      echo "$package is not installed, run ${bold}sudo $pm_install $package${normal} to install."
      exit 1
    fi
  done
  for package in ${req_flatpaks[@]}; do
    if [[ ${installed_flatpaks[@]} != *$package* ]]; then
      echo "$package is not installed, run ${bold}flatpak install $package${normal} to install."
      exit 1
    fi
  done
}

# Checking if Steam is installed through Flatpak or natively
function CheckSteamInstall {
  if [[ ${installed_packages[@]} == *"steam"* ]] && [[ ${installed_flatpaks[@]} == *"com.valvesoftware.Steam"* ]]; then
    echo "Steam is installed both as a native package and Flatpak."
    PS3="Select which installation of Steam to use: "
    select installation_method in "Native" "Flatpak"
    do
      installation_method="$(echo ${installation_method,,} | awk '{print $1;}')" # Converting to lowercase and getting the first word
      if [ $installation_method == "native" ]; then
        set_paths_for steam native
        break
      elif [ $installation_method == "flatpak" ]; then
        set_paths_for steam flatpak
        break
      fi
    done
  elif [[ ${installed_packages[@]} == *"steam"* ]]; then
    echo "Native installation of Steam found."
    set_paths_for steam native
  elif [[ ${installed_flatpaks[@]} == *"com.valvesoftware.Steam"* ]]; then
    echo "Flatpak installation of Steam found."
    set_paths_for steam flatpak
  else
    echo "Steam installation not found. Native and Flatpak versions of Steam are supported."
    exit 1
  fi
}

function CheckAssettoProcess {
  ac_pid="$(pgrep "AssettoCorsa.ex")"
  if [[ $ac_pid != "" ]]; then
    Ask "Assetto Corsa is running. Stop Assetto Corsa to proceed?" && kill "$ac_pid" &&
    return
    exit
  fi
}

function CheckTempDir {
  if [[ -d "temp/" ]]; then
    echo "\"temp\" directory found inside current directory. It needs to be removed or renamed for this script to work."
    Ask "Move \"temp/\" to trash?" && gio trash "temp" --force && return
    exit 1
  fi
}

function FindAC {
  if [ -d $AC_COMMON ]; then
    echo "Found ${bold}$AC_COMMON${normal}."
    Ask "Is that the right installation?" &&
    set_paths_for assettocorsa "$AC_COMMON" &&
    return
  else
    echo "Could not find Asseto Corsa in the default path."
  fi
  while :; do
    echo "Enter path to ${bold}steamapps/common/assettocorsa${normal}:"
    read -i "$PWD/" -e AC_COMMON &&
    # Converting '~/directory/' to '/home/user/directory'
    AC_COMMON="$(echo "${AC_COMMON%"/"}" | sed "s|\~\/|$HOME\/|g")"
    if [[ -d $AC_COMMON ]] && [[ $(basename "$AC_COMMON") == "assettocorsa" ]]; then
      set_paths_for assettocorsa "$AC_COMMON"
      break
    else
      echo "Invalid directory."; echo
    fi
  done
}

function StartMenuShortcut {
  link_file="$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Content Manager.lnk"
  if [[ -f "$link_file" ]]; then
    echo "Start Menu Shortcut for Content Manager found. This might be causing crashes on start-up."
    Ask "Delete the shortcut?" && rm "$link_file" 
  fi
}

function CheckPrefix {
  if [ -d "$AC_COMPATDATA/pfx" ]; then
    echo "Found existing Wineprefix, deleting it may solve AC not launching/crashing."
    Ask "Delete existing Wineprefix and Content Manager? (preserves configs, presets and mods)" && RemovePrefix
  fi
}
function RemovePrefix {
  # Asking whether to get rid of previous configs
  if [[ -d "ac_configs/" ]]; then
    while :; do
      echo "Found previous save of AC and CM configs in ${bold}$PWD/ac_configs/${normal}."
      Ask "Delete previous saves to proceed?" &&
      rm -r "ac_configs/" &&
      break
      exit 1
    done
  fi
  # Saving configs
  mkdir "ac_configs/"
  ac_config_dir="$AC_COMPATDATA/pfx/drive_c/users/steamuser/Documents/Assetto Corsa"
  cm_config_dir="$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager"
  if [[ -d "$ac_config_dir" ]]; then
    while :; do
      echo "Saving AC configs and presets..." &&
      cp -r "$ac_config_dir" "ac_configs" &&
      break
      Error "Failed to copy AC configuration to 'temp', aborting deletion of Wineprefix."
    done
  fi
  if [[ -d "$cm_config_dir" ]]; then
    while :; do
      echo "Saving CM configs and presets..." &&
      cp -r "$cm_config_dir" "ac_configs" &&
      break
      Error "Failed to copy CM configuration to 'temp', aborting deletion of Wineprefix"
    done
  fi
  # Deleting Wineprefix
  if [[ -d "$AC_COMPATDATA/pfx" ]]; then
    while :; do
      echo "Deleting Wineprefix..." &&
      rm -rf "$AC_COMPATDATA" &&
      break
      Error "Failed to delete '$AC_COMPATDATA/pfx'"
    done
  fi
  # Copying back the saved configs
  declare -i copied=0
  if [[ -d "ac_configs/Assetto Corsa" ]]; then
    while :; do
      echo "Copying saved AC configs and presets..." &&
      mkdir -p "$AC_COMPATDATA/pfx/drive_c/users/steamuser/Documents" &&
      cp -r "ac_configs/Assetto Corsa" "$ac_config_dir" &&
      copied+=1 &&
      break
      Error "Failed to copy preserved CM configuration."
    done
  fi
  if [[ -d "ac_configs/AcTools Content Manager" ]]; then
    while :; do
      echo "Copying saved CM configs and presets..." &&
      mkdir -p "$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local" &&
      cp -r "ac_configs/AcTools Content Manager" "$cm_config_dir" &&
      copied+=1 &&
      break
      Error "Failed to copy preserved CM configuration."
    done
  fi
  # Deleting the saved configs
  if [[ -d "ac_configs/" ]] && (( $copied == 2 )); then
    while :; do
      rm -r "ac_configs/" &&
      break
      Error "Could not delete 'ac_configs/' directory"
    done
  fi
  # Deleting Content Manager
  ac_exe="$AC_COMMON/AssettoCorsa.exe"
  ac_original_exe="$AC_COMMON/AssettoCorsa_original.exe"
  if [[ -f "$ac_original_exe" ]]; then
    while :; do
      echo "Removing AC executable..." &&
      rm "$ac_exe" &&
      mv "$ac_original_exe" "$ac_exe" &&
      break
      Error "Failed to delete Content Manager executable"
    done
  fi
}

function CheckProtonGE {
  # Finding current ProtonGE version
  declare -i current_ge_version=0
  compat_tools=($(ls "$COMPAT_TOOLS_DIR/"))
  for compat_tool in ${compat_tools[@]}; do
    if [[ $compat_tool == "GE-Proton"* ]]; then
      declare -i compat_tool_version=$(echo $compat_tool | sed 's/GE-Proton//g' | sed 's/-//g')
      if (( $compat_tool_version > $current_ge_version )); then
        declare -i current_GE_version=$compat_tool_version
        current_GE="$(echo $compat_tool | sed 's/GE-Proton/ProtonGE/g')"
      fi
    fi
  done
  # Asking whether to install ProtonGE
  ProtonGE="ProtonGE $GE_version"
  declare -i GE_tobeinstalled=$(echo $GE_version | sed 's|-||g')
  if (( $GE_tobeinstalled == $current_GE_version )); then
    Ask "Reinstall $ProtonGE?" && InstallProtonGE
  elif (( $GE_tobeinstalled > $current_GE_version )); then
    Ask "$current_GE is already installed. Update to $ProtonGE?" && InstallProtonGE
  elif (( $GE_tobeinstalled < $current_GE_version )); then
    Ask "$current_GE is already installed. Downgrade to $ProtonGE?" && InstallProtonGE
  else
    Ask "Install $ProtonGE?" && InstallProtonGE
  fi
}
function InstallProtonGE {
  # Deleting previous install
  if [[ -d "$COMPAT_TOOLS_DIR/GE-Proton$GE_version" ]]; then
    echo "Removing previous installation of GE-Proton$GE_version..."
    rm -rf "$COMPAT_TOOLS_DIR/GE-Proton$GE_version"
  fi
  # Installing ProtonGE
  echo "Downloading $ProtonGE..."
  wget -q "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton$GE_version/GE-Proton$GE_version.tar.gz" -P "temp/" &&
  echo "Installing $ProtonGE..." &&
  mkdir -p "$COMPAT_TOOLS_DIR" &&
  tar -xzf "temp/GE-Proton$GE_version.tar.gz" -C "temp/" &&
  cp -rfa "temp/GE-Proton$GE_version" "$COMPAT_TOOLS_DIR" &&
  rm -rf "temp/" &&
  echo "${bold}To enable ProtonGE for Assetto Corsa:
1. Restart Steam.
2. Go to Assetto Corsa > Properties > Compatability.
3. Turn on 'Force the use of a specific Steam Play compatability tool'.
4. From the drop-down, select $ProtonGE.${normal}" &&
  return
  Error "$ProtonGE installation failed"
}

function CheckContentManager {
  if [[ -f "$AC_COMMON/AssettoCorsa_original.exe" ]]; then
    Ask "Reinstall Content Manager?" && InstallContentManager
  else
    Ask "Install Content Manager?" && InstallContentManager
  fi
}
function InstallContentManager {
  # Installing CM
  while :; do
    echo "Installing Content Manager..." &&
    wget -q "https://acstuff.club/app/latest.zip" -P "temp/" &&
    unzip -q "temp/latest.zip" -d "temp/" &&
    mv "temp/Content Manager.exe" "temp/AssettoCorsa.exe" &&
    mv -n "$AC_COMMON/AssettoCorsa.exe" "$AC_COMMON/AssettoCorsa_original.exe" &&
    rm "temp/latest.zip" &&
    cp -r "temp/"* "$AC_COMMON/" &&
    rm -r "temp" &&
    break
    Error "Content Manager installation failed"
  done
  # Installing fonts
  while :; do
    echo "Installing fonts required for Content Manager..." &&
    wget -q "https://files.acstuff.ru/shared/T0Zj/fonts.zip" -P "temp/" &&
    unzip -qo "temp/fonts.zip" -d "temp/" &&
    rm "temp/fonts.zip" &&
    cp -r "temp/system" "$AC_COMMON/content/fonts/" &&
    rm -r "temp/" &&
    break
    Error "Font installation for CM failed"
  done
  # Creating symlink
  while :; do
    echo "Creating symlink..." &&
    link_from="$LOCAL/share/Steam/config/loginusers.vdf" &&
    link_to="$AC_COMPATDATA/pfx/drive_c/Program Files (x86)/Steam/config/loginusers.vdf" &&
    ln -sf "$link_from" "$link_to" &&
    break
    Error "Failed to create the symlink for CM"
  done
  # Adding ability to open acmanager uri links
  if [[ -f "$AC_DESKTOP" ]]; then
    mimelist="$HOME/.config/mimeapps.list"
    while :; do
      # Cleaning up previous modifications to mimeapps.list
      if [[ -f "$mimelist" ]]; then
        while :; do
          sed "s|x-scheme-handler/acmanager=Assetto Corsa.desktop;||g" -i "$mimelist" &&
          sed "s|x-scheme-handler/acmanager=Assetto Corsa.desktop||g" -i "$mimelist" &&
          sed '$!N; /^\(.*\)\n\1$/!P; D' -i "$mimelist" &&
          break
          Error "Could not clean up previous modifications to mimeapps.list"
        done
      fi
      # Adding acmanager to mimeapps.list
      echo "Adding ability to open acmanager links..." &&
      sed "s|steam steam://rungameid/244210|$APPLAUNCH_AC|g" -i "$AC_DESKTOP" &&
      gio mime x-scheme-handler/acmanager "Assetto Corsa.desktop" 1>& /dev/null &&
      break
      Error "Could not add acmanager to mimeapps.list"
    done
  else
    echo "Assetto Corsa does not have a .desktop shortcut, URI links to CM will not work."
  fi
}

function CheckCSP {
  # Getting CSP version
  data_manifest_file="$AC_COMMON/extension/config/data_manifest.ini"
  if [[ -f "$data_manifest_file" ]]; then
    current_CSP_version="$(cat "$data_manifest_file" | grep "SHADERS_PATCH=" | sed 's/SHADERS_PATCH=//g')"
  fi
  # Asking whether to install
  if [[ $current_CSP_version == "" ]]; then
    Ask "Install CSP (Custom Shaders Patch) v$CSP_version?" && InstallCSP
  elif [[ $current_CSP_version == "$CSP_version" ]]; then
    Ask "Reinstall CSP v$CSP_version?" && InstallCSP
  else
    Ask "CSP v$current_CSP_version is already installed. Install CSP v$CSP_version instead?" && InstallCSP
  fi
}
function InstallCSP {
  # Adding dwrite dll override
  reg_dwrite="$(echo "$(cat "$AC_COMPATDATA/pfx/user.reg")" | grep "dwrite")"
  if [[ $reg_dwrite == "" ]]; then
    while :; do
      echo "Adding DLL override 'dwrite'..." &&
      sed '/\"\*d3d11"="native\"/a \"dwrite"="native,builtin\"' "$AC_COMPATDATA/pfx/user.reg" -i &&
      break
      Error "Could not create DLL override for 'dwrite'"
    done
  else
    echo "DLL override 'dwrite' already exists."
  fi
  # Installing CSP
  while :; do
    echo "Downloading CSP..." &&
    wget -q "https://acstuff.club/patch/?get=$CSP_version" -P "temp/" &&
    echo "Installing CSP..." &&
    # For some reason the downloaded file name is weird so we have to rename it
    mv "temp/index.html?get=$CSP_version" "temp/lights-patch-v$CSP_version.zip" -f &&
    unzip -qo "temp/lights-patch-v$CSP_version.zip" -d "temp/" &&
    rm "temp/lights-patch-v$CSP_version.zip" &&
    cp -r "temp/." "$AC_COMMON" &&
    rm -r "temp" &&
    break
    Error "CSP installation failed"
  done
  # Installing fonts for CSP
  while :; do
    echo "Installing fonts required for CSP... (this might take a while)"
    protontricks 244210 corefonts 1>& /dev/null &&
    return
    Error "Could not install corefonts for CSP"
  done
}

function DXVK {
  echo "Installing DXVK..."
  protontricks --no-background-wineserver 244210 dxvk 1>& /dev/null &&
  return
  Error "Could not install DXVK"
}

# Helper functions
function Error {
  echo "${bold}ERROR${normal}: $1. If this is an issue, please report it on github."
  exit 1
}
function Ask {
  while true; do
    read -p "$* [y/n]: " yn
    case $yn in
      [Yy]*) return 0 ;;
      [Nn]*) echo "Skipping..." ; return 1 ;;
    esac
  done
}

function check_generated_files {
  if [ ! -d "$AC_COMPATDATA/pfx/drive_c/Program Files (x86)/Steam/config" ]; then
    echo "Please launch Assetto Corsa with Proton-GE to generate required files before proceeding.
  It will take a while to launch since it's creating a Wineprefix and installing dependencies."
    exit 1
  fi
}

# Checking stuff
CheckOS
CheckFlathub
CheckDependencies
CheckSteamInstall
CheckAssettoProcess
CheckTempDir
# Running functions
FindAC
StartMenuShortcut
CheckPrefix
CheckProtonGE
check_generated_files # Checking if assettocorsa's files were generated
# Continuing to run functions
CheckContentManager
CheckCSP
Ask "Install DXVK? (fixes poor performance on some servers)" && DXVK
echo "${bold}All done!${normal}"
