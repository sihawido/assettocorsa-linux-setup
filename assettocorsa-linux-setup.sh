# Checking compatability
OS="$(cat /etc/os-release | grep ID=* -w | sed "s/ID=//g")"
if [ $OS != "fedora" ] && [ $OS != "ubuntu" ] && [ $OS != "debian" ]; then
  echo $OS is not currently supported.
  exit 1
fi

# Useful variables
GE_version="9-20"
Steamapps="$HOME/.local/share/Steam/steamapps"

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
# Checking if Steam is installed through Flatpak
flatpak_apps=($(flatpak list --columns=application))
if [[ ${flatpak_apps[@]} == *"com.valvesoftware.Steam"* ]]; then
  echo "You have a Flatpak version of Steam installed, which is not currently supported."
  exit 1
fi

# Checking if required packages are installed for Fedora
if [ $OS == "fedora" ]; then
  installed="$(dnf list --installed)"
  if [[ $installed != *"steam"* ]]; then
    echo "Steam is not installed, run ${bold}sudo dnf install steam${normal} to install."
    exit 1
  fi
  if [[ $installed != *"protontricks"* ]]; then
    echo "Protontricks is not installed, run ${bold}sudo dnf install protontricks${normal} to install."
    exit 1
  fi
fi

# Checking if required packages are installed for Debian and Ubuntu
if [ $OS == "debian" ] || [ $OS == "ubuntu" ]; then
  installed="$(apt list --installed)"
  if [[ $installed != *"steam"* ]]; then
    echo "Steam is not installed, run ${bold}sudo apt install steam${normal} to install."
    exit 1
  fi
  if [[ $installed != *"protontricks"* ]]; then
    echo "Protontricks is missing, run ${bold}sudo apt install protontricks${normal} to install."
    exit 1
  fi
fi
if [[ ${flatpak_apps[@]} != *"com.github.Matoking.protontricks"* ]]; then
  echo "Flatpak version of protontricks is missing, run ${bold}flatpak install com.github.Matoking.protontricks${normal} to install."
  exit 1
fi
echo "Pre-requisites are installed."

# Checking if Assetto Corsa is installed
if ! [[ -d $Steamapps/common/assettocorsa ]]; then
  echo "Error: Assetto Corsa is either not installed or not in the default path."
  exit 1
fi
echo "Assetto Corsa is installation found."

# Defining functions
function ProtonGE () {
  echo "Installing Proton-GE..."
  mkdir "temp"
  wget -q -P "temp/" "https://github.com/GloriousEggroll/proton-ge-custom/releases/latest/download/GE-Proton$GE_version.tar.gz"
  tar -xzf "temp/GE-Proton$GE_version.tar.gz" --directory "temp/"
  echo; echo "Copying Proton-GE requires root privileges."
  sudo cp -r "temp/GE-Proton$GE_version" "$HOME/.steam/root/compatibilitytools.d"
  rm -rf "temp/"
  echo "Proton-GE is installed."
  echo; echo "${bold}Restart Steam. Go to Assetto Corsa > Properties > Compatability. Turn on \"Force the use of a specific Steam Play compatability tool\". From the drop-down, select GE-Proton$GE_version.${normal}"; echo
}

function Symlink () {
  echo "Creating symlink..."
  ln -sf "$HOME/.steam/root/config/loginusers.vdf" "$Steamapps/compatdata/244210/pfx/drive_c/Program Files (x86)/Steam/config/loginusers.vdf"
}

function ContentManager () {
	echo "Installing Content Manager..."
	wget -q "https://acstuff.ru/app/latest.zip"
	unzip -q "latest.zip" -d "temp"
	mv "temp/Content Manager.exe" "temp/AssettoCorsa.exe"
	mv "$Steamapps/common/assettocorsa/AssettoCorsa.exe" "$HOME/.local/share/Steam/steamapps/common/assettocorsa/AssettoCorsa_original.exe"
	cp "temp/AssettoCorsa.exe" "$Steamapps/common/assettocorsa/"
	cp "temp/Manifest.json" "$Steamapps/common/assettocorsa/"
	rm -r "latest.zip" "temp"
}

function dxvk () {
  protontricks --no-background-wineserver 244210 dxvk
}

function CustomShaderPatch () {
  echo; echo "${bold}In the opened window, go to the ‘Libraries’ tab, type dwrite into the ‘New override for library’ textbox and click ‘Add’.
Look for dwrite in the list and make sure it also says ‘native, built-in’. If it doesn’t, switch it via the ‘Edit’ menu.
Press ‘OK’ to close the window.${normal}"; echo
  # Using non-flatpak version here since the flatpak version doesn't seem to work
  protontricks -c winecfg 244210
}

function InstallFonts () {
  echo "Installing required fonts..."
  wget -q https://files.acstuff.ru/shared/T0Zj/fonts.zip
  unzip -q "fonts.zip" -d "temp"
  cp -r "temp/system" "$Steamapps/common/assettocorsa/content/fonts/"
  rm -r "fonts.zip" "temp"
  # Using flatpak version here since the native version has bugs preventing this from working
  flatpak run com.github.Matoking.protontricks 244210 corefonts
}

function Ask {
  while true; do
    read -p "$* [y/n]: " yn
    case $yn in
      [Yy]*) return 0  ;;  
      [Nn]*) echo "Skipping" ; return  1 ;;
    esac
  done
}

# Asking to run function
Ask "Install Proton-GE?" && ProtonGE
Ask "Create symlink required for Content Manager?" && Symlink
Ask "Install Content Manager?" && ContentManager
Ask "Set-up DXVK (might result in better performance for AMD GPUs)?" && dxvk
Ask "Apply CSP tweaks?" && CustomShaderPatch
Ask "Install required fonts?" && InstallFonts
