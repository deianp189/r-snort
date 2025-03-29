#!/bin/bash

# -------------------------------
# Snort 3 Rollback Script
# -------------------------------

echo "[*] INICIANDO ROLLBACK COMPLETO DE SNORT 3..."

# 1. Detener el servicio de Snort
echo "[*] Deteniendo servicio snort si está activo..."
sudo systemctl stop snort 2>/dev/null
sudo systemctl disable snort 2>/dev/null

# 2. Eliminar archivos binarios
echo "[*] Eliminando binarios de Snort y DAQ..."
sudo rm -rf /usr/local/bin/snort*
sudo rm -rf /usr/local/lib/snort*
sudo rm -rf /usr/local/lib/daq*
sudo rm -rf /usr/local/include/snort*
sudo rm -rf /usr/local/include/daq*
sudo rm -rf /usr/local/lib/pkgconfig/snort*.pc
sudo rm -rf /usr/local/lib/pkgconfig/daq*.pc

# 3. Eliminar directorios y configuraciones
echo "[*] Eliminando directorios y configuraciones de Snort..."
sudo rm -rf /usr/local/snort
sudo rm -rf /usr/local/etc/snort
sudo rm -rf /usr/local/etc/daq
sudo rm -rf /etc/systemd/system/snort.service
sudo rm -rf /etc/ld.so.conf.d/snort.conf

# 4. Actualizar el caché de bibliotecas compartidas
echo "[*] Ejecutando ldconfig para limpiar caché de bibliotecas..."
sudo ldconfig

# 5. Borrar usuario/grupo snort (si existe)
echo "[*] Borrando usuario y grupo snort si existen..."
sudo userdel snort 2>/dev/null
sudo groupdel snort 2>/dev/null

# 6. Borrar logs y archivos temporales
echo "[*] Limpiando logs y archivos temporales..."
sudo rm -rf /var/log/snort
sudo rm -rf /tmp/snort*
sudo rm -rf /var/tmp/snort*

echo "[✔] Rollback completado. El sistema está limpio de Snort 3."
