# superconfig — CachyOS + Hyprland + Caelestia

Capa de personalización sobre una instalación **Caelestia / Midnight** ya
funcionando. No es un fork del shell: instala solo los archivos que cambian la
estética y las cositas añadidas (overview 3D, CustomWallpaper, Thunar Fluent,
Kitty, suspensión, etc.).

## Qué incluye

- **Sesión**: menú sin `hibernar`, botón de dormir con icono `bedtime` y
  `systemctl suspend`. GIF de Fry en el menú de sesión.
- **Kitty**: copiar al seleccionar, clic derecho para pegar, `Ctrl+C/V/X`,
  notificación “Copiado” solo cuando Kitty está enfocado, y saludo ASCII
  **CHRIS** en Fish.
- **Overview 3D**: `Super + Space`, con colores sincronizados desde Caelestia.
- **Thunar estilo Windows 11**: wrapper `bwrap` con GTK `Fluent-Dark`, iconos
  `Win11-black` y cursores `WinSur-dark-cursors`. `Super + E` y
  `Alt + Super + E`.
- **CustomWallpaper**: selector propio con vídeos locales, MotionBGs y
  Wallhaven. `Super + B`. El selector nativo de Caelestia sigue en
  `Super + Shift + B`.
- **Hyprland**: gaps, redondeos, transparencias, reglas de ventana, atajos y
  sincronización de colores con KDE/GTK.
- **Wallpapers**: `paths.wallpaperDir` apunta a tu carpeta de vídeos local
  (por defecto `~/Vídeos` o `~/Videos`).

## Requisitos

- CachyOS/Arch + Hyprland.
- **Caelestia / Midnight** ya instalado y funcionando. En este equipo el CLI
  viene del paquete `midnight-cli-git` y el shell de `quickshell-git`.
- `python3`, `tar`, `xz`.
- Recomendados: `kitty`, `fish`, `thunar`, `hyprswitch`, `bubblewrap`, `jq`,
  `wl-clipboard`, `libnotify`, `ffmpeg`, `cliphist`, `papirus-icon-theme`,
  `breeze-icons`, `ttf-jetbrains-mono-nerd`, `gnome-text-editor`, `qtengine`,
  `starship`, `fastfetch`, `eza`, `zoxide`, `direnv`.

Lista orientativa en [`packages.txt`](packages.txt).

## Instalación rápida

```bash
git clone https://github.com/crdacoga2016-beep/superconfig.git ~/superconfig
cd ~/superconfig

# 1) Ver qué haría, sin tocar nada
./install.sh --dry-run

# 2) Instalar (hace backup de lo que reemplaza)
./install.sh

# 3) Aplicar
hyprctl reload   # o cerrar y volver a iniciar sesión
```

Opciones útiles:

```bash
./install.sh --yes                         # sin confirmación
./install.sh --install-packages            # intenta instalar faltantes con paru/yay/pacman
./install.sh --wallpaper-dir ~/Vídeos      # carpeta de vídeos/fondos
./install.sh --no-integrations             # no toca systemctl/xdg-mime/hyprctl/hooks
./install.sh --help
```

Los backups quedan en:

```text
~/.local/state/chris-dotfiles/backups/FECHA-HORA/
```

## API keys y `shell.json`

El repo **no incluye** tu `shell.json` real ni ninguna API key.

El instalador lee el `~/.config/caelestia/shell.json` que ya exista en el
portátil y fusiona **solo claves estéticas** (`appearance`, `background`,
`bar`, `utilities`, `paths`, `general.sessionGifSpeed`,
`general.apps.explorer`). El bloque `ai`, `audio`, `services`, `launcher` y
cualquier clave propia se conservan tal cual.

- Si el portátil ya tiene tus API keys, se quedan.
- Si no existe `shell.json`, se crea sin bloque `ai`.
- El archivo se escribe con permisos `600`.
- No se imprime ningún secreto por consola.

Si alguna vez compartiste tu `shell.json` o una key, rótala.

## Fondos y vídeos

CustomWallpaper lee la carpeta configurada en `paths.wallpaperDir`. Por
defecto el instalador elige, en este orden:

1. `--wallpaper-dir` si lo pasas.
2. La carpeta XDG de vídeos.
3. `~/Vídeos`.
4. `~/Videos`.
5. `~/Imágenes/Fondos` o `~/Pictures/Wallpapers`.

Copia tus vídeos ahí antes o después de instalar. **Los vídeos no se suben al
repo.**

## Atajos principales

| Atajo | Acción |
| --- | --- |
| `Super + Space` | Overview 3D |
| `Super + B` | Abrir CustomWallpaper |
| `Super + Shift + B` | Selector de fondos de Caelestia |
| `Super + E` / `Alt + Super + E` | Thunar |
| `Super + T` | Kitty |
| `Super + Tab` | hyprswitch (mantén Super y pulsa Tab) |
| `Super + Shift + A` | Cambiar salida de audio |
| `Super + Shift + L` | Dormir (`systemctl suspend`) |
| `Ctrl + Alt + Delete` | Menú de sesión (sin hibernar) |
| `Super + V` | Portapapeles |

## Estructura

```text
config/hypr/                 variables y scripts de Hyprland
config/caelestia/            hypr-user.lua, hypr-vars.lua, cli.json
config/quickshell/           overview 3D, Content.qml y CustomWallpaper
config/kitty/                kitty.conf
config/fish/                 saludo CHRIS
config/thunar-fluent/        GTK de Thunar
config/systemd/user/         override del daemon de Thunar
local/bin/                   scripts instalados en ~/.local/bin
assets/themes/               Fluent-Dark, Win11-black y WinSur (.tar.xz)
assets/fry.webp              GIF del menú de sesión
scripts/                     merge seguro de JSON y generación del .desktop
```

## Qué no se incluye

- `~/.config/caelestia/shell.json` con API keys.
- El binario `~/.local/bin/hyprswitch` (se usa el paquete `hyprswitch`).
- Archivos generados: `hypr/scheme/current.lua`, `hyprswitch/theme.css` y
  `quickshell/overview/theme.json` (se regeneran al iniciar o con
  `hyprswitch-theme`).
- Configuración específica de monitor (`HDMI-A-2`): ajústala en el portátil.
- Vídeos, bookmarks personales, CoreCtrl, warpdash y otros programas ajenos a
  esta estética.

## Problemas comunes

**Thunar no coge el tema**  
Comprueba que `bwrap` funciona:

```bash
bwrap --dev-bind / / true && echo ok
```

Si falla, el wrapper lanza Thunar normal como fallback.

**No aparece hyprswitch**  

```bash
paru -S hyprswitch
```

**Los colores del overview/hyprswitch no cambian**  

```bash
~/.local/bin/hyprswitch-theme
```

Luego reinicia la sesión o vuelve a abrir el overview.

**Caelestia actualizó y sobrescribió `Content.qml`**  
Vuelve a ejecutar `./install.sh`; el instalador guarda backup del archivo
anterior.

## Créditos y licencias

Ver [`THIRD_PARTY.md`](THIRD_PARTY.md). Caelestia, los temas GTK/iconos y
Wallestile pertenecen a sus autores originales.
