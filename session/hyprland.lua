-- Sentinel session uses the 43PR Hyprland + Quickshell rice only.
-- https://github.com/43PR/dotfiles
local home = os.getenv("SENTINEL_HOME") or "/usr/share/sentinel-desktop"
local rice = home .. "/dot43pr/hypr"

local function exists(path)
    local probe = io.open(path, "r")
    if not probe then
        return false
    end
    probe:close()
    return true
end

if not exists(rice .. "/hyprland.lua") then
    dofile(home .. "/session/hyprland-hud.lua")
    return
end

package.path = rice .. "/?.lua;" .. package.path
dofile(rice .. "/hyprland.lua")

-- Do not dispatch during --verify-config; Hyprland 0.56 can abort there.
local function leave_resize()
    pcall(function()
        hl.dispatch(hl.dsp.submap(""))
    end)
end
hl.on("hyprland.start", leave_resize)

pcall(function()
    hl.config({
        misc = {
            force_default_wallpaper = 0,
            disable_hyprland_logo = true,
            disable_splash_rendering = true,
            disable_watchdog_warning = true,
        },
    })
end)
pcall(function()
    hl.curve("appin", {
        type = "bezier",
        points = {{0.2, 0.9}, {0.2, 1.0}},
    })
    hl.animation({ leaf = "windowsIn", enabled = true, speed = 8, bezier = "appin", style = "popin 96%" })
    hl.animation({ leaf = "fadeIn", enabled = true, speed = 8, bezier = "appin" })
end)

-- Software rendering in a VM cannot keep up with blur and shadows.
local function guest_vm()
    local product = io.open("/sys/class/dmi/id/product_name", "r")
    if not product then
        return false
    end
    local name = product:read("*a") or ""
    product:close()
    return name:find("QEMU") ~= nil or name:find("KVM") ~= nil
        or name:find("Virtual") ~= nil or name:find("Bochs") ~= nil
end
if guest_vm() then
    pcall(function()
        hl.config({
            decoration = {
                blur = { enabled = false },
                shadow = { enabled = false },
            },
        })
    end)
end
pcall(function()
    hl.env("QT_QPA_PLATFORM", "wayland;xcb")
    hl.env("GDK_BACKEND", "wayland,x11")
    hl.env("MOZ_ENABLE_WAYLAND", "1")
    hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
end)

-- Wayland 不会把 Ctrl+Space 交给 fcitx 内部热键，必须由合成器转发。
hl.bind("CTRL + SPACE", hl.dsp.exec_cmd(home .. "/scripts/toggle-ime.sh"))
