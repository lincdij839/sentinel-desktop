-- 43PR Hyprland config, adapted for Sentinel Desktop on Fedora.
-- Upstream: https://github.com/43PR/dotfiles  .config/hypr/hyprland.lua

mainMod    = "SUPER"
terminal   = "kitty"
menu       = "rofi -show drun"
fileManager = "thunar"
browser    = "brave"

local sentinel = os.getenv("SENTINEL_HOME") or "/usr/share/sentinel-desktop"
local function has_bin(name)
    local prefixes = {
        "/usr/bin/",
        "/usr/local/bin/",
        (os.getenv("HOME") or "") .. "/.local/bin/",
    }
    for i = 1, #prefixes do
        local probe_bin = io.open(prefixes[i] .. name, "r")
        if probe_bin then
            probe_bin:close()
            return true
        end
    end
    return false
end
if not has_bin("brave") and not has_bin("brave-browser") then
    if has_bin("firefox") then
        browser = "firefox"
    elseif has_bin("google-chrome-stable") then
        browser = "google-chrome-stable"
    end
end
if not has_bin("kitty") and has_bin("ptyxis") then
    terminal = "ptyxis"
end
if not has_bin("thunar") and has_bin("nautilus") then
    fileManager = "nautilus"
end

hl.on("hyprland.start", function()
    hl.exec_cmd(sentinel .. "/scripts/start-43pr-helpers.sh")
    local shell = os.getenv("SENTINEL_SHELL") or (sentinel .. "/dot43pr/quickshell")
    hl.exec_cmd(sentinel .. "/scripts/start-qs.sh --path " .. string.format("%q", shell))
end)

hl.env("XCURSOR_SIZE", "14")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.config({
    input = {
        kb_layout = os.getenv("SENTINEL_KB_LAYOUT") or "us",
        follow_mouse = 1,
        sensitivity = 0.5,
        touchpad = {
            natural_scroll = false,
            tap_to_click = true,
        },
    },
})

hl.config({
    dwindle = { preserve_split = true },
})
hl.config({
    master = { new_status = "master" },
})

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        disable_watchdog_warning = true,
    },
})

require("monitors")
require("keybinds")
require("look")
require("rules")
pcall(require, "hyprland-gui")
