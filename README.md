# Assetto Corsa Linux Setup

A shell script based on [this](https://steamcommunity.com/sharedfiles/filedetails/?id=2828364666) guide. Works on most modern systems.

## What it does

- Installs [Proton-GE](https://github.com/GloriousEggroll/proton-ge-custom)
- Installs [Content Manager](https://assettocorsa.club/content-manager.html) and everything else required for it to work
- Adds an `acmanager://` URI handler for opening race invite links in Content Manager
- Installs [Custom Shaders Patch (CSP)](https://acstuff.club/patch/) and everything else required for it to work
- Installs [DXVK](https://github.com/doitsujin/dxvk)
- Optionally installs [SimHub](https://github.com/SHWotever/SimHub) into Assetto Corsa's Proton prefix
- Optionally installs the Apple CarPlay SimHub dashboard addon when the required addon zip files are provided

After running the script you should be able to launch Assetto Corsa from Steam with no issues (it will launch Content Manager). The original launcher is preserved as `AssettoCorsa_original.exe`.

## Instructions

1. Download Assetto Corsa on Steam.
2. Inside the terminal, run

  ```
  curl -Os https://raw.githubusercontent.com/sihawido/assettocorsa-linux-setup/main/assettocorsa-linux-setup.sh && bash assettocorsa-linux-setup.sh
  ```

> [!WARNING]
> Always be careful when running scripts from the internet.
1. Follow every step in the console (y - stands for yes, n - stands for no).

> [!NOTE]
> If you encounter an error with protontricks, something like `SyntaxError: Invalid file magic number`, use [pipx to install a more up-to-date version](https://github.com/Matoking/protontricks?tab=readme-ov-file#pipx) ([#33](https://github.com/sihawido/assettocorsa-linux-setup/issues/33)).
1. Launch Assetto Corsa from Steam (it might take a while on the first run, be patient).
2. In Content Manager set the Assetto Corsa root folder to `Z:\path\to\Steam\steamapps\common\assettocorsa`.
3. In Content Manager, go to `Settings -> Content Manager -> Appearace` and check "Disable windows transparency" (fixes the full-black tooltips, pop-ups and dialogues).
4. If you installed SimHub, start Assetto Corsa first from Steam/Content Manager, then start SimHub:

  ```
  ~/.local/bin/simhub
  ```
1. Enjoy!

## Installing the Apple CarPlay SimHub addon

The CarPlay addon install is offered only after SimHub is installed into Assetto Corsa's Proton prefix. If you skipped SimHub on the first run, run the setup script again and choose the SimHub install step first.

Before accepting the CarPlay addon prompt, download the addon files and put both zip files in the same folder:

- `Apple-CarPlay.zip`
- `SimHubUDPConnector.zip`

When the script asks for the folder containing those files, enter that folder path. The default path is:

```
~/Downloads/Assetto Downloads/Carplay
```

The script installs the SimHub dashboard, the UDP connector plugin and Assetto Corsa app, the CarPlay torque extension, required font, and Content Manager preview presets when Content Manager's config folder already exists.

After the install finishes:

1. Start Assetto Corsa from Steam/Content Manager first, then start SimHub with `~/.local/bin/simhub`.
2. In AC/CSP, enable the SimHub UDPConnector extension and activate `TorquePowerExtensionMy`.
3. In SimHub, enable Media Information and set the dashboard's simulated keys to match your Assetto Corsa controls.
4. In Content Manager, generate previews twice using `preview_light` and `preview_nolight`.

## Notes

### Fixing crashes

- Having Assetto Corsa installed on a NTFS partition can cause many issues, including crashes. The only solution is to install Assetto Corsa on a partition with a proper linux filesystem (i.e. ext4 or btrfs).
- Creating a Start Menu Shortcut for Content Manager might cause it to crash. This script will check if it exists and ask whether you want to delete it.
- Opening the 'Live' tab in earlier versions of Content Manager could cause a crash. After that you might have a hard time since Content Manager will open that tab on start-up. You can delete the Content Manager configuration folder at `/path/to/Steam/steamapps/compatdata/244210/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager` to resolve the crash, but that will also get rid of any settings you might have saved, be sure to back it up.
- Content Manager can sometimes crash while loading a server's info, there is an [open pull request to fix it](https://github.com/gro-ove/actools/pull/114), but it's unclear whether it will ever be merged.

### Other

- Race invite links using the `acmanager://` scheme should open through Content Manager. When Content Manager is closed, the handler starts it through Steam. When Content Manager is already open, the handler tries to pass the invite directly to Content Manager inside the existing Proton prefix. If a specific invite source still fails, copy the `ip` and `httpPort` values from the link and search for `ip:httpPort` in Content Manager's server browser.
- To fix the font in Content Manager (it's Times New Roman by default) run `protontricks 244210 regedit` in the terminal. Then, in the opened window, go to `HKEY_CURRENT_USER\Software\Wine\Fonts\Replacements` and rename the `Replacements` key to `Replacements Backup`.
- SimHub is installed into Assetto Corsa's compatibility prefix and should be started after Assetto Corsa. Starting SimHub first and then launching Assetto Corsa from SimHub can prevent Steam from launching the game correctly.
