# Assetto Corsa Linux Setup
A shell script based on [this](https://steamcommunity.com/sharedfiles/filedetails/?id=2828364666) guide. Works on most modern systems.

## What it does
- Installs Proton-GE
- Installs Content Manager and everything else required for it to work
- Adds Content Manager to mimeapps.list (allows opening `acmanager://` race invite links)
- Installs Custom Shaders Patch (CSP) and everything else required for it to work
- Installs DXVK

After running the script you should be able to launch Assetto Corsa from Steam with no issues (it will launch Content Manager). The original launcher is preserved as `AssettoCorsa_original.exe`.

## Instructions
1. Download Assetto Corsa on Steam.
2. Inside the terminal, run
  ```
  curl -Os https://raw.githubusercontent.com/sihawido/assettocorsa-linux-setup/main/assettocorsa-linux-setup.sh && bash assettocorsa-linux-setup.sh
  ```
> **Warning**: Always be careful when running scripts from the internet.
3. Follow every step in the console (y - stands for yes, n - stands for no).
4. Launch Assetto Corsa from Steam (it might take a while on the first run, be patient).
5. In Content Manager set the Assetto Corsa root folder to `Z:\path\to\Steam\steamapps\common\assettocorsa`.
6. In Content Manager, go to `Settings -> Content Manager -> Appearace` and check "Disable windows transparency" (fixes the full-black tooltips, pop-ups and dialogues).
7. Enjoy!

## Notes
### Fixing crashes
- Creating a Start Menu Shortcut for Content Manager might cause it to crash. This script will check if it exists and ask you if you want to delete it.  
- Opening the 'Live' tab in earlier versions of Content Manager could crash it. After that you might have a hard time since Content Manager will open this tab on start-up. You can delete the Content Manager configuration folder at `/path/to/Steam/steamapps/compatdata/244210/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager` to resolve the crash, but that will also get rid of any settings you might have saved, be sure to back it up.
- Content Manager can sometimes crash while loading a server's info, there is an [open pull request to fix it](https://github.com/gro-ove/actools/pull/114), but it's unclear whether it will be merged.
### Other
- To fix the font in Content Manager (it's Times New Roman by default) run `flatpak run com.github.Matoking.protontricks 244210 regedit` in the terminal. Then, in the opened window, go to `HKEY_CURRENT_USER\Software\Wine\Fonts\Replacements` and rename `Replacements` to `Replacements Backup`.
- To keep your Proton-GE updated consider using [ProtonUp-Qt](https://flathub.org/apps/net.davidotek.pupgui2).
