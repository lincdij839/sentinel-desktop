-- ~/.config/hypr/keybinds.lua
-- Migrated from keybinds.conf
-- Docs: https://wiki.hypr.land/Configuring/Basics/Binds/
--       https://wiki.hypr.land/Configuring/Basics/Dispatchers/

local home = os.getenv("HOME") or ""
local share = os.getenv("SENTINEL_HOME") or "/usr/share/sentinel-desktop"
local bind = share .. "/scripts/43pr-bind.sh"

local path = "/usr/local/bin:/usr/bin:/usr/sbin:/bin"
if home ~= "" then
    path = home .. "/.local/bin:" .. path
end
pcall(function()
    hl.env("PATH", path)
end)

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(bind .. " launcher")) -- Toggle launcher / rofi
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd(bind .. " launcher")) -- App launcher
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(bind .. " ipc wheel toggle")) -- qs ipc call wheel toggle
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())

hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd(bind .. " lock")) -- Lock screen

hl.bind(mainMod .. " + GRAVE", hl.dsp.exec_cmd(bind .. " ipc powermenu toggle")) -- qs ipc call powermenu toggle

hl.bind(mainMod .. " + I", hl.dsp.exec_cmd(bind .. " ipc settings toggle")) -- qs ipc call settings toggle

hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(bind .. " wallpaper")) -- hyprquickpaper

hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(bind .. " opacity"))

-- Theme used Super+L upstream, but that key is vim-style focus right.
hl.bind(mainMod .. " + Y", hl.dsp.exec_cmd(bind .. " theme"))

hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(bind .. " ipc notifications toggle")) -- qs ipc call notifications toggle

hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(bind .. " ipc todo toggle")) -- qs ipc call todo toggle

-- Mouse move/resize window
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(bind .. " ipc bar toggle")) -- qs ipc call bar toggle

-- Clipboard
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(bind .. " clip"))

-- Screenshot fullscreen
hl.bind("Delete", hl.dsp.exec_cmd(bind .. " screenshot full"))
-- Screenshot area select
hl.bind("SHIFT + Delete", hl.dsp.exec_cmd(bind .. " screenshot area"))

-- IME / keyboard layout
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd(bind .. " ime"))

-- Toggle float window, center and resize
hl.bind(mainMod .. " + Space", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))

    local w = hl.get_active_window()
    if w ~= nil and w.floating then
        local mon = hl.get_active_monitor()
        if mon ~= nil then
            local target_w = math.floor(mon.width * 0.7)
            local target_h = math.floor(mon.height * 0.7)

            hl.dispatch(hl.dsp.window.resize({ x = target_w, y = target_h, relative = false }))

            local mon_x = mon.x or 0
            local mon_y = mon.y or 0
            local target_x = mon_x + math.floor((mon.width - target_w) / 2)
            local target_y = mon_y + math.floor((mon.height - target_h) / 2)

            hl.dispatch(hl.dsp.window.move({ x = target_x, y = target_y, relative = false }))
        end
    end
end)

hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(bind .. " record"))

-- Zoom
local function zoomfunction(value)
    local zoomvalue = hl.get_config("cursor:zoom_factor")
    if (zoomvalue + value) > 1.5 then
        hl.config({ cursor = { zoom_factor = 1.5 } })
    elseif (zoomvalue + value) < 1.0 then
        hl.config({ cursor = { zoom_factor = 1.0 } })
    else
        hl.config({ cursor = { zoom_factor = zoomvalue + value } })
    end
end
hl.bind(mainMod .. " + mouse_down", function() zoomfunction(-0.5) end, { repeating = true })
hl.bind(mainMod .. " + mouse_up", function() zoomfunction(0.5) end, { repeating = true })

hl.bind(mainMod .. " + code:82", function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + code:86", function() zoomfunction(0.3) end, { repeating = true })

hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(bind .. " exit-session"))

hl.bind(mainMod .. " + K", hl.dsp.exec_cmd(bind .. " ipc keybinds toggle"))

-- Focus. Up is Super+Up because Super+K opens the shortcut list.
-- Hyprland 0.56 ignores the short names l/r/u/d for window moves.
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))

hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))

hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.resize({ x = -80, y = 0, relative = true }))
hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.resize({ x = 80, y = 0, relative = true }))
hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.resize({ x = 0, y = -80, relative = true }))
hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.resize({ x = 0, y = 80, relative = true }))

for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
