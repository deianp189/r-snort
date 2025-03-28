#!/bin/bash

instalar_snort() {
  local SOFTWARE_DIR="$1"
  local INSTALL_DIR="$2"
  local EXTRA_FLAGS="$3"

  log "Preparando instalación de Snort 3 (versión estable sin NUMA)..."

  cd "$SOFTWARE_DIR"
  tar -xzf snort3.tar.gz
  cd "$(find . -maxdepth 1 -type d -name 'snort3*' | head -n 1)"

  # 🧹 Limpieza de parches NUMA (ya no son necesarios)
  log "Saltando parches NUMA: versión antigua ya compatible."

  # Corrige bug de hilos si es necesario
  sed -i 's/\[ \"\\$NUMTHREADS\" -lt \"\\$MINTHREADS\" \]/[ \"${NUMTHREADS:-0}\" -lt \"${MINTHREADS:-1}\" ]/' configure_cmake.sh

  # Limpia flags para evitar arrastrar -lnuma
  unset LDFLAGS
  unset CXXFLAGS
  export LDFLAGS=""
  export CXXFLAGS="-Wno-deprecated-declarations"

  # Ejecuta el script de configuración
  ./configure_cmake.sh --prefix="$INSTALL_DIR"

  cd build
  activar_swap_temporal_si_necesario

  log "Compilando Snort 3. Puede tardar un rato..."
  make -j"$(nproc)" || error "Fallo en make al compilar Snort 3."
  make install
  ldconfig

  # Crea symlink para 'snort'
  ln -sf "$INSTALL_DIR/bin/snort" /usr/local/bin/snort

  success "Snort 3 instalado con éxito."
}
