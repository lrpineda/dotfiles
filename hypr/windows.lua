-- Personal window rules and window behavior.

-- Keep picture-in-picture following you across workspaces.
--
-- Omarchy already floats and pins anything titled "Picture-in-Picture"
-- ($OMARCHY_PATH/default/hypr/apps/pip.lua), and that rule does fire. But a
-- pin is state on the window, not a standing rule: several things clear it
-- (moving the window to a workspace, SUPER+O on an already-popped window),
-- and once a Zen PiP loses its pin it stays behind on whichever workspace it
-- was on. These handlers put the pin back so it keeps following.

local PIP_TITLE = "[Pp]icture.?[Ii]n.?[Pp]icture"

local function is_pip(win)
  return win ~= nil and win.title ~= nil and win.title:find(PIP_TITLE) ~= nil
end

-- Only pin floaters. Pinning a tiled window is a no-op in Hyprland, and
-- force-floating something the user deliberately tiled would be a surprise.
local function keep_pinned(win)
  if not win or win.pinned or not win.floating or not win.address then return end
  hl.dispatch(hl.dsp.window.pin({ window = "address:" .. win.address }))
end

hl.on("window.open", function(win)
  if is_pip(win) then keep_pinned(win) end
end)

-- Firefox/Zen name the window at map time, but Google Meet and friends rename
-- a plain window into a PiP later, so re-check on every title change.
hl.on("window.title", function(win)
  if is_pip(win) then keep_pinned(win) end
end)

-- The catch-all: whatever dropped the pin, notice it the next time you change
-- workspace and put it back, so a PiP can go at most one switch astray.
hl.on("workspace.active", function()
  for _, win in ipairs(hl.get_windows() or {}) do
    if is_pip(win) then keep_pinned(win) end
  end
end)
