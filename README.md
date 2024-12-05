# Assetto Corsa Linux Setup
A shell script based on [this](https://steamcommunity.com/sharedfiles/filedetails/?id=2828364666) guide. Should work on most modern systems. Has not been tested with the Flatpak version of Steam!

# What it does
The bash script installs Proton-GE, Content Manager, asks you to apply some tweaks for CSP, and installs all the required fonts. After running the script you should be able to launch Assetto Corsa from Steam with no issues (it will launch Content Manager). The original launcher is preserved in `~/.local/share/Steam/steamapps/common/assettocorsa` as `AssettoCorsa_original.exe`.

# Instructions
1. Download Assetto Corsa on Steam
2. Download "assettocorsa-linux-setup.sh" (Click on the `assettocorsa-linux-setup.sh` file and press "Download raw file")
3. Open the terminal and run `bash assettocorsa-linux-setup.sh` in the same directory as the downloaded file (`cd` to change current directory)
4. Follow every step in the console (y - stands for yes, n - stands for no)
5. Launch Assetto Corsa from Steam (it might take a while on the first run, be patient)
6. In content manager set "Assetto Corsa folder" to Z:\home\YOUR-USERNAME\.local\share\Steam\steamapps\common\assettocorsa
7. Enjoy!

### Warning
Opening the "Live" tab in Content Manager might crash it. After that you might have a hard time since Content Manager will open this tab on start-up. You can delete the Content Manager configuration directory at `~/.local/share/Steam/steamapps/compatdata/244210/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager` to resolve the crash, but that will also get rid of any settings you might have saved, be sure to back it up.
