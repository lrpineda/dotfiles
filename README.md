# dotfiles

Mirrors `~/.config` at the repo root; `home/` mirrors `~`.

## Omarchy style setup

On a fresh Omarchy machine:

    git clone https://github.com/lrpineda/dotfiles ~/Projects/dotfiles
    cd ~/Projects/dotfiles && ./install.sh

The older `hypr/*.conf` and `waybar/` files predate Omarchy's move to Lua
config and the Quickshell bar; `install.sh` does not touch them.

The script backs up every file it replaces as `<file>.bak.<timestamp>`.

## What's included

**Windows (Hyprland)**
- [x] Rounded corners (6px) + frosted-glass blur, limited to terminals: `hypr/looknfeel.lua`
- [x] Picture-in-picture windows stay pinned across workspaces: `hypr/windows.lua` (the script adds the `require` to hyprland.lua)
- [x] Dropdown terminal on CTRL+` : `~/.local/bin/quick-terminal` + a snippet appended to `hypr/bindings.lua`

**Terminals**
- [x] Ghostty: MesloLGS Nerd Font at 11, 50% transparent background, bar cursor, tighter padding, shaders (cursor smear, blaze, party sparks, transparent CRT). Shell integration off for ble.sh.
- [x] Alacritty / Kitty: font size 11
- [x] ble.sh fish-style autosuggestions (`blesh-git` from AUR, `~/.blerc`, two lines added to `~/.bashrc`)
- [x] Package `ttf-meslo-nerd`

**Bar (Omarchy shell)**
- [x] `shell.json`: transparent bar, 12-hour clock with world cities and life-progress, bar layout
- [x] Rebel starbird menu button: `lrpineda.rebel-menu`
- [x] Now-playing card with album art: `lrpineda.media-card`
- [x] Battery capsule + power stats: `lrpineda.power`
- [x] Weather radar and herdr widgets (cloned from GitHub)
- [x] Custom screensaver/about ASCII art: `omarchy/branding/`

**Theme**
- [x] Catppuccin (stock theme, applied with `omarchy theme set catppuccin`)

## Left out on purpose (specific to this laptop)

- `monitors.lua`: different screens
- `input.lua`: touchpad/keyboard tweaks. Copy it by hand if you want natural scrolling and the 3-finger workspace swipe.
- Touchscreen gestures (hyprgrass, `touchscreen.lua`, the `rebuild-hypr-plugins` hook): only useful on a touchscreen
- Audio idle-inhibitor, lid-wake fix, MSI power notes: hardware workarounds
- Work/personal account split: agent PATH override, `omarchy-agent-usage-claude-work` timer, git/gh identity
- herdr app config, dictation and voxtype, kimi, opencode

## Check after installing

- The quick-terminal size (`1840 x 1035` px in bindings.lua) was picked for a 4K screen at 1.25 scale. On a different screen, change it to about 60% of the logical resolution.
- The herdr widget does nothing unless the `herdr` app is installed. Remove it with `omarchy plugin disable io.github.fabean.herdr`.
- If a widget is missing from the bar, run `omarchy plugin disable <id>` and then `omarchy plugin enable <id> --section …` to resync the layout.
- Ghostty only re-reads its config after `omarchy restart terminal`, which the script runs.
