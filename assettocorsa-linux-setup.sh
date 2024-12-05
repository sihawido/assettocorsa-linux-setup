# Checking compatability
OS="$(cat /etc/os-release | grep ID=* -w | sed "s/ID=//g")"
if [ $OS != "fedora" ] && [ $OS != "ubuntu" ] && [ $OS != "debian" ]; then
  echo $OS is not currently supported.
  exit 1
fi
# Checking if required software is installed
if [ $OS == "fedora" ]; then
  installed="$(dnf list --installed | grep protontricks)"
  if [[ $installed != *"protontricks"* ]]; then
    echo "Protontricks is missing, run ${bold}sudo dnf install protontricks${normal} to install."
    exit 1
  fi
fi
if [ $OS == "debian" ] || [ $OS == "ubuntu" ]; then
  installed="$(apt list --installed | grep protontricks)"
  if [[ $installed != *"protontricks"* ]]; then
    echo "Protontricks is missing, run ${bold}sudo apt install protontricks${normal} to install."
    exit 1
  fi
fi
flatpak_apps=($(flatpak list --columns=application))
if [[ ${flatpak_apps[@]} != *"com.github.Matoking.protontricks"* ]]; then
  echo "Flatpak version of protontricks is missing, run ${bold}flatpak install com.github.Matoking.protontricks${normal} to install."
  exit 1
fi; if [[ ${flatpak_apps[@]} != *"net.davidotek.pupgui2"* ]]; then
  echo "ProtonUp-Qt is missing, consider installing it to update the Proton-GE version from time to time.
Hint: ${bold}flatpak install net.davidotek.pupgui2${normal} to install."
fi
echo Pre-requisites are installed.

# Defining text styles
bold=$(tput bold)
normal=$(tput sgr0)

# Defining function
function Ask {
  while true; do
    read -p "$* [y/n]: " yn
    case $yn in
      [Yy]*) return 0  ;;  
      [Nn]*) echo "Skipping" ; return  1 ;;
    esac
  done
}

function ProtonGE () {
  echo "Installing Proton-GE..."
  mkdir "temp"
  wget -P "temp/" "https://github.com/GloriousEggroll/proton-ge-custom/releases/latest/download/GE-Proton$GE_version.tar.gz"
  tar -xzf "temp/GE-Proton$GE_version.tar.gz" --directory "temp/"
  cp -r "temp/GE-Proton$GE_version" "$HOME/.steam/root/compatibilitytools.d"
  rm -rf "temp/"
  echo; echo "Restart Steam for Proton-GE to appear as an option. Go to Assetto Corsa -> Properties -> Compatability. Turn on \"Force the use of a specific Steam Play compatability tool\". From the drop-down, select GE-Proton$GE_version."
}

function ContentManager () {
	echo "Installing Content Manager..."
	wget "https://acstuff.ru/app/latest.zip"
	unzip "latest.zip" -d "temp"
	mv "temp/Content Manager.exe" "temp/AssettoCorsa.exe"
	mv "$HOME/.local/share/Steam/steamapps/common/assettocorsa/AssettoCorsa.exe" "$HOME/.local/share/Steam/steamapps/common/assettocorsa/AssettoCorsa_original.exe"
	mv "temp/AssettoCorsa.exe" "$HOME/.local/share/Steam/steamapps/common/assettocorsa/"
	mv "temp/Manifest.json" "$HOME/.local/share/Steam/steamapps/common/assettocorsa/"
	rm -r "latest.zip" "temp"
}

function CustomShaderPatch () {
  echo; echo "${bold}Go to the ‘Libraries’-tab, type dwrite into the ‘New override for library’-textbox and click ‘Add’.
Look for dwrite in the list and make sure it also says ‘native, built-in’. If it doesn’t, switch it via the ‘Edit’ menu.
Press ‘OK’ to close the window.${normal}"; echo
  # Using non-flatpak version here since the flatpak version doesn't seem to work
  protontricks -c winecfg 244210
}

function InstallFonts () {
  # Using flatpak version here since the native version has bugs preventing this from working
  flatpak run com.github.Matoking.protontricks 244210 corefonts
  wget https://files.acstuff.ru/shared/T0Zj/fonts.zip
  unzip -u "fonts.zip" -d "temp"
  cp -r "temp/system" "$HOME/.local/share/Steam/steamapps/common/assettocorsa/content/fonts/"
  rm -r "fonts.zip" "temp"
}

flatpak_remotes="$(flatpak remotes)"
if [[ $flatpak_remotes != *"flathub"* ]]; then
  echo Flatpak is either not installed or the Flathub remote is not configured.
  echo Refer to ${bold}https://flathub.org/setup${normal} to set-up Flatpak.
  exit 1
fi

GE_version="9-20"

# Running function
Ask "Install Proton-GE?" && ProtonGE
Ask "Install Content Manager?" && ContentManager
Ask "Apply CSP tweaks?" && CustomShaderPatch
Ask "Install required fonts?" && InstallFonts
