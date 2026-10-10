-- Sentinel Desktop Hyprland configuration.
-- SENTINEL_HOME is exported by session/sentinel-session (or run-nested.sh).

local home = os.getenv("SENTINEL_HOME") or "/usr/share/sentinel-desktop"
local terminal = (function()
    local kitty = io.popen("command -v kitty 2>/dev/null")
    local path = kitty and kitty:read("*l")
    if kitty then kitty:close() end
    if path and path ~= "" then
        return "kitty"
    end
    return "ptyxis"
end)()
local mod = "SUPER"

local function config_home()
    local base = os.getenv("XDG_CONFIG_HOME")
    if base and base ~= "" then
        return base
    end
    return (os.getenv("HOME") or "") .. "/.config"
end

local function shell_dir()
    local override = os.getenv("SENTINEL_SHELL")
    if override and override ~= "" then
        return override
    end
    local candidate = config_home() .. "/sentinel/shell"
    local probe = io.open(candidate .. "/shell.qml", "r")
    if probe then
        probe:close()
        return candidate
    end
    return home .. "/shell"
end

local quickshell_path = shell_dir()

local function saved_scales()
    local file = io.open(config_home() .. "/sentinel/monitors.conf", "r")
    if not file then
        return nil
    end
    local scales = {}
    for line in file:lines() do
        local name, scale = line:match("^(%S+)%s+([%d%.]+)$")
        local value = scale and tonumber(scale) or nil
        if name and value and value >= 0.5 and value <= 3 then
            scales[#scales + 1] = { name = name, scale = value }
        end
    end
    file:close()
    if #scales == 0 then
        return nil
    end
    return scales
end

local saved = saved_scales()
if saved then
    for _, item in ipairs(saved) do
        hl.monitor({
            output = item.name,
            mode = "preferred",
            position = "auto",
            scale = item.scale,
        })
    end
else
    hl.monitor({
        output = "",
        mode = "preferred",
        position = "auto",
        scale = 1,
    })
end

local function keyboard_layout()
    local override = os.getenv("SENTINEL_KB_LAYOUT")
    if override and override ~= "" then
        return override
    end
    local xorg = io.open("/etc/X11/xorg.conf.d/00-keyboard.conf", "r")
    if xorg then
        local text = xorg:read("*a") or ""
        xorg:close()
        local layout = text:match('XkbLayout"%s*"([^"]+)"')
        if layout and layout ~= "" then
            return layout
        end
    end
    local vconsole = io.open("/etc/vconsole.conf", "r")
    if vconsole then
        local text = vconsole:read("*a") or ""
        vconsole:close()
        local keymap = text:match('KEYMAP="?([%w_-]+)')
        if keymap then
            return keymap
        end
    end
    return nil
end

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("QT_IM_MODULES", "wayland;fcitx;ibus")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("SDL_IM_MODULE", "fcitx")
hl.env("INPUT_METHOD", "fcitx")

hl.on("hyprland.start", function()
    hl.exec_cmd(
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP SENTINEL_HOME QT_IM_MODULE QT_IM_MODULES XMODIFIERS SDL_IM_MODULE INPUT_METHOD QT_QPA_PLATFORM GDK_BACKEND MOZ_ENABLE_WAYLAND ELECTRON_OZONE_PLATFORM_HINT"
        .. " && { uwsm finalize SENTINEL_HOME XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE QT_IM_MODULE QT_IM_MODULES XMODIFIERS SDL_IM_MODULE INPUT_METHOD QT_QPA_PLATFORM GDK_BACKEND MOZ_ENABLE_WAYLAND ELECTRON_OZONE_PLATFORM_HINT || true; }"
        .. " && " .. home .. "/session/start-fcitx.sh"
        .. " && { command -v wl-paste >/dev/null 2>&1 && command -v cliphist >/dev/null 2>&1 && wl-paste --watch cliphist store >/dev/null 2>&1 & true; }"
        .. " && exec " .. home .. "/scripts/start-qs.sh --path " .. string.format("%q", quickshell_path)
    )
end)

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border = { colors = {"rgb(5ee6ff)", "rgb(2fa8c8)"}, angle = 45 },
            inactive_border = "rgb(123a4a)",
        },
        layout = "dwindle",
    },
    decoration = {
        rounding = 2,
        blur = {
            enabled = true,
            size = 6,
            passes = 2,
        },
        shadow = {
            enabled = true,
            range = 14,
            render_power = 3,
            color = "rgba(5ee6ff55)",
        },
    },
    animations = {
        enabled = true,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        disable_watchdog_warning = true,
        force_default_wallpaper = 0,
        background_color = "rgb(000000)",
    },
    input = (function()
        local input = { follow_mouse = 1 }
        local layout = keyboard_layout()
        if layout then
            input.kb_layout = layout
        end
        return input
    end)(),
})

hl.curve("hud", {
    type = "bezier",
    points = {{0.2, 0.9}, {0.2, 1.0}},
})
hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "hud", style = "popin 92%" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "hud" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "hud", style = "fade" })
hl.animation({ leaf = "border", enabled = true, speed = 6, bezier = "hud" })

hl.window_rule({
    name = "sentinel-dashboard",
    match = { title = "^Sentinel Desktop$" },
    float = true,
    size = "1360 860",
    center = true,
})
local function shell(command)
    return hl.dsp.exec_cmd(home .. "/session/sentinel-ctl " .. command)
end

hl.bind("CTRL + SPACE", hl.dsp.exec_cmd(home .. "/scripts/toggle-ime.sh"))
hl.bind(mod .. " + X", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + SPACE", shell("launcher toggle"))
hl.bind(mod .. " + D", shell("dashboard toggle"))
hl.bind(mod .. " + N", shell("network toggle"))
hl.bind(mod .. " + E", shell("files toggle"))
hl.bind(mod .. " + CTRL + L", shell("lock lock"))
hl.bind(mod .. " + SHIFT + E", shell("power toggle"))
hl.bind(mod .. " + A", shell("audio toggle"))
hl.bind(mod .. " + B", shell("bluetooth toggle"))
hl.bind(mod .. " + P", shell("display toggle"))
hl.bind(mod .. " + W", shell("wallpaper next"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(home .. "/scripts/screenshot.sh"))
hl.bind(mod .. " + CTRL + S", hl.dsp.exec_cmd(home .. "/scripts/screenshot-edit.sh"))
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd(home .. "/scripts/clipboard.sh"))

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.bind("XF86AudioRaiseVolume", shell("osd volumeUp"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", shell("osd volumeDown"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", shell("osd volumeMute"), { locked = true })
hl.bind("XF86MonBrightnessUp", shell("osd brightnessUp"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", shell("osd brightnessDown"), { locked = true, repeating = true })

hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "down" }))

for workspace = 1, 5 do
    hl.bind(mod .. " + " .. workspace, hl.dsp.focus({ workspace = workspace }))
    hl.bind(mod .. " + SHIFT + " .. workspace, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Extra binds in ~/.config/sentinel/overrides.lua apply on the next login.
-- `mod` is exported for that file; `hl` is the Hyprland API.
local overlay = config_home() .. "/sentinel/overrides.lua"
local overlay_file = io.open(overlay, "r")
if overlay_file then
    overlay_file:close()
    _G.mod = mod
    dofile(overlay)
end
