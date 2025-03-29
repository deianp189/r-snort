#!/bin/bash
check_root() {
  [ "$(id -u)" -eq 0 ] || error "Este script debe ejecutarse como root."
}

interface_selection() {
  log "Detectando interfaces de red disponibles..."
  mapfile -t interfaces < <(ip -brief link | awk '{print $1}' | grep -v '^lo$')

  if (( ${#interfaces[@]} == 0 )); then
    error "No se encontraron interfaces válidas. Verifica que estén conectadas y activas."
  fi

  echo "Seleccione una interfaz de red:"
  for i in "${!interfaces[@]}"; do
    echo "  [$i] ${interfaces[$i]}"
  done

  read -rp "Introduce el número correspondiente a la interfaz: " selected_index

  [[ ! "$selected_index" =~ ^[0-9]+$ ]] && error "Entrada inválida. Debe ser un número."
  (( selected_index < 0 || selected_index >= ${#interfaces[@]} )) && error "Número fuera de rango. Selección no válida."

  IFACE="${interfaces[$selected_index]}"
  log "Interfaz seleccionada: $IFACE"
}
