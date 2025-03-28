# R-SNORT INSTALLER

Instalador profesional y automatizado de Snort 3.7 para sistemas Linux con arquitectura ARM y x86.

---

## ✨ Descripción
**R-SNORT** es un script de instalación automática y profesional de **Snort 3.7**, un sistema de detección de intrusos (NIDS) de alto rendimiento.

Pensado para Raspberry Pi y otros entornos ligeros, automatiza:
- Instalación de dependencias del sistema.
- Compilación desde fuentes de todos los componentes necesarios.
- Configuración completa de Snort con reglas de comunidad, reglas personalizadas y bloqueos IP.
- Creación del servicio systemd para ejecución permanente.

---

## ⚙️ Requisitos
- Linux (Debian/Ubuntu preferido)
- Ejecutar como **root**
- Conexión a Internet

---

## 🚀 Ejecución
```bash
sudo ./instalador.sh
```
El script le pedirá seleccionar la interfaz de red a monitorizar. El resto se ejecuta de forma completamente automática.

---

## 🌐 Estructura del Proyecto
```
R-SNORT/
├── configuracion/               # Archivos snort.lua, reglas y blocklists
├── software/                    # Paquetes .tar.gz necesarios para compilar
├── instalador.sh                # Script principal de instalación
├── README.md
```

---

## 🔧 Características
- Instalación limpia y profesional
- Swap solo si es necesario (<1.5 GB RAM)
- Configuración automática de Snort con community rules y reglas personalizadas
- Servicio Snort para systemd generado dinámicamente
- Compatible con Raspberry Pi 5 y arquitecturas ARM64 / x86_64

---

## 🌐 Tecnologías utilizadas
- Snort 3.7
- LuaJIT
- OpenSSL
- DAQ, PCRE2, zlib, hwloc, etc.
- Linux Systemd

---

## 🎯 Ejemplo de ejecución
```bash
[*] Copiando archivos de configuración finales...
[*] Creando reputación y community rules...
[*] Descomprimiendo community rules...
[*] Activando e iniciando servicio Snort...
[✓] Snort 3 instalado y configurado completamente.
Snort 3 está en ejecución en la interfaz: eth0
```

---

## 📈 Ejemplo de alerta generada
```
[**] [1:1000001:0] Intento de acceso HTTP sospechoso [**]
[Priority: 2]
03/28-00:11:51.522594 192.168.1.101 -> 93.184.216.34
TCP TTL:64 TOS:0x0 ID:54321 IpLen:20 DgmLen:1500
```

---

## 🚜 Futuras mejoras
- Web UI de configuración
- Almacenamiento en base de datos
- Exportación de alertas
- Dashboard con estadísticas

---

## 🙌 Autor
Desarrollado por Deian Orlando Petrovics (2025)

---

> R-SNORT es un proyecto de código abierto orientado a facilitar la ciberseguridad accesible, robusta y automatizada.

