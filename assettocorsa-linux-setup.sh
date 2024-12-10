# Checking compatability
OS="$(cat /etc/os-release | grep ID=* -w | sed "s/ID=//g")"
if [ $OS == "fedora" ] || [ $OS == "ultramarine" ]; then pm_install="dnf install"
elif [ $OS == "debian" ] || [ $OS == "ubuntu" ] || [ $OS == "linuxmint" ]; then pm_install="apt install"
elif [ $OS == "arch" ] || [ $OS == "endeavouros" ]; then pm_install="pacman -S"
else echo "$OS is not currently supported. Feel free to open an issue to support it."; exit 1; fi

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
if [[ ${installed_flatpaks[@]} == *"com.valvesoftware.Steam"* ]]; then
  echo "You have a Flatpak version of Steam installed, which is not currently supported."
  exit 1
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

# Checking if Assetto Corsa is installed
function Ask {
  while true; do
    read -p "$* [y/n]: " yn
    case $yn in
      [Yy]*) return 0 ;;  
      [Nn]*) echo "Aborting..." ; exit 1 ;;
    esac
  done
}
# Searching the home directory first, then external disks
echo "Looking for Assetto Corsa installation..."
ac_dir="$(find $HOME -type d -name assettocorsa -not -path ".compatdata*")"
if [[ $ac_dir == "" ]]; then
  ac_dir="$(find /mnt -type d -name assettocorsa -not -path ".compatdata*")"
  if [[ $ac_dir == "" ]]; then
    ac_dir="$(find /run -type d -name assettocorsa -not -path ".compatdata*")"
    if [[ $ac_dir == "" ]]; then
      ac_dir="$(find /var/run -type d -name assettocorsa -not -path ".compatdata*")"
      if [[ $ac_dir == "" ]]; then
        echo "Assetto Corsa installation not found."
        exit 1
      fi
    fi
  fi
fi
Ask "Found ${bold}$ac_dir${normal}, is the right location?" && Steamapps=${ac_dir%"/common/assettocorsa"}

# Defining functions
function ProtonGE () {
  echo "Installing Proton-GE..."
  mkdir "temp" -p
  wget -q "https://github.com/GloriousEggroll/proton-ge-custom/releases/latest/download/GE-Proton$GE_version.tar.gz" -P "temp/"
  tar -xzf "temp/GE-Proton$GE_version.tar.gz" -C "temp/"
  echo; echo "Copying Proton-GE requires root privileges."
  sudo cp -ra "temp/GE-Proton$GE_version" "$HOME/.steam/root/compatibilitytools.d"
  rm -rf "temp/"
  echo "Proton-GE is installed."
  echo; echo "${bold}Restart Steam. Go to Assetto Corsa > Properties > Compatability. Turn on \"Force the use of a specific Steam Play compatability tool\". From the drop-down, select GE-Proton$GE_version.${normal}"; echo
}

function dxvk () {
  flatpak run com.github.Matoking.protontricks --no-background-wineserver 244210 dxvk
  echo
}

function Symlink () {
  echo "Creating symlink..."
  ln -sf "$HOME/.steam/root/config/loginusers.vdf" "$Steamapps/compatdata/244210/pfx/drive_c/Program Files (x86)/Steam/config/loginusers.vdf"
}

function ContentManager () {
  echo "Installing Content Manager..."
  mkdir "temp" -p
  wget -q "https://acstuff.ru/app/latest.zip" -P "temp/"
  unzip -q "temp/latest.zip" -d "temp/"
  mv "temp/Content Manager.exe" "temp/AssettoCorsa.exe"
  mv "$Steamapps/common/assettocorsa/AssettoCorsa.exe" "$Steamapps/common/assettocorsa/AssettoCorsa_original.exe"
  cp "temp/AssettoCorsa.exe" "$Steamapps/common/assettocorsa/"
  cp "temp/Manifest.json" "$Steamapps/common/assettocorsa/"
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
  cp -r "temp/." "$Steamapps/common/assettocorsa"
  rm -r "temp"
}

function Fonts () {
  echo "Installing required fonts..."
  mkdir "temp" -p
  wget -q "https://files.acstuff.ru/shared/T0Zj/fonts.zip" -P "temp/"
  unzip -qo "temp/fonts.zip" -d "temp/"
  cp -r "temp/system" "$Steamapps/common/assettocorsa/content/fonts/"
  rm -r "temp/"
  # Flatpak protorntricks doesn't have access to /mnt
  if [[ $Steamapps != "$HOME"* ]]; then
    echo "Flatpak version of protontricks might not have access to this location."
    echo "Running \"${bold}sudo flatpak override com.github.Matoking.protontricks --filesystem=${Steamapps%"/steamapps"}${normal}\""
    sudo flatpak override com.github.Matoking.protontricks --filesystem="${Steamapps%"/steamapps"}"
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

if [ -f "$Steamapps/compatdata/244210/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Content Manager.lnk" ]; then
  echo "Start Menu Shortcut for Content Manager found. This might be causing crashes on start-up."
  Ask "Delete the shortcut?" && rm "$Steamapps/compatdata/244210/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Content Manager.lnk"
fi

# Asking to run function
Ask "Install Proton-GE?" && ProtonGE
Ask "Install DXVK? (might result in better performance for AMD GPUs)" && dxvk
Ask "Create symlink required for Content Manager?" && Symlink
Ask "Install Content Manager?" && ContentManager
Ask "Install CSP?" && CustomShaderPatch
Ask "Install required fonts?" && Fonts
