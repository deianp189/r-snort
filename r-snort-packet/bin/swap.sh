#!/bin/bash

activar_swap_temporal_si_necesario() {
  local mem_kb
  mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  [ "$mem_kb" -lt 1500000 ] && ! free | awk '/^Swap:/ {exit !$2}' && {
    log "Creando swap temporal..."
    fallocate -l 2G /swapfile_snort || dd if=/dev/zero of=/swapfile_snort bs=1M count=2048
    chmod 600 /swapfile_snort
    mkswap /swapfile_snort
    swapon /swapfile_snort
    log "Swap temporal creada en /swapfile_snort"
  } || log "RAM suficiente o swap ya activa."
}

limpiar_swap_temporal() {
  swapon --show | grep -q "/swapfile_snort" && {
    log "Desactivando swap temporal..."
    swapoff /swapfile_snort && rm -f /swapfile_snort
    success "Swap temporal eliminada."
  }
}