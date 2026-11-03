#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
HOME_DIR="${HOME:?HOME no está definido}"
SRC_DIR="${HYPRSWITCH_SRC:-$HOME_DIR/.local/src/hyprswitch}"
BIN_DIR="${XDG_BIN_HOME:-$HOME_DIR/.local/bin}"
COMMIT="3b5bb6a37e8cd60e32e573a6a82231e8bbe27d82"
CRATE="hyprland-0.4.0-beta.3"
PATCH="$REPO_DIR/patches/$CRATE-workspace-id.patch"

DRY_RUN=0
INSTALL=1
RESTART=1

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
Uso: ./scripts/build-hyprswitch-patched.sh [opciones]

Compila hyprswitch 5.0.0 (fork egnrse) con un parche para hyprland-rs
0.4.0-beta.3 que hace opcional WorkspaceBasic.id. Necesario en Hyprland
0.57+, donde specialWorkspace ya no incluye "id".

Opciones:
  --dry-run          Muestra los comandos sin ejecutarlos.
  --no-install       Compila pero no instala en ~/.local/bin.
  --no-restart       No reinicia el watcher/daemon de hyprswitch.
  --src-dir DIR      Directorio de compilación (por defecto ~/.local/src/hyprswitch).
  -h, --help         Muestra esta ayuda.

Requiere: git, cargo/rustc y el paquete gtk4-layer-shell.
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

while (($#)); do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --no-install) INSTALL=0; shift ;;
        --no-restart) RESTART=0; shift ;;
        --src-dir)
            [[ $# -ge 2 ]] || die "--src-dir necesita una ruta"
            SRC_DIR="$2"; shift 2 ;;
        --src-dir=*) SRC_DIR="${1#*=}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "opción desconocida: $1" ;;
    esac
done

[[ -f "$PATCH" ]] || die "falta el parche: $PATCH"
command -v git >/dev/null 2>&1 || die "falta git"
command -v cargo >/dev/null 2>&1 || die "falta cargo; instala rust con: sudo pacman -S rust"
command -v patch >/dev/null 2>&1 || die "falta patch (paquete patch)"

info "hyprswitch parcheado (Hyprland 0.57+)"
info "fuente: $SRC_DIR"
info "commit: $COMMIT"

if [[ -d "$SRC_DIR/.git" ]]; then
    run git -C "$SRC_DIR" fetch --quiet origin
else
    run mkdir -p -- "$(dirname -- "$SRC_DIR")"
    run git clone --quiet https://github.com/egnrse/hyprswitch.git "$SRC_DIR"
fi
run git -C "$SRC_DIR" checkout --quiet --force "$COMMIT"

VENDOR="$SRC_DIR/vendor/$CRATE"
if [[ ! -d "$VENDOR" ]]; then
    run mkdir -p -- "$SRC_DIR/vendor"
    crate_src=""
    for candidate in "$HOME_DIR"/.cargo/registry/src/index.crates.io-*/"$CRATE"; do
        if [[ -d "$candidate" ]]; then
            crate_src="$candidate"
            break
        fi
    done
    if [[ -n "$crate_src" ]]; then
        run cp -a -- "$crate_src" "$VENDOR"
        run rm -f -- "$VENDOR/.cargo-ok"
    else
        command -v curl >/dev/null 2>&1 || die "falta curl para descargar $CRATE"
        tmp_dir="$(mktemp -d)"
        run curl -fsSL "https://crates.io/api/v1/crates/hyprland/0.4.0-beta.3/download" -o "$tmp_dir/hyprland.crate"
        run tar -xzf "$tmp_dir/hyprland.crate" -C "$SRC_DIR/vendor"
        run rm -rf -- "$tmp_dir"
    fi
fi

if patch -p1 -N --dry-run -d "$VENDOR" < "$PATCH" >/dev/null 2>&1; then
    run patch -p1 -d "$VENDOR" < "$PATCH"
elif patch -p1 -R --dry-run -d "$VENDOR" < "$PATCH" >/dev/null 2>&1; then
    info "el parche ya estaba aplicado"
else
    die "no se pudo aplicar el parche; revisa $VENDOR/src/data/regular.rs"
fi

if ! grep -q '^hyprland = { path = "vendor/' "$SRC_DIR/Cargo.toml"; then
    if grep -q '^\[patch.crates-io\]' "$SRC_DIR/Cargo.toml"; then
        die "ya existe [patch.crates-io]; añade hyprland = { path = \"vendor/$CRATE\" } a mano"
    fi
    if ((DRY_RUN)); then
        info "añadir [patch.crates-io] hyprland -> vendor/$CRATE"
    else
        printf '\n[patch.crates-io]\nhyprland = { path = "vendor/%s" }\n' "$CRATE" >> "$SRC_DIR/Cargo.toml"
    fi
fi

run cargo build --release --manifest-path "$SRC_DIR/Cargo.toml"
BIN="$SRC_DIR/target/release/hyprswitch"
[[ -x "$BIN" ]] || die "no se generó $BIN"

if ((INSTALL)); then
    run mkdir -p -- "$BIN_DIR"
    if [[ -e "$BIN_DIR/hyprswitch" ]]; then
        backup="$BIN_DIR/hyprswitch.bak-$(date +%Y%m%d-%H%M%S)"
        run cp -a -- "$BIN_DIR/hyprswitch" "$backup"
        info "backup: $backup"
    fi
    run install -m755 -- "$BIN" "$BIN_DIR/hyprswitch"
    if ((DRY_RUN)); then
        info "instalaría: $BIN_DIR/hyprswitch"
    else
        ok "instalado: $BIN_DIR/hyprswitch"
    fi
fi

if ((RESTART)) && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    if pgrep -f 'hyprswitch-theme-watch' >/dev/null 2>&1; then
        run pkill -f 'hyprswitch-theme-watch' || true
        sleep 0.3
    fi
    if pgrep -x hyprswitch >/dev/null 2>&1; then
        run pkill -x hyprswitch || true
        sleep 0.3
    fi
    sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hyprswitch.sock"
    if [[ -S "$sock" ]]; then
        run rm -f -- "$sock"
    fi
    if [[ -x "$BIN_DIR/hyprswitch-theme-watch" ]]; then
        if ((DRY_RUN)); then
            run setsid -f "$BIN_DIR/hyprswitch-theme-watch"
            info "reiniciaría el daemon hyprswitch"
        else
            setsid -f "$BIN_DIR/hyprswitch-theme-watch" >/dev/null 2>&1
            sleep 1
            if pgrep -x hyprswitch >/dev/null 2>&1; then
                ok "daemon hyprswitch reiniciado"
            else
                warn "el daemon no arrancó; revisa ~/.local/bin/hyprswitch-theme-watch"
            fi
        fi
    fi
fi

if ((DRY_RUN)); then
    ok "simulación completada"
else
    ok "build completado"
fi
