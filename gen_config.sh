#!/bin/bash

# Primer argumento: Ruta de salida
OUTPUT_FILE="$1"
if [ -z "$OUTPUT_FILE" ]; then
    echo "Error: Debes especificar la ruta de salida como primer argumento."
    echo "Uso: ./generate_config.sh /ruta/al/archivo.env [FLAGS]"
    exit 1
fi
shift # Quitar la ruta de los argumentos para procesar los flags

# --- VALORES POR DEFECTO ---
PUBLIC_IP=$(curl -s https://ifconfig.me/ip || echo "vpn.example.com")
DEBUG_MODE="false"
INSTALL_SYSTEM_UPDATE="true"
INSTALL_DOCKER="true"
INSTALL_BASE_PACKAGES="true"
INSTALL_WIREGUARD="true"
INSTALL_WIREGUARD_UI="true"
INSTALL_JAVA="true"
INSTALL_GO="true"
INSTALL_PHP="true"
INSTALL_REDIS="true"
INSTALL_NODEJS="true"
INSTALL_PYTHON="true"
INSTALL_CODE_SERVER="true"
INSTALL_OPENCODE_AI="true"
INSTALL_PHPMYADMIN="true"
INSTALL_ZSH="true"
INSTALL_FIREWALL="true"
WG_ENDPOINT="$PUBLIC_IP"
WG_PORT="51820"
WG_IPV4_ADDR="10.7.0.1/24"
WG_IPV6_ADDR="fddd:2c4:2c4:2c4::1/64"
DNS_IPV4="1.1.1.1"
DNS_IPV6="2606:4700::1111"
WG_HOST_IP="10.7.0.1"
WG_UI_DOMAIN="$PUBLIC_IP"
WG_UI_PORT="8082"
WG_UI_PROXY_PORT="8083"
ADMIN_PASSWORD=$(openssl rand -base64 12)
DEV_USER="dev"
CODE_PORT="8080"
CODE_PASSWORD=$(openssl rand -base64 12)
MYSQL_DEV_USER="dev"
MYSQL_DEV_PASSWORD=$(openssl rand -base64 12)
MYSQL_ALLOWED_NET="127.0.0.1,10.7.0.%"
PHPMYADMIN_PORT="8081"

# --- PROCESAMIENTO DE FLAGS ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --DEBUG_MODE) DEBUG_MODE="$2"; shift ;;
        --INSTALL_*) # Captura dinámica para todos los módulos INSTALL_
            var_name=$(echo $1 | sed 's/--//')
            eval "$var_name=\"$2\""
            shift ;;
        --WG_ENDPOINT) WG_ENDPOINT="$2"; shift ;;
        --WG_HOST_IP) WG_HOST_IP="$2"; shift ;;
        --WG_PORT) WG_PORT="$2"; shift ;;
        --WG_IPV4_ADDR) WG_IPV4_ADDR="$2"; shift ;;
        --WG_IPV6_ADDR) WG_IPV6_ADDR="$2"; shift ;;
        --WG_UI_DOMAIN) WG_UI_DOMAIN="$2"; shift ;;
        --WG_UI_PROXY_PORT) WG_UI_PROXY_PORT="$2"; shift ;;
        --ADMIN_PASSWORD) ADMIN_PASSWORD="$2"; shift ;;
        --DEV_USER) DEV_USER="$2"; shift ;;
        --CODE_PASSWORD) CODE_PASSWORD="$2"; shift ;;
        --MYSQL_DEV_PASSWORD) MYSQL_DEV_PASSWORD="$2"; shift ;;
        --MYSQL_DEV_USER) MYSQL_DEV_USER="$2"; shift ;;
        *) echo "Flag desconocido: $1"; shift ;;
    esac
    shift
done

# --- ESCRITURA DEL ARCHIVO ---
cat <<EOF > "$OUTPUT_FILE"
### ================= CONFIGURACIÓN DE DEBUG Y MÓDULOS =================
DEBUG_MODE=$DEBUG_MODE

INSTALL_SYSTEM_UPDATE=$INSTALL_SYSTEM_UPDATE
INSTALL_DOCKER=$INSTALL_DOCKER
INSTALL_BASE_PACKAGES=$INSTALL_BASE_PACKAGES
INSTALL_WIREGUARD=$INSTALL_WIREGUARD
INSTALL_WIREGUARD_UI=$INSTALL_WIREGUARD_UI
INSTALL_JAVA=$INSTALL_JAVA
INSTALL_GO=$INSTALL_GO
INSTALL_PHP=$INSTALL_PHP
INSTALL_REDIS=$INSTALL_REDIS
INSTALL_NODEJS=$INSTALL_NODEJS
INSTALL_PYTHON=$INSTALL_PYTHON
INSTALL_CODE_SERVER=$INSTALL_CODE_SERVER
INSTALL_OPENCODE_AI=$INSTALL_OPENCODE_AI
INSTALL_PHPMYADMIN=$INSTALL_PHPMYADMIN
INSTALL_ZSH=$INSTALL_ZSH
INSTALL_FIREWALL=$INSTALL_FIREWALL

### ================= WIREGUARD CONFIG =================
WG_ENDPOINT="$WG_ENDPOINT"
WG_PORT=$WG_PORT
WG_IPV4_ADDR="$WG_IPV4_ADDR"
WG_IPV6_ADDR="$WG_IPV6_ADDR"
DNS_IPV4="$DNS_IPV4"
DNS_IPV6="$DNS_IPV6"
WG_HOST_IP="$WG_HOST_IP"
WG_UI_DOMAIN="$WG_UI_DOMAIN"
WG_UI_PORT=$WG_UI_PORT
WG_UI_PROXY_PORT=$WG_UI_PROXY_PORT
ADMIN_PASSWORD="$ADMIN_PASSWORD"

### ================= DEV CONFIG =================
DEV_USER="$DEV_USER"
CODE_PORT="$CODE_PORT"
CODE_PASSWORD="$CODE_PASSWORD"

### ================= MYSQL / PHPMYADMIN =================
MYSQL_DEV_USER="$MYSQL_DEV_USER"
MYSQL_DEV_PASSWORD="$MYSQL_DEV_PASSWORD"
MYSQL_ALLOWED_NET="$MYSQL_ALLOWED_NET"
PHPMYADMIN_PORT="$PHPMYADMIN_PORT"
EOF

echo "Archivo generado en $OUTPUT_FILE con los parámetros proporcionados."
