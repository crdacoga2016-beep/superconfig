local home = os.getenv("HOME")
local bin = home .. "/.local/bin"
local config = home .. "/.config"

hl.bind("SUPER + B", hl.dsp.exec_cmd("qs -c CustomWallpaper"), { description = "Open Custom Wallpaper Selector" })
hl.layer_rule({ match = { namespace = "custom-wallpaper" }, animation = "fade", blur = true })

hl.window_rule({
    match = { class = "steam_proton" },
    idle_inhibit = "always"
})

-- hyprswitch: mantener SUPER y pulsar TAB para ciclar; soltar SUPER para confirmar.
hl.bind("SUPER + TAB", hl.dsp.exec_cmd("hyprswitch gui --mod-key SUPER --key TAB --close mod-key-release"), { description = "Window & workspace switcher (hyprswitch)" })

hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("qs -c overview ipc call overview toggle"), { description = "3D workspace overview" })
hl.layer_rule({ match = { namespace = "caelestia-overview" }, animation = "fade", blur = true })

hl.on("hyprland.start", function()
    hl.exec_cmd(bin .. "/hyprswitch-theme-watch")
end)

hl.on("hyprland.start", function()
    hl.exec_cmd("sh -c 'test -f " .. config .. "/quickshell/overview/theme.json || " .. bin .. "/hyprswitch-theme >/dev/null 2>&1; exec qs -c overview'")
end)

hl.config({ input = { kb_layout = "latam" } })

hl.bind("SUPER + SHIFT + B", hl.dsp.global("caelestia:wallpaper"), { description = "Wallpaper picker" })

hl.on("hyprland.start", function()
    hl.exec_cmd("sleep 8 && qs -c caelestia ipc call idleInhibitor enable")
end)

hl.bind("SUPER + SHIFT + A", hl.dsp.exec_cmd(bin .. "/switch-audio.sh"), { description = "Cambiar salida de audio" })

hl.env("QT_QPA_PLATFORMTHEME", "qtengine")
hl.env("QS_ICON_THEME", "Papirus-Dark")
hl.env("QT_STATUSBAR_THEME", "dark")
hl.env("KDE_COLOR_SCHEME", "Caelestia")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "0")

hl.on("hyprland.start", function()
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'WinSur-dark-cursors'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 24")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
    hl.exec_cmd("command -v kwriteconfig6 >/dev/null && kwriteconfig6 --file kdeglobals --group General --key ColorScheme Caelestia || true")
    hl.exec_cmd("command -v kwriteconfig6 >/dev/null && kwriteconfig6 --file kdeglobals --group Icons --key Theme Papirus-Dark || true")
    hl.exec_cmd(bin .. "/caelestia-kde-sync")
end)

hl.window_rule({ match = { class = "kitty" }, opacity = "1.0 override" })
hl.window_rule({ match = { class = "^(Thunar)$" }, opacity = "0.80 override" })

-- Notificación "Copiado" al copiar selección en kitty.
hl.on("hyprland.start", function()
    hl.exec_cmd("sh -c 'command -v wl-paste >/dev/null && exec wl-paste --type text --watch " .. config .. "/hypr/scripts/clipboard-notify.sh'")
end)
