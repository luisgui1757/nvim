-- devilspie2 rule: always maximize Ghostty windows on launch (X11 / GNOME).
--
-- Why this exists: Ghostty's `maximize = true` is only a startup *hint*; on
-- Linux the window manager owns final placement and may ignore it. On X11
-- (Mutter usually honors it) `maximize = true` often suffices on its own --
-- try that first. If it does NOT, devilspie2 enforces it window-manager-side.
--
-- Ghostty's app-id maps to the X11 WM_CLASS "com.mitchellh.ghostty".
-- devilspie2 runs every .lua in ~/.config/devilspie2/ for each new window.
--
-- Setup (X11 only -- devilspie2 does NOT work on Wayland):
--   1. install devilspie2            (apt/dnf/pacman/zypper install devilspie2)
--   2. link this file into place:
--        mkdir -p ~/.config/devilspie2
--        ln -sfn "$PWD/linux/devilspie2/ghostty-maximize.lua" \
--                ~/.config/devilspie2/ghostty-maximize.lua
--   3. run it at login (autostart):
--        mkdir -p ~/.config/autostart
--        printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=devilspie2' \
--          'Exec=devilspie2' 'X-GNOME-Autostart-enabled=true' \
--          > ~/.config/autostart/devilspie2.desktop
--   4. start it now without re-login:  devilspie2 &

if get_window_class() == "com.mitchellh.ghostty" or get_application_name() == "Ghostty" then
	maximize()
end
