-- Dropdown terminal on CTRL + grave. Hyprland owns the toggle because
-- ghostty's own quick terminal needs a `global:` keybind, and the
-- GlobalShortcuts portal rejects unsandboxed apps here. See
-- ~/.local/bin/quick-terminal for the full explanation.
o.window("org.quickterm", { workspace = "special:quickterm" })
o.window("org.quickterm", { float = true })
o.window("org.quickterm", { center = true })
-- Pixels, not percentages: the rule silently does nothing when given "60%".
-- Both monitors are 3840x2160 at scale 1.25, so this is ~60% of the 3072x1728
-- logical size.
o.window("org.quickterm", { size = { 1840, 1035 } })

o.bind("CTRL + GRAVE", "Quick terminal", os.getenv("HOME") .. "/.local/bin/quick-terminal")
