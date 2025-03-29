#!/bin/bash

temp_swap_if_necessary() {
  local mem_kb
  mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')

  if [ "$mem_kb" -lt 1500000 ]; then
    if ! free | awk '/^Swap:/ {exit !$2}'; then
      log "Creando swap temporal..."

      if ! fallocate -l 2G /swapfile_snort; then
        log "fallocate falló, usando dd como alternativa..."
        dd if=/dev/zero of=/swapfile_snort bs=1M count=2048 || {
          error "No se pudo crear swap con dd tampoco. Abortando."
          return 1
        }
      fi

      chmod 600 /swapfile_snort
      mkswap /swapfile_snort
      swapon /swapfile_snort
      success "Swap temporal creada en /swapfile_snort"
    else
      log "Swap ya activa. No se necesita crear otra."
    fi
  else
    log "RAM suficiente (≥1.5 GB). No se necesita swap temporal."
  fi
}

temp_swap_clean() {
  if swapon --show | grep -q "/swapfile_snort"; then
    log "Desactivando swap temporal..."
    if swapoff /swapfile_snort; then
      rm -f /swapfile_snort
      success "Swap temporal eliminada."
    else
      log "Swap ya estaba desactivada o no se pudo eliminar. Continuando."
    fi
  else
    log "No hay swap temporal activa. Nada que limpiar."
  fi
}
