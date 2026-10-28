#!/bin/bash

# Obtener el sink actual
current=$(pactl get-default-sink)

# Obtener la lista de todos los sinks (dispositivos de salida)
sinks=($(pactl list short sinks | awk '{print $2}'))

if [[ ${#sinks[@]} -eq 0 ]]; then
    notify-send -i audio-speakers "Salida de Audio" "No se encontraron dispositivos de salida"
    exit 1
fi

# Buscar en qué posición de la lista está el actual
current_idx=0
for i in "${!sinks[@]}"; do
    if [[ "${sinks[$i]}" == "$current" ]]; then
        current_idx=$i
        break
    fi
done

# Calcular el siguiente (si es el último, vuelve al primero)
next_idx=$(( (current_idx + 1) % ${#sinks[@]} ))
next_sink="${sinks[$next_idx]}"

# Cambiar el audio al siguiente dispositivo
pactl set-default-sink "$next_sink"

# Obtener el campo Description del sink (nombre legible, ej. 'GAMING HEADSET GT808')
description=$(pactl list sinks | awk -v target="$next_sink" '
    /^Sink #/ {
        if (name == target && desc != "") { print desc; found = 1; exit }
        name = ""; desc = ""
    }
    /^[[:space:]]*Name:/ { name = $2 }
    /^[[:space:]]*Description:/ {
        sub(/^[[:space:]]*Description:[[:space:]]*/, "")
        desc = $0
    }
    END { if (!found && name == target && desc != "") print desc }
')

# Si no se encontró la descripción, usar el nombre técnico como respaldo
[[ -z "$description" ]] && description="$next_sink"

# Mostrar la notificación visual
notify-send -i audio-speakers "Salida de Audio" "Cambiado a: $description"
