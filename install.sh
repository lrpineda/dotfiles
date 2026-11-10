#!/bin/bash
# Apply the omarchy style bundle on another Omarchy machine.
# Run from the repo root:  ./install.sh
# Only the files listed in CONFIG_FILES are installed; the older .conf/waybar
# files in this repo predate Omarchy's Lua/Quickshell switch and are skipped.
# Every file it overwrites is backed up to <file>.bak.<timestamp> first.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
TS=$(date +%s)

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

step "Packages (MesloLGS Nerd Font for ghostty, ble.sh for autosuggestions)"
omarchy pkg add ttf-meslo-nerd
omarchy pkg aur add blesh-git

CONFIG_FILES=(
  hypr/looknfeel.lua hypr/windows.lua
  ghostty/config ghostty/shaders
  alacritty/alacritty.toml kitty/kitty.conf
  omarchy/branding omarchy/backgrounds
  omarchy/plugins/lrpineda.rebel-menu omarchy/plugins/lrpineda.media-card omarchy/plugins/lrpineda.power
)

install_file() { # $1 = source file, $2 = destination
  local f=$1 dest=$2
  mkdir -p "$(dirname "$dest")"
  if [[ -e $dest ]] && ! cmp -s "$f" "$dest"; then
    cp -a "$dest" "$dest.bak.$TS"
  fi
  cp -a "$f" "$dest"
}

step "Copying config files (backing up anything replaced)"
cd "$HERE"
for entry in "${CONFIG_FILES[@]}"; do
  find "$entry" -type f | while read -r f; do install_file "$f" "$HOME/.config/$f"; done
done
cd "$HERE/home"
find . -type f | while read -r f; do install_file "$f" "$HOME/${f#./}"; done
chmod +x "$HOME/.local/bin/quick-terminal"

step "Third-party bar plugins (weather radar, herdr)"
P=$HOME/.config/omarchy/plugins
[[ -d $P/eduardodallecort.weather-radar ]] || git clone https://github.com/eduardodallecort/omarchy-weather-radar.git "$P/eduardodallecort.weather-radar"
[[ -d $P/io.github.fabean.herdr ]] || git clone https://github.com/fabean/omarchy-herdr.git "$P/io.github.fabean.herdr"

step "Bar layout (copied last: the shell drops layout entries for plugins it has not discovered yet)"
sleep 2
[[ -e $HOME/.config/omarchy/shell.json ]] && cp -a "$HOME/.config/omarchy/shell.json" "$HOME/.config/omarchy/shell.json.bak.$TS"
cp "$HERE/omarchy/shell.json" "$HOME/.config/omarchy/shell.json"

step "Hyprland: PiP pinning + quick-terminal binding"
H=$HOME/.config/hypr
grep -q 'require("hypr.windows")' "$H/hyprland.lua" || {
  cp -a "$H/hyprland.lua" "$H/hyprland.lua.bak.$TS"
  printf '\nrequire("hypr.windows")\n' >> "$H/hyprland.lua"
}
grep -q 'org.quickterm' "$H/bindings.lua" || {
  cp -a "$H/bindings.lua" "$H/bindings.lua.bak.$TS"
  printf '\n' >> "$H/bindings.lua"
  cat "$HERE/hypr/bindings-quickterm.lua" >> "$H/bindings.lua"
}

step "bash: hook up ble.sh"
if ! grep -q 'blesh/ble.sh' "$HOME/.bashrc"; then
  cp -a "$HOME/.bashrc" "$HOME/.bashrc.bak.$TS"
  # load (noattach) right after the non-interactive early return...
  sed -i '/^\[\[ \$- != \*i\* \]\] && return/a\
\
# ble.sh: fish-style autosuggestions. Must load before the omarchy rc.\
[[ -f /usr/share/blesh/ble.sh ]] \&\& source /usr/share/blesh/ble.sh --noattach' "$HOME/.bashrc"
  # ...and attach on the very last line.
  printf '\n# Hand the line editor over to ble.sh. Must be the LAST line in this file.\n[[ ${BLE_VERSION-} ]] && ble-attach\n' >> "$HOME/.bashrc"
fi

step "Theme + wallpaper"
omarchy theme set catppuccin
omarchy theme bg set "$HOME/.config/omarchy/backgrounds/catppuccin/a_graphic_of_a_wave.png"

step "Reloading"
hyprctl reload >/dev/null && hyprctl configerrors
omarchy restart shell
omarchy restart terminal

echo
echo "Done. Open a new terminal to get ble.sh. Backups are *.bak.$TS."
