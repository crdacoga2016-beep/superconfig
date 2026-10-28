#!/bin/sh
# Aviso "Copiado" cuando se copia texto con kitty enfocado.
cat >/dev/null

[ "$CLIPBOARD_STATE" = data ] || exit 0

class="$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty' 2>/dev/null)"
[ "$class" = kitty ] || exit 0

notify-send -a kitty -t 1200 -i edit-copy "Copiado"
