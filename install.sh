#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
HOME_DIR="${HOME:?HOME no está definido}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME_DIR/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME_DIR/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME_DIR/.local/state}"
BIN_DIR="$HOME_DIR/.local/bin"
BACKUP_ROOT="$STATE_HOME/chris-dotfiles/backups/$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
ASSUME_YES=0
INSTALL_PACKAGES=0
SKIP_DEPS=0
NO_INTEGRATIONS=0
WALLPAPER_DIR=""

if [[ -t 1 ]]; then
    C_BLUE=$'\033[1;34m'; C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'; C_RESET=$'\033[0m'
else
    C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_RESET=""
fi

info() { printf '%s::%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok() { printf '%s ok %s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%swarning:%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die() { printf '%serror:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Uso: ./install.sh [opciones]

Opciones:
  --dry-run              Muestra lo que se haría sin tocar archivos.
  -y, --yes              No pide confirmación.
  --wallpaper-dir DIR    Carpeta de vídeos/fondos (por defecto ~/Vídeos o ~/Videos).
  --install-packages     Intenta instalar dependencias con paru/yay/pacman.
  --no-deps              Omite la comprobación de dependencias.
  --no-integrations      No ejecuta systemctl, xdg-mime, hyprctl ni hooks.
  -h, --help             Muestra esta ayuda.

El instalador hace backups en:
  ~/.local/state/chris-dotfiles/backups/FECHA-HORA
EOF
}

run() {
    if ((DRY_RUN)); then
        printf '  [dry-run]'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

confirm() {
    if [[ ! -t 0 ]]; then
        die "sin terminal interactiva; usa --yes"
    fi
    local answer
    read -r -p "¿Continuar? [Y/n] " answer
    [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]
}

backup_path() {
    local target="$1"
    if [[ ! -e "$target" && ! -L "$target" ]]; then
        return 0
    fi
    local rel="${target#"$HOME_DIR"/}"
    local dest="$BACKUP_ROOT/$rel"
    if ((DRY_RUN)); then
        info "backup: $rel"
        return 0
    fi
    mkdir -p -- "$(dirname -- "$dest")"
    cp -a -- "$target" "$dest"
    info "backup: $rel"
}

install_file() {
    local src="$1" dest="$2" mode="${3:-644}"
    [[ -f "$src" ]] || die "falta $src"
    if ((DRY_RUN)); then
        info "instalar ${dest#"$HOME_DIR"/}"
        return 0
    fi
    backup_path "$dest"
    mkdir -p -- "$(dirname -- "$dest")"
    install -m "$mode" -- "$src" "$dest"
}

install_tree() {
    local src="$1" dest="$2"
    [[ -d "$src" ]] || die "falta $src"
    if ((DRY_RUN)); then
        info "instalar ${dest#"$HOME_DIR"/}/"
        return 0
    fi
    backup_path "$dest"
    rm -rf -- "$dest"
    mkdir -p -- "$(dirname -- "$dest")"
    cp -a -- "$src" "$dest"
}

install_archive() {
    local archive="$1" dest_root="$2" name="$3"
    [[ -f "$archive" ]] || die "falta $archive"
    if ((DRY_RUN)); then
        info "extraer $name -> ${dest_root#"$HOME_DIR"/}"
        return 0
    fi
    command -v tar >/dev/null || die "tar es obligatorio"
    command -v xz >/dev/null || die "xz es obligatorio (paquete xz)"
    backup_path "$dest_root/$name"
    rm -rf -- "$dest_root/$name"
    mkdir -p -- "$dest_root"
    tar -xJf "$archive" -C "$dest_root"
}

resolve_wallpaper_dir() {
    if [[ -n "$WALLPAPER_DIR" ]]; then
        WALLPAPER_DIR="${WALLPAPER_DIR/#\~/$HOME_DIR}"
    else
        local xdg_videos=""
        if command -v xdg-user-dir >/dev/null 2>&1; then
            xdg_videos="$(xdg-user-dir VIDEOS 2>/dev/null || true)"
        fi
        if [[ -n "$xdg_videos" && "$xdg_videos" != "$HOME_DIR" ]]; then
            WALLPAPER_DIR="$xdg_videos"
        fi
        if [[ -z "$WALLPAPER_DIR" ]]; then
            local candidate
            for candidate in "$HOME_DIR/Vídeos" "$HOME_DIR/Videos" "$HOME_DIR/Imágenes/Fondos" "$HOME_DIR/Pictures/Wallpapers"; do
                if [[ -d "$candidate" ]]; then
                    WALLPAPER_DIR="$candidate"
                    break
                fi
            done
        fi
        if [[ -z "$WALLPAPER_DIR" ]]; then
            WALLPAPER_DIR="$HOME_DIR/Vídeos"
        fi
    fi
    if [[ "$WALLPAPER_DIR" != /* ]]; then
        WALLPAPER_DIR="$PWD/$WALLPAPER_DIR"
    fi
}

pkg_install() {
    local pkg="$1"
    if ((DRY_RUN)); then
        info "instalar paquete $pkg"
        return 0
    fi
    if command -v paru >/dev/null 2>&1; then
        paru -S --needed --noconfirm "$pkg"
    elif command -v yay >/dev/null 2>&1; then
        yay -S --needed --noconfirm "$pkg"
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm "$pkg"
    else
        warn "no hay paru/yay/pacman; instala $pkg manualmente"
        return 1
    fi
}

check_dependencies() {
    if ((SKIP_DEPS)); then
        return 0
    fi
    command -v python3 >/dev/null 2>&1 || die "python3 es obligatorio"

    local missing=() optional=() cmd
    for cmd in caelestia qs hyprctl; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    for cmd in kitty fish thunar hyprswitch bwrap jq wl-paste notify-send ffmpeg xz; do
        command -v "$cmd" >/dev/null 2>&1 || optional+=("$cmd")
    done

    if ((INSTALL_PACKAGES)); then
        local map=(
            "caelestia:midnight-cli-git"
            "qs:quickshell-git"
            "hyprctl:hyprland"
            "kitty:kitty"
            "fish:fish"
            "thunar:thunar"
            "hyprswitch:hyprswitch"
            "bwrap:bubblewrap"
            "jq:jq"
            "wl-paste:wl-clipboard"
            "notify-send:libnotify"
            "ffmpeg:ffmpeg"
            "xz:xz"
        )
        local entry
        for entry in "${map[@]}"; do
            local name="${entry%%:*}" package="${entry#*:}"
            if ! command -v "$name" >/dev/null 2>&1; then
                pkg_install "$package" || warn "no se pudo instalar $package"
            fi
        done
        missing=()
        optional=()
        for cmd in caelestia qs hyprctl; do
            command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
        done
        for cmd in kitty fish thunar hyprswitch bwrap jq wl-paste notify-send ffmpeg xz; do
            command -v "$cmd" >/dev/null 2>&1 || optional+=("$cmd")
        done
    fi

    if ((${#missing[@]})); then
        warn "faltan comandos base: ${missing[*]}"
        warn "instala Caelestia/Midnight y ejecuta de nuevo, o usa --install-packages"
    fi
    if ((${#optional[@]})); then
        warn "faltan comandos para funciones: ${optional[*]}"
    fi
}

merge_shell_json() {
    local target="$CONFIG_HOME/caelestia/shell.json"
    if ((DRY_RUN)); then
        info "fusionar shell.json (solo estética; ai/API keys intactas)"
        return 0
    fi
    backup_path "$target"
    mkdir -p -- "$(dirname -- "$target")"
    python3 "$REPO_DIR/scripts/merge-shell-json.py" \
        --existing "$target" \
        --patch "$REPO_DIR/assets/shell.json" \
        --output "$target" \
        --home "$HOME_DIR" \
        --wallpaper-dir "$WALLPAPER_DIR"
}

merge_cli_json() {
    local target="$CONFIG_HOME/caelestia/cli.json"
    if ((DRY_RUN)); then
        info "ajustar cli.json (postHook)"
        return 0
    fi
    backup_path "$target"
    mkdir -p -- "$(dirname -- "$target")"
    python3 "$REPO_DIR/scripts/merge-cli-json.py" "$target" "$BIN_DIR/caelestia-kde-sync"
}

generate_thunar_desktop() {
    local source="/usr/share/applications/thunar.desktop"
    local target="$DATA_HOME/applications/thunar.desktop"
    local icon="$DATA_HOME/icons/Win11-black/apps/scalable/system-file-manager.svg"
    if [[ ! -f "$source" ]]; then
        warn "no existe $source; se omite el .desktop de Thunar"
        return 0
    fi
    if ((DRY_RUN)); then
        info "generar ${target#"$HOME_DIR"/}"
        return 0
    fi
    backup_path "$target"
    mkdir -p -- "$(dirname -- "$target")"
    python3 "$REPO_DIR/scripts/generate-thunar-desktop.py" \
        --source "$source" \
        --output "$target" \
        --wrapper "$BIN_DIR/thunar-fluent" \
        --icon "$icon"
}

install_payload() {
    info "Hyprland"
    install_file "$REPO_DIR/config/hypr/variables.lua" "$CONFIG_HOME/hypr/variables.lua" 644
    install_file "$REPO_DIR/config/hypr/scripts/clipboard-notify.sh" "$CONFIG_HOME/hypr/scripts/clipboard-notify.sh" 755

    info "Caelestia"
    install_file "$REPO_DIR/config/caelestia/hypr-user.lua" "$CONFIG_HOME/caelestia/hypr-user.lua" 644
    install_file "$REPO_DIR/config/caelestia/hypr-vars.lua" "$CONFIG_HOME/caelestia/hypr-vars.lua" 644
    install_file "$REPO_DIR/config/quickshell/caelestia/modules/session/Content.qml" \
        "$CONFIG_HOME/quickshell/caelestia/modules/session/Content.qml" 644
    install_file "$REPO_DIR/assets/fry.webp" "$DATA_HOME/caelestia/assets/fry.webp" 644
    merge_shell_json
    merge_cli_json

    info "Kitty y Fish"
    install_file "$REPO_DIR/config/kitty/kitty.conf" "$CONFIG_HOME/kitty/kitty.conf" 644
    install_file "$REPO_DIR/config/fish/functions/fish_greeting.fish" \
        "$CONFIG_HOME/fish/functions/fish_greeting.fish" 644

    info "Overview 3D"
    install_tree "$REPO_DIR/config/quickshell/overview" "$CONFIG_HOME/quickshell/overview"

    info "CustomWallpaper"
    install_tree "$REPO_DIR/config/quickshell/CustomWallpaper" "$CONFIG_HOME/quickshell/CustomWallpaper"

    info "Thunar Fluent / Windows 11"
    install_tree "$REPO_DIR/config/thunar-fluent/gtk-3.0" "$CONFIG_HOME/thunar-fluent/gtk-3.0"
    install_file "$REPO_DIR/config/systemd/user/thunar.service.d/override.conf" \
        "$CONFIG_HOME/systemd/user/thunar.service.d/override.conf" 644
    install_archive "$REPO_DIR/assets/themes/Fluent-Dark.tar.xz" "$HOME_DIR/.themes" "Fluent-Dark"
    install_archive "$REPO_DIR/assets/themes/Win11-black.tar.xz" "$DATA_HOME/icons" "Win11-black"
    install_archive "$REPO_DIR/assets/themes/WinSur-dark-cursors.tar.xz" "$HOME_DIR/.icons" "WinSur-dark-cursors"
    generate_thunar_desktop

    info "Scripts"
    install_file "$REPO_DIR/local/bin/thunar-fluent" "$BIN_DIR/thunar-fluent" 755
    install_file "$REPO_DIR/local/bin/hyprswitch-theme" "$BIN_DIR/hyprswitch-theme" 755
    install_file "$REPO_DIR/local/bin/hyprswitch-theme-watch" "$BIN_DIR/hyprswitch-theme-watch" 755
    install_file "$REPO_DIR/local/bin/caelestia-kde-sync" "$BIN_DIR/caelestia-kde-sync" 755
    install_file "$REPO_DIR/local/bin/switch-audio.sh" "$BIN_DIR/switch-audio.sh" 755
}

run_integrations() {
    if ((NO_INTEGRATIONS)); then
        return 0
    fi

    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        run gtk-update-icon-cache -f -t "$DATA_HOME/icons/Win11-black" || warn "no se pudo actualizar la caché de iconos"
    fi
    if command -v update-desktop-database >/dev/null 2>&1; then
        run update-desktop-database "$DATA_HOME/applications" || true
    fi
    if command -v xdg-mime >/dev/null 2>&1; then
        backup_path "$CONFIG_HOME/mimeapps.list"
        run xdg-mime default thunar.desktop inode/directory || true
        run xdg-mime default thunar.desktop x-scheme-handler/file || true
    fi
    if command -v systemctl >/dev/null 2>&1; then
        run systemctl --user daemon-reload || true
        run systemctl --user try-restart thunar.service || true
    fi
    if [[ -x "$BIN_DIR/caelestia-kde-sync" ]] && \
        [[ -f "$CONFIG_HOME/qtengine/caelestia.colors" || -f "$DATA_HOME/color-schemes/Caelestia.colors" ]]; then
        run "$BIN_DIR/caelestia-kde-sync" || warn "caelestia-kde-sync no pudo aplicar los colores"
    fi
    if [[ -x "$BIN_DIR/hyprswitch-theme" ]]; then
        run "$BIN_DIR/hyprswitch-theme" >/dev/null 2>&1 || warn "no se pudo generar el tema de hyprswitch"
    fi
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
        run hyprctl reload || warn "no se pudo recargar Hyprland"
    fi
}

main() {
    while (($#)); do
        case "$1" in
            --dry-run) DRY_RUN=1; shift ;;
            -y|--yes) ASSUME_YES=1; shift ;;
            --install-packages) INSTALL_PACKAGES=1; shift ;;
            --no-deps) SKIP_DEPS=1; shift ;;
            --no-integrations) NO_INTEGRATIONS=1; shift ;;
            --wallpaper-dir)
                [[ $# -ge 2 ]] || die "--wallpaper-dir necesita una ruta"
                WALLPAPER_DIR="$2"; shift 2 ;;
            --wallpaper-dir=*) WALLPAPER_DIR="${1#*=}"; shift ;;
            -h|--help) usage; exit 0 ;;
            *) die "opción desconocida: $1" ;;
        esac
    done

    [[ -d "$REPO_DIR/config" ]] || die "no encuentro config/ en $REPO_DIR"
    resolve_wallpaper_dir
    check_dependencies

    info "HOME: $HOME_DIR"
    info "Backups: $BACKUP_ROOT"
    info "Fondos/vídeos: $WALLPAPER_DIR"
    if ((DRY_RUN)); then
        info "Modo simulación: no se escribirá nada"
    elif (( ! ASSUME_YES )); then
        confirm || exit 0
    fi

    if (( ! DRY_RUN )); then
        mkdir -p -- "$BACKUP_ROOT" "$WALLPAPER_DIR"
    fi

    install_payload
    run_integrations

    if ((DRY_RUN)); then
        ok "Simulación completada"
    else
        ok "Instalación completada"
        info "Backups en: $BACKUP_ROOT"
        info "Copia tus vídeos/fondos a: $WALLPAPER_DIR"
        info "Cierra sesión o reinicia Hyprland para aplicar los cambios"
    fi
}

main "$@"
