------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "desc:LG Electronics LG ULTRAGEAR+ 409NTYT1W034",
    mode     = "3840x2160@240",
    position = "auto",
    scale    = "auto",
})


-------------------------
---- MATUGEN COLORS -----
-------------------------

-- Add context to required HyprLua registrations. A failed reload should say
-- exactly which rule or binding is incompatible instead of silently omitting
-- part of the desktop configuration.
local function required(name, register)
    local ok, result = xpcall(register, debug.traceback)
    if not ok then
        error("failed to register " .. name .. ":\n" .. result, 0)
    end
    return result
end

-- Reads the matugen-generated accent color (config/matugen/) so the active
-- window border matches hyprlock, Kitty, and the Quickshell surfaces. This file is re-read
-- on every config reload, and scripts/set-wallpaper.sh reloads Hyprland
-- after regenerating it, so the border updates with the rest of the theme.
-- Falls back to a fixed color if the file is missing/unparseable (e.g.
-- before home/stivce.nix's seedMatugenDefaults has run).
local function matugenHex(name, fallback)
    -- Palette loading is deliberately optional: the checked-in fallback keeps
    -- the compositor usable before Matugen has generated its first palette.
    local ok, hex = pcall(function()
        local f = io.open(os.getenv("HOME") .. "/.config/hypr/hyprlock-colors.conf", "r")
        if not f then return nil end
        local content = f:read("*a")
        f:close()
        return content:match("%$" .. name .. "%s*=%s*rgb%((%x+)%)")
    end)
    return (ok and hex) or fallback
end

local accentHex  = matugenHex("accent", "ffffff")
local surfaceHex = matugenHex("surface", "111318")


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "nautilus"

local menu = "quickshell ipc call launcher toggle"


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_THEME", "volantes_light_cursors") -- NixOS theme name (was Volantes_Light)
hl.env("XCURSOR_SIZE", "34")
hl.env("HYPRCURSOR_SIZE", "34")

-- GTK4: native Wayland (XWayland fallback breaks layer-shell input)
hl.env("GDK_BACKEND", "wayland")

-- NVIDIA
-- LIBVA_DRIVER_NAME is set system-wide in modules/nvidia.nix, not here.
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("__GL_VRR_ALLOWED", "0")
hl.env("NVD_BACKEND", "direct")

-- Electron / Chromium Wayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Qt Wayland (qt6ct carries the dark palette; the stack is qt6-only)
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,

        border_size = 2,

        col = {
            active_border   = "rgb(" .. accentHex .. ")",
            inactive_border = { colors = {"rgba(808080b3)", "rgba(" .. accentHex .. "b3)"}, angle = 45 },
        },

        resize_on_border = false,
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        active_opacity   = 0.97,
        inactive_opacity = 0.90,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled           = true,
            size              = 5,
            passes            = 2,
            ignore_opacity    = true,
            new_optimizations = true,
            vibrancy          = 0.17,
            -- Acrylic-glass look: Hyprland's defaults (brightness 0.8172,
            -- contrast 0.8916) darken everything behind blur, which made
            -- the tintless notification glass read as a dark box. Neutral
            -- values + a touch of noise give the frosted-acrylic grain.
            brightness        = 1.0,
            contrast          = 1.0,
            noise             = 0.02,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_status = "master",
    },
})

hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        -- disable_hyprland_logo only hides the logo graphic - this is the
        -- separate "<quote>" splash text, which otherwise lingers oddly
        -- underneath the wallpaper for a moment once it loads.
        disable_splash_rendering = true,
        -- Matches the matugen surface color, so the moment before
        -- scripts/set-wallpaper.sh finishes starting awww and setting the
        -- real wallpaper (unavoidably sequential: start the daemon, wait
        -- for it, then load the image) is a themed dark tone instead of a
        -- jarring flash of pure black.
        background_color = tonumber("0xff" .. surfaceHex),
        -- If hyprlock dies while it holds the session lock (crash, or a
        -- service restart killing it mid-lock), Hyprland falls back to its
        -- own built-in "lockscreen app died" screen and refuses to let a
        -- new hyprlock reattach without this - leaving you stuck until a
        -- TTY-based recovery. Let a fresh hyprlock reclaim it instead.
        allow_session_lock_restore = true,
    },
})

hl.config({
    ecosystem = {
        no_update_news = true,
    },
})

-- NVIDIA: hardware cursors glitch on nvidia-drm
hl.config({
    cursor = {
        no_hardware_cursors = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd(terminal .. " herdr"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only
required("binding " .. mainMod .. "+F", function()
    hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
end)
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("quickshell ipc call powermenu toggle"))
hl.bind("ALT + SHIFT + 3", hl.dsp.exec_cmd("$HOME/.local/bin/misc/screenshot-output-save"))
hl.bind("ALT + SHIFT + 4", hl.dsp.exec_cmd("$HOME/.local/bin/misc/screenshot-region"))
hl.bind("ALT + SHIFT + 5", hl.dsp.exec_cmd("hyprquickframe"))
hl.bind(mainMod .. " + SHIFT + Q",  hl.dsp.exec_cmd("$HOME/.config/hypr/start-hyprlock"))
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd("quickshell ipc call wallpaper toggle"))
hl.bind(mainMod .. " + SHIFT + F1", hl.dsp.exec_cmd("$HOME/Scripts/set-wallpaper.sh"))

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Launched by clicking the expanded Quickshell notch calendar.
hl.window_rule({
    name  = "float-gnome-calendar",
    match = { class = "^org\\.gnome\\.Calendar$" },

    float  = true,
    center = true,
    opacity = "0.8 override",
})


-- No transparency for these apps / fullscreen content
for name, m in pairs({
    ["opaque-looking-glass"] = { class = "looking-glass-client" },
    ["opaque-zen"]           = { class = "zen" },
    ["opaque-helium"]        = { class = "helium" },
    ["opaque-fullscreen"]    = { fullscreen = true },
}) do
    required("window rule " .. name, function()
        hl.window_rule({ name = name, match = m, opacity = "1 override" })
    end)
end

-- WoW: own workspace, floating fullscreen, tearing allowed
for name, rule in pairs({
    ["wow-workspace"]  = { workspace = "e+1" },
    ["wow-float"]      = { float = true },
    ["wow-fullscreen"] = { fullscreen = true },
    ["wow-immediate"]  = { immediate = true },
}) do
    local r = { name = name, match = { title = "^World of Warcraft$" } }
    for k, v in pairs(rule) do r[k] = v end
    required("window rule " .. name, function()
        hl.window_rule(r)
    end)
end

-- Small Quickshell frosted-glass surfaces (the notch itself is opaque black,
-- so it is deliberately NOT blurred). Sample the live content immediately
-- behind them rather than xraying through windows to the wallpaper.
for name, ns in pairs({
    ["blur-qs-notifications"] = "quickshell-notifications",
    ["blur-qs-bar"]           = "quickshell-bar",
    ["blur-qs-launcher"]      = "quickshell-launcher",
    ["blur-qs-power"]         = "quickshell-power",
    ["blur-qs-wallpaper"]     = "quickshell-wallpaper",
}) do
    required("layer rule " .. name, function()
        hl.layer_rule({ name = name, match = { namespace = ns }, blur = true, ignore_alpha = 0.1, xray = false })
    end)
end

-- The notification centre should blur the actual windows/content immediately
-- behind it. Unlike the small acrylic popups, do not xray through to wallpaper.
required("layer rule blur-qs-center", function()
    hl.layer_rule({
        name = "blur-qs-center",
        match = { namespace = "quickshell-center" },
        blur = true,
        ignore_alpha = 0.1,
        xray = false,
    })
end)

-- Hyprland's own layersIn fade animation applies to every new layer-shell
-- surface, including awww's wallpaper layer - on top of the matugen
-- fallback color and awww's own transition (already set to "none" in
-- set-wallpaper.sh), this was the last source of visible fade-in delay at
-- session start.
required("layer rule no-anim-wallpaper", function()
    hl.layer_rule({ name = "no-anim-wallpaper", match = { namespace = "awww-daemon" }, no_anim = true })
end)
