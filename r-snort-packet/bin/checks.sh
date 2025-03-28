#!/bin/bash

check_root() {
  [ "$(id -u)" -eq 0 ] || error "Este script debe ejecutarse como root."
}

seleccionar_interfaz() {
  mapfile -t interfaces < <(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
  (( ${#interfaces[@]} == 0 )) && error "No se encontraron interfaces válidas."

  echo "Seleccione una interfaz de red:"
  for i in "${!interfaces[@]}"; do echo "  [$i] ${interfaces[$i]}"; done
  read -rp "Introduce el número correspondiente: " selected_index

  [[ ! "$selected_index" =~ ^[0-9]+$ ]] && error "Debe ser un número."
  (( selected_index < 0 || selected_index >= ${#interfaces[@]} )) && error "Fuera de rango."
  echo "${interfaces[$selected_index]}"
}