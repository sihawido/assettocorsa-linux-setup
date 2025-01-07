if [[ $USER == "root" ]]; then
  echo "Please do not run as root."
  exit 1
fi

# Useful variables
GE_version="9-22"; CSP_version="0.2.5"
## Defining text styles for readablity
bold=$(tput bold); normal=$(tput sgr0)
## Supported distros
supported_apt=("debian" "ubuntu" "linuxmint" "pop")
supported_dnf=("fedora" "ultramarine")
supported_arch=("arch" "endeavouros" "steamos")
## Required native and flatpak packages
req_packages=("wget" "unzip" "ls" "cd" "cp" "mv" "echo" "sed" "test" "read" "flatpak")
req_flatpaks=("protontricks")

# Checking OS compatability
function get_release () {
  os_release="$(cat /etc/os-release)"
  echo "$(echo $os_release | sed "s/.* $1=//g" | sed "s/$1=\"//g" |  sed "s/ .*//g" | sed "s/\"//g")"
}
function CheckOS () {
  OS="$(get_release ID)"; OS_name="$(get_release NAME)"
  if [[ ${supported_dnf[*]} =~ "$OS" ]]; then pm_install="dnf install"
  elif [[ ${supported_apt[*]} =~ "$OS" ]]; then pm_install="apt install"
  elif [[ ${supported_arch[*]} =~ "$OS" ]]; then pm_install="pacman -S"
  else echo "$OS_name is not currently supported. Please open an issue to support it."; exit 1; fi
}

# Checking if Flatpak and Flathub is set up
function CheckFlathub () {
  flatpak_remotes="$(flatpak remotes)"
  if [[ $flatpak_remotes != *"flathub"* ]]; then
    echo "Flatpak is either not installed or the Flathub remote is not configured.
  Refer to ${bold}https://flathub.org/setup${normal} to set-up Flatpak."
    exit 1
  else
    installed_flatpaks=($(flatpak list --columns=application))
  fi
}

# Checking if required packages are installed
function CheckDependencies () {
  installed_packages=($(ls /bin))
  installed_packages+=($(ls /usr/bin))
  installed_packages+=($(ls /usr/games 2> /dev/null)) # PopOS stores the steam exec in /usr/games
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
function CheckSteamInstall () {
  if [[ ${installed_packages[@]} == *"steam"* ]] && [[ ${installed_flatpaks[@]} == *"com.valvesoftware.Steam"* ]]; then
    echo "Steam is installed both as a native package and Flatpak."
    PS3="Select which installation of Steam to use: "
    select installation_method in "Native" "Flatpak"
    do
      installation_method="$(echo ${installation_method,,} | awk '{print $1;}')" # converting to lowercase and using only the first word
      if [ $installation_method == "native" ]; then
        steam_install_method="native"
        break
      elif [ $installation_method == "flatpak" ]; then
        steam_install_method="flatpak"
        break
      fi
    done
  elif [[ ${installed_packages[@]} == *"steam"* ]]; then
    echo "Native installation of Steam found."
    steam_install_method="native"
  elif [[ ${installed_flatpaks[@]} == *"com.valvesoftware.Steam"* ]]; then
    echo "Flatpak installation of Steam found."
    steam_install_method="flatpak"
  else
    echo "Steam installation not found. Native and Flatpak versions of Steam are supported."
    exit 1
  fi
  # Setting paths depending on Steam installation
  if [[ $steam_install_method == "native" ]]; then
    default_ac_path="$HOME/.local/share/Steam/steamapps/common/assettocorsa"
    STEAM_ROOT="$HOME/.steam/root"
  elif [[ $steam_install_method == "flatpak" ]]; then
    default_ac_path="$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/assettocorsa"
    STEAM_ROOT="$HOME/.var/app/com.valvesoftware.Steam/.steam/root"
  fi
}

function CheckTempDir () {
  if [[ -d "temp/" ]]; then
    echo "\"temp\" directory found inside current directory. It needs to be removed or renamed for this script to work."
    Ask "Move \"temp/\" to trash?" && gio trash "temp" --force && return
    exit 1
  fi
}

function FindAC () {
  if [ -d $default_ac_path ]; then
    echo "Found ${bold}$default_ac_path${normal}."
    Ask "Is that the right installation?" &&
    STEAMAPPS="${default_ac_path%"/common/assettocorsa"}" &&
    return
  else
    echo "Could not find Asseto Corsa in the default path."
  fi
  while :; do
    echo "Enter path to ${bold}steamapps/common/assettocorsa${normal}:"
    read -i "$PWD/" -e ac_dir &&
    ac_dir=${ac_dir%"/"} && # in case path ends with "/" (test -d doesnt work if that is the case)
    eval "ac_dir=$ac_dir" && # In case the path includes ~
    STEAMAPPS="${ac_dir%"/common/assettocorsa"}"
    if [ -d $ac_dir ] && [[ $(echo $ac_dir | sed -e 's/.*assettocorsa/assettocorsa/') == "assettocorsa" ]]; then
      echo "Directory valid. Proceeding."
      break
    else
      echo "Invalid directory."; echo
    fi
  done
}

function StartMenuShortcut () {
  if [ -f "$STEAMAPPS/compatdata/244210/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Content Manager.lnk" ]; then
    echo "Start Menu Shortcut for Content Manager found. This might be causing crashes on start-up."
    Ask "Delete the shortcut?" && rm "$STEAMAPPS/compatdata/244210/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Content Manager.lnk"
  fi
}

function CheckProtonGE () {
  protonge="GE-Proton$GE_version"
  if [[  ! -d "$STEAM_ROOT/compatibilitytools.d/GE-Proton$GE_version" ]]; then
    Ask "Install $protonge?" && InstallProtonGE
    return
  else
    echo "Found installation of GE-Proton$GE_version."
    Ask "Reinstall $protonge?" && InstallProtonGE
  fi
}

function InstallProtonGE () {
  if [[ -d "$STEAM_ROOT/compatibilitytools.d/GE-Proton$GE_version" ]]; then
    echo "Removing previous installation of GE-Proton$GE_version..."
    rm -rf "$STEAM_ROOT/compatibilitytools.d/GE-Proton$GE_version"
  fi
  echo "Downloading $protonge..."
  wget -q "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton$GE_version/GE-Proton$GE_version.tar.gz" -P "temp/" &&
  echo "Installing $protonge..." &&
  tar -xzf "temp/GE-Proton$GE_version.tar.gz" -C "temp/" &&
  cp -rfa "temp/GE-Proton$GE_version" "$STEAM_ROOT/compatibilitytools.d" &&
  rm -rf "temp/" &&
  echo "1. ${bold}Restart Steam.
2. Go to Assetto Corsa > Properties > Compatability.
3. Turn on 'Force the use of a specific Steam Play compatability tool'.
4. From the drop-down, select $protonge.${normal}" &&
  return
  Error "$protonge installation failed"
}

function DXVK () {
  echo "Installing DXVK..."
  flatpak run com.github.Matoking.protontricks --no-background-wineserver 244210 dxvk 1>& /dev/null &&
  return
  Error "Could not install DXVK"
}

function ContentManager () {
  echo "Creating symlink..."
  ln -sf "$STEAM_ROOT/compatibilitytools.d/config/loginusers.vdf" "$STEAMAPPS/compatdata/244210/pfx/drive_c/Program Files (x86)/Steam/config/loginusers.vdf" &&
  echo "Installing Content Manager..." &&
  wget -q "https://acstuff.club/app/latest.zip" -P "temp/" &&
  unzip -q "temp/latest.zip" -d "temp/" &&
  mv "temp/Content Manager.exe" "temp/AssettoCorsa.exe" &&
  mv -n "$STEAMAPPS/common/assettocorsa/AssettoCorsa.exe" "$STEAMAPPS/common/assettocorsa/AssettoCorsa_original.exe" &&
  rm "temp/latest.zip" &&
  cp -r "temp/"* "$STEAMAPPS/common/assettocorsa/" &&
  rm -r "temp" &&
  echo "Installing fonts required for Content Manager..." &&
  wget -q "https://files.acstuff.ru/shared/T0Zj/fonts.zip" -P "temp/" &&
  unzip -qo "temp/fonts.zip" -d "temp/" &&
  rm "temp/fonts.zip"
  cp -r "temp/system" "$STEAMAPPS/common/assettocorsa/content/fonts/" &&
  rm -r "temp/" &&
  return
  Error "Content Manager installation failed"
}

function CustomShaderPatch () {
  while :; do
    echo "${bold}1. In the 'Wine configuration' window, go to the ‘Libraries’ tab, type 'dwrite' into the ‘New override for library’ textbox and click ‘Add’.
2. Look for dwrite in the list and make sure it also says ‘native, built-in’. If it doesn’t, switch it via the ‘Edit’ menu.
3. Press ‘OK’ to close the window.${normal}"
    flatpak run com.github.Matoking.protontricks --command "wine winecfg" 244210 2> /dev/null &&
    echo "Downloading CSP..." &&
    wget -q "https://acstuff.club/patch/?get=$CSP_version" -P "temp/" &&
    echo "Installing CSP..." &&
    cd "temp/" &&
    # For some reason the downloaded file name is weird so we have to rename it
    mv "index.html?get=$CSP_version" "lights-patch-v$CSP_version.zip" -f &&
    cd .. &&
    unzip -qo "temp/lights-patch-v$CSP_version.zip" -d "temp/" &&
    rm "temp/lights-patch-v$CSP_version.zip" &&
    cp -r "temp/." "$STEAMAPPS/common/assettocorsa" &&
    rm -r "temp" &&
    break
    Error "CSP installation failed"
  done
  
  # In case Flatpak protorntricks doesn't have access to the steamlibrary
  while :; do
    echo "Installing fonts required for CSP..."
    IFS=";"
    pt_file_access=($(flatpak info --show-permissions com.github.Matoking.protontricks |
    grep filesystems | sed 's/filesystems=//'))
    unset IFS
    declare -i has_access=0
    for location in ${pt_file_access[@]}; do
      eval "location=$location" 2> /dev/null
      if [[ $STEAMAPPS == "$location"* ]]; then
        has_access=1
      fi
    done
    while (( $has_access == 0 )); do
      command="sudo flatpak override com.github.Matoking.protontricks --filesystem="${STEAMAPPS%"/STEAMAPPS"}""
      echo "Flatpak version of protontricks might not have access to ${STEAMAPPS%"/STEAMAPPS"}."
      echo "Running \"${bold}$command${normal}\""
      eval $command &&
      break
      Error "Could not acquire permissions for protontricks"
    done
    flatpak run com.github.Matoking.protontricks 244210 corefonts 1>& /dev/null &&
    return
    Error "Could not install corefonts for CSP"
  done
}

function Error () {
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

# Running functions
CheckOS
CheckFlathub
CheckDependencies
CheckSteamInstall
CheckTempDir
FindAC
StartMenuShortcut
CheckProtonGE

# Next steps will not work unless AC files have been generated
if [ ! -d "$STEAMAPPS/compatdata/244210/pfx/drive_c/Program Files (x86)/Steam/config" ]; then
  echo "Please launch Assetto Corsa with Proton-GE to generate required files before proceeding.
(it might take a while to launch)"
  exit 1
fi

Ask "Install DXVK? (might result in better performance for AMD GPUs)" && DXVK
Ask "Install Content Manager?" && ContentManager
Ask "Install CSP?" && CustomShaderPatch
echo; echo "${bold}All done!${normal}"
