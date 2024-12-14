# Checking compatability
OS_name="$(cat /etc/os-release | grep NAME=* -w | sed "s/NAME=//g")"
OS="$(cat /etc/os-release | grep ID=* -w | sed "s/ID=//g")"
if [ $OS == "fedora" ] || [ $OS == "ultramarine" ]; then pm_install="dnf install"
elif [ $OS == "debian" ] || [ $OS == "ubuntu" ] || [ $OS == "linuxmint" ] || [ $OS == "pop" ]; then pm_install="apt install"
elif [ $OS == "arch" ] || [ $OS == "endeavouros" ]; then pm_install="pacman -S"
else echo "$OS_name is not currently supported. Feel free to open an issue to support it."; exit 1; fi

# Useful variables
GE_version="9-20"
CSP_version="0.2.4"

# Defining text styles for readablity
bold=$(tput bold)
normal=$(tput sgr0)

# Checking if Flatpak is set up
flatpak_remotes="$(flatpak remotes)"
if [[ $flatpak_remotes != *"flathub"* ]]; then
  echo "Flatpak is either not installed or the Flathub remote is not configured.
Refer to ${bold}https://flathub.org/setup${normal} to set-up Flatpak."
  exit 1
fi

installed_packages=($(ls /bin))
installed_packages+=($(ls /usr/bin))
installed_flatpaks=($(flatpak list --columns=application))
req_packages=("steam" "wget2" "unzip")
req_flatpaks=("protontricks")

# Checking if Steam is installed through Flatpak
function set_to_native () {
  default_ac_path="$HOME/.local/share/Steam/steamapps/common/assettocorsa"
  STEAM_ROOT="$HOME/.steam/root"
  steam_command="steam"
}; function set_to_flatpak () {
  default_ac_path="$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/assettocorsa"
  STEAM_ROOT="$HOME/.var/app/com.valvesoftware.Steam/.steam/root"
  steam_command="flatpak run com.valvesoftware.Steam"
}

if [[ ${installed_packages[@]} == *"steam"* ]] && [[ ${installed_flatpaks[@]} == *"com.valvesoftware.Steam"* ]]; then
  echo "Steam is installed both as a native package and through Flatpak."
  PS3="Select version to use: "
  select installation_method in "Native" "Flatpak"
  do
    installation_method="$(echo ${installation_method,,} | awk '{print $1;}')"
    if [ $installation_method == "native" ]; then
      set_to_native
      break
    elif [ $installation_method == "flatpak" ]; then
      set_to_flatpak
      break
    fi
  done
elif [[ ${installed_packages[@]} == *"steam"* ]]; then
  echo "Native install of Steam found."
  set_to_native
elif [[ ${installed_flatpaks[@]} == *"com.valvesoftware.Steam"* ]]; then
  echo "Flatpak install of Steam found."
  set_to_flatpak
fi

# Checking if required packages are installed
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
echo "Dependencies found."

# Defining functions
function enter_manually () {
  Ask "Enter path to ${bold}steamapps/common/assettocorsa${normal} manually?" && read ac_dir
  if [[ $ac_dir == "" ]]; then
    exit 1
  elif [ -d $ac_dir ] && [[ $(echo $ac_dir | sed -e 's/.*assettocorsa/assettocorsa/') == "assettocorsa" ]]; then
    echo "Directory valid. Proceeding."
  else
    echo "Invalid directory. Exiting."
    exit 1
  fi
}
function FindAC () {
  if [ -d $default_ac_path ]; then
    echo "Found ${bold}$default_ac_path${normal}."
    Ask "Is that the right installation?" && STEAMAPPS="${default_ac_path%"/common/assettocorsa"}"
    if [[ $STEAMAPPS == "" ]]; then
      enter_manually
    fi
  else
    echo "Could not find Asseto Corsa in the default path."
    enter_manually
  fi
}

function StartMenuShortcut () {
  if [ -f "$STEAMAPPS/compatdata/244210/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Content Manager.lnk" ]; then
    echo "Start Menu Shortcut for Content Manager found. This might be causing crashes on start-up."
    Ask "Delete the shortcut?" && rm "$STEAMAPPS/compatdata/244210/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Content Manager.lnk"
  fi
}

function ProtonGE () {
  echo "Installing Proton-GE..."
  mkdir "temp" -p
  wget -q "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton$GE_version/GE-Proton$GE_version.tar.gz" -P "temp/"
  tar -xzf "temp/GE-Proton$GE_version.tar.gz" -C "temp/"
  echo; echo "Copying Proton-GE requires root privileges."
  sudo cp -ra "temp/GE-Proton$GE_version" "$STEAM_ROOT/compatibilitytools.d"
  rm -rf "temp/"
  echo "Proton-GE is installed."
  echo; echo "${bold}Restart Steam. Go to Assetto Corsa > Properties > Compatability. Turn on \"Force the use of a specific Steam Play compatability tool\". From the drop-down, select GE-Proton$GE_version.${normal}"; echo
}

function dxvk () {
  flatpak run com.github.Matoking.protontricks --no-background-wineserver 244210 dxvk
  echo
}

function ContentManager () {
  echo "Creating symlink..."
  ln -sf "$STEAM_ROOT/compatibilitytools.d/config/loginusers.vdf" "$STEAMAPPS/compatdata/244210/pfx/drive_c/Program Files (x86)/Steam/config/loginusers.vdf"
  
  echo "Installing Content Manager..."
  mkdir "temp" -p
  wget -q "https://acstuff.ru/app/latest.zip" -P "temp/"
  unzip -q "temp/latest.zip" -d "temp/"
  mv "temp/Content Manager.exe" "temp/AssettoCorsa.exe"
  mv "$STEAMAPPS/common/assettocorsa/AssettoCorsa.exe" "$STEAMAPPS/common/assettocorsa/AssettoCorsa_original.exe"
  cp "temp/AssettoCorsa.exe" "$STEAMAPPS/common/assettocorsa/"
  cp "temp/Manifest.json" "$STEAMAPPS/common/assettocorsa/"
  rm -r "temp"
}

function CustomShaderPatch () {
  echo "${bold}In the opened window, go to the ‘Libraries’ tab, type 'dwrite' into the ‘New override for library’ textbox and click ‘Add’.
Look for dwrite in the list and make sure it also says ‘native, built-in’. If it doesn’t, switch it via the ‘Edit’ menu.
Press ‘OK’ to close the window.${normal}"; echo
  flatpak run com.github.Matoking.protontricks --command "wine winecfg" 244210; echo
  echo "Installing CSP..."
  mkdir "temp" -p
  wget -q "https://acstuff.club/patch/?get=$CSP_version" -P "temp/"
  cd "temp/"
  # For some reason the downloaded file name is weird so we have to rename it
  mv "index.html?get=$CSP_version" "lights-patch-v$CSP_version.zip" -f
  cd ..
  unzip -qo "temp/lights-patch-v$CSP_version.zip" -d "temp/"
  rm "temp/lights-patch-v$CSP_version.zip"
  cp -r "temp/." "$STEAMAPPS/common/assettocorsa"
  rm -r "temp"
}

function Fonts () {
  echo "Installing required fonts..."
  mkdir "temp" -p
  wget -q "https://files.acstuff.ru/shared/T0Zj/fonts.zip" -P "temp/"
  unzip -qo "temp/fonts.zip" -d "temp/"
  cp -r "temp/system" "$STEAMAPPS/common/assettocorsa/content/fonts/"
  rm -r "temp/"
  # Flatpak protorntricks doesn't have access to /mnt
  if [[ $STEAMAPPS != "$HOME"* ]]; then
    echo "Flatpak version of protontricks might not have access to this location."
    echo "Running \"${bold}sudo flatpak override com.github.Matoking.protontricks --filesystem=${STEAMAPPS%"/STEAMAPPS"}${normal}\""
    sudo flatpak override com.github.Matoking.protontricks --filesystem="${STEAMAPPS%"/STEAMAPPS"}"
  fi
  flatpak run com.github.Matoking.protontricks 244210 corefonts
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

# Asking to run function
FindAC
StartMenuShortcut
Ask "Install Proton-GE?" && ProtonGE
if [ ! -d "$STEAMAPPS/compatdata/244210/pfx/drive_c/Program Files (x86)/Steam/config" ]; then
  echo "Please launch Assetto Corsa with Proton-GE to generate required files before proceeding.
(it might take a while to launch)"
  exit 1
fi
Ask "Install DXVK? (might result in better performance for AMD GPUs)" && dxvk
Ask "Install Content Manager?" && ContentManager
Ask "Install CSP?" && CustomShaderPatch
Ask "Install required fonts?" && Fonts
