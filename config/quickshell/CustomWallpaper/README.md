
# CustomWallpaper

A fullscreen Quickshell wallpaper browser for Hyprland/Caelestia with Grid,
Carousel, and 3D Ring layouts. It browses **local animated/static wallpapers**,
**MotionBGs** (4K animated) and **Wallhaven** (static), then applies the chosen
one through Caelestia's native `wallpaper set` IPC service, so the live wallpaper
and colour singletons update exactly like Caelestia's own selector.

Local wallpapers are read from `paths.wallpaperDir` in
`~/.config/caelestia/shell.json` (falling back to `~/Vídeos`). Video thumbnails
reuse Caelestia's cache when present and are otherwise extracted with `ffmpeg`.
MotionBGs entries stream a 960×540 preview in the selected card and download the
4K MP4 on apply. The selected wallpaper survives logout and reboot.

## Providers

- **Local**: every mp4 / webm / mkv / gif / image in the wallpaper directory.
  Filters: All, Animated, Images.
- **MotionBGs**: Latest, 4K, Anime, Games and Nature, plus text search.
- **Wallhaven**: Latest and Toplist, plus text search.

## Install / run

Add the Hyprland bind (already present in this setup):

```lua
hl.bind("SUPER + B", hl.dsp.exec_cmd("qs -c CustomWallpaper"))
hl.layer_rule({ match = { namespace = "custom-wallpaper" }, animation = "fade", blur = true })
```

Run it directly:

```sh
qs -c CustomWallpaper
```

Controls: arrow keys navigate, Enter applies, Escape closes, double-clicking a
card applies it.

MotionBGs videos are downloaded (MP4, ~4K) to
`$XDG_DATA_HOME/custom-wallpaper`; only the active download is kept. The 960×540
preview streams directly and is not cached on disk.
