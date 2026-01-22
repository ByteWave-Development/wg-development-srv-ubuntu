# 🚀 VPN Development Server Stack

Este script automatiza el despliegue de un entorno de desarrollo robusto, seguro y preconfigurado en un VPS (Ubuntu 22.04/24.04). Todo el acceso a las herramientas de desarrollo está protegido tras una **VPN WireGuard**, dejando expuesto al público únicamente el túnel cifrado.

---

## 🛠️ Componentes Incluidos

* **VPN:** WireGuard + WireGuard UI (Panel web) + Caddy (Proxy Inverso).
* **IDE:** Code-Server (VS Code en el navegador).
* **Base de Datos:** MySQL Server + phpMyAdmin (Dockerizado).
* **Lenguajes:** PHP (7.4, 8.1, 8.2, 8.3), Node.js (LTS via NVM), Python 3, Java (17/21), Go.
* **Herramientas:** Docker, Redis, ZSH (Oh My Zsh), Git, Composer, Pnpm, Poetry.
* **Seguridad:** Firewall UFW preconfigurado (Puertos cerrados por defecto).

---

## ⚡ Instalación Rápida con Parámetros

Ejecuta este comando para descargar, configurar e instalar todo automáticamente:

```bash
curl -sSL https://raw.githubusercontent.com/ByteWave-Development/wg-development-srv-ubuntu/main/generate_config.sh -o generate_config.sh && \
curl -sSL https://raw.githubusercontent.com/ByteWave-Development/wg-development-srv-ubuntu/main/deploy.sh -o deploy.sh && \
chmod +x generate_config.sh deploy.sh && \
./generate_config.sh /tmp/config.env 
  --WG_ENDPOINT "vpn.example.com" \
  --WG_UI_DOMAIN "vpn.example.com" \
  --ADMIN_PASSWORD "admin" \
  --DEV_USER "dev" \
  --CODE_PASSWORD "VSCode_PASSWORD" \
  --MYSQL_DEV_USER "dev_admin" \
  --MYSQL_DEV_PASSWORD "MySQL_PASSWORD" && \
export CONFIG_FILE=/tmp/config.env && sudo ./deploy.sh
```

### Parámetros Disponibles:

| Sección | Flag | Descripción | Valor por Defecto |
| --- | --- | --- | --- |
| **Generales** | `--DEBUG_MODE` | Activa mensajes detallados y pausas | `false` |
| **Módulos** | `--INSTALL_SYSTEM_UPDATE` | Actualiza repositorios y paquetes del SO | `true` |
| **Módulos** | `--INSTALL_DOCKER` | Instala Docker Engine y Compose | `true` |
| **Módulos** | `--INSTALL_BASE_PACKAGES` | Herramientas esenciales (curl, git, tmux...) | `true` |
| **Módulos** | `--INSTALL_WIREGUARD` | Servidor VPN WireGuard (Dual Stack) | `true` |
| **Módulos** | `--INSTALL_WIREGUARD_UI` | Interfaz web de gestión y Caddy Proxy | `true` |
| **Módulos** | `--INSTALL_JAVA` | OpenJDK 17 y 21 | `true` |
| **Módulos** | `--INSTALL_GO` | Entorno de lenguaje Go | `true` |
| **Módulos** | `--INSTALL_PHP` | PHP (7.4 a 8.3) + Extensiones + Composer | `true` |
| **Módulos** | `--INSTALL_REDIS` | Servidor Redis local | `true` |
| **Módulos** | `--INSTALL_NODEJS` | Node.js LTS vía NVM + Yarn/Pnpm | `true` |
| **Módulos** | `--INSTALL_PYTHON` | Python 3 + Pip + Poetry + Virtualenv | `true` |
| **Módulos** | `--INSTALL_CODE_SERVER` | Servidor VS Code Web | `true` |
| **Módulos** | `--INSTALL_OPENCODE_AI` | CLI de OpenCode AI | `true` |
| **Módulos** | `--INSTALL_PHPMYADMIN` | Contenedor Docker de phpMyAdmin | `true` |
| **Módulos** | `--INSTALL_ZSH` | Oh My Zsh + plugins (fzf, bat, rg) | `true` |
| **Módulos** | `--INSTALL_FIREWALL` | Configuración estricta de UFW | `true` |
| **VPN** | `--WG_ENDPOINT` | IP pública o dominio del servidor | `Auto-detectada` |
| **VPN** | `--WG_UI_DOMAIN` | IP pública o dominio del servidor para WG UI | `Auto-detectada` |
| **VPN** | `--WG_PORT` | Puerto UDP de la VPN | `51820` |
| **VPN** | `--WG_UI_PROXY_PORT` | Puerto público (HTTPS) para la UI | `8083` |
| **VPN** | `--ADMIN_PASSWORD` | Password para el panel WireGuard UI | `Aleatorio` |
| **VPN** | `--WG_IPV4_ADDR` | Rango IP interno (v4) | `10.7.0.1/24` |
| **VPN** | `--WG_HOST_IP` | IP VPN del servidor | "10.7.0.1" |
| **VPN** | `--WG_IPV6_ADDR` | Rango IP interno (v6) | `fddd:2c4...::1/64` |
| **Cuentas** | `--DEV_USER` | Nombre del usuario Linux y MySQL | `dev` |
| **Cuentas** | `--CODE_PASSWORD` | Password para VS Code Web | `Aleatorio` |
| **Cuentas** | `--MYSQL_DEV_USER` | Nombre del usuario super-dev en MySQL | `dev` |
| **Cuentas** | `--MYSQL_DEV_PASSWORD` | Password para acceso a bases de datos | `Aleatorio` |
| **Cuentas** | `--MYSQL_ALLOWED_NET` | Redes con permiso para conectar a MySQL | `127.0.0.1,10.7.0.%` |

---

## 📖 Guía de Uso Post-Instalación

### 1. Conectar a la VPN

1. Accede a la interfaz de gestión: `http://TU_IP:8083` (vía Caddy Proxy).
2. Usa el usuario `admin` y la contraseña definida en `--ADMIN_PASSWORD`.
3. Crea un cliente, descarga el archivo `.conf` y conéctate.

### 2. Acceso a Servicios Internos

Una vez conectado a la VPN, todos los servicios responden en la IP privada **`10.7.0.1`**:

* **VS Code:** `http://10.7.0.1:8080`
* **phpMyAdmin:** `http://10.7.0.1:8081`
* **WireGuard UI (Interno):** `http://10.7.0.1:8082`

### 3. Logs y Debugging

Si algo falla, puedes revisar los logs en caliente:

* **Principal:** `tail -f /var/log/vpn-dev-install.log`
* **Errores:** `tail -f /var/log/vpn-dev-install-errors.log`

---

## 📁 Estructura del Repositorio

* `deploy.sh`: El core del instalador (instala paquetes, configura servicios).
* `generate_config.sh`: Generador de archivos `.env` basado en flags.
* `config.env.example`: Plantilla de referencia para configuración manual.

---

## ⚠️ Notas de Seguridad

1. **Firewall:** UFW bloqueará todo el tráfico entrante excepto SSH y el puerto UDP de WireGuard.
2. **MySQL:** El usuario de desarrollo tiene privilegios totales (`GRANT ALL`). Úsalo con precaución.
3. **Certificados:** Caddy se configura con `tls internal`.