#!/bin/bash

snort_install() {
  local SOFTWARE_DIR="$1"
  local INSTALL_DIR="$2"

  log "Preparando instalación de Snort 3 (versión estable sin soporte NUMA)..."

  cd "$SOFTWARE_DIR"
  tar -xzf snort3.tar.gz
  cd "$(find . -maxdepth 1 -type d -name 'snort3*' | head -n 1)"

  # Corrige bug de hilos si es necesario (solo versiones antiguas)
  sed -i 's/\[ \"\\$NUMTHREADS\" -lt \"\\$MINTHREADS\" \]/[ \"${NUMTHREADS:-0}\" -lt \"${MINTHREADS:-1}\" ]/' configure_cmake.sh

  # Prevenir advertencias por OpenSSL 3+
  unset LDFLAGS
  unset CXXFLAGS
  export LDFLAGS=""
  export CXXFLAGS="-Wno-deprecated-declarations"

  ./configure_cmake.sh --prefix="$INSTALL_DIR"

  cd build
  temp_swap_if_necessary

  log "Compilando Snort 3. Puede tardar un rato..."
  make -j"$(nproc)" || error "Fallo en make al compilar Snort 3."
  make install
  ldconfig

  ln -sf "$INSTALL_DIR/bin/snort" /usr/local/bin/snort

  success "Snort 3 instalado con éxito."
}
