#!/bin/bash
mostrar_estadisticas() {
  local IFACE="$1"
  local INSTALL_DIR="$2"

  echo
  log "Resumen del sistema tras la instalación:"
  uptime_str=$(uptime -p)
  total_ram=$(free -h | awk '/Mem:/ {print $2}')
  used_ram=$(free -h | awk '/Mem:/ {print $3}')
  swap_enabled=$(swapon --noheadings | wc -l)
  swap_used=$(free -h | awk '/Swap:/ {print $3 "/" $2}')
  disk_usage=$(df -h / | awk 'NR==2 {print $3 " usados de " $2}')
  cpu_model=$(lscpu | grep "Model name" | sed 's/Model name:\s*//')
  cpu_cores=$(nproc)
  snort_version=$("$INSTALL_DIR/bin/snort" -V 2>/dev/null | grep -i "version" || echo "No encontrado")


  echo "──────────────────────────────────────────────────────"
  echo -e "💻 Hostname:           $(hostname)"
  echo -e "⏱  Uptime:             $uptime_str"
  echo -e "🧠 RAM usada:          $used_ram / $total_ram"
  echo -e "💾 Swap activa:        $([ "$swap_enabled" -eq 0 ] && echo "No" || echo "Sí ($swap_used)")"
  echo -e "📂 Espacio raíz:       $disk_usage"
  echo -e "🧠 CPU:                $cpu_model ($cpu_cores núcleos)"
  echo -e "🐗 Snort versión:      ${snort_version:-No encontrado}"
  echo -e "🌐 Interfaz activa:    $IFACE"
  echo "──────────────────────────────────────────────────────"

  success "Snort 3 está en ejecución en la interfaz: $IFACE."
}