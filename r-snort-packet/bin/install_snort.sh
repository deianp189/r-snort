#!/bin/bash

instalar_snort3() {
  local SOFTWARE_DIR="$1"
  local INSTALL_DIR="$2"
  cd "$SOFTWARE_DIR"
  tar -xzf snort3.tar.gz
  cd snort3*/
  sed -i 's/\[ \"\\$NUMTHREADS\" -lt \"\\$MINTHREADS\" \]/[ \"${NUMTHREADS:-0}\" -lt \"${MINTHREADS:-1}\" ]/' configure_cmake.sh
  ./configure_cmake.sh --prefix="$INSTALL_DIR"
  cd build
  activar_swap_temporal_si_necesario
  log "Compilando Snort 3..."
  make -j"$(nproc)" || error "Fallo al compilar Snort 3."
  make install
  ldconfig
  ln -sf "$INSTALL_DIR/bin/snort" /usr/local/bin/snort
  success "Snort 3 instalado."
}