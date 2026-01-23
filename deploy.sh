#!/bin/bash
set -e

# Cargar configuración
CONFIG_FILE="${CONFIG_FILE:-/tmp/config.env}"
if [ -f "$CONFIG_FILE" ]; then
    echo "Cargando configuración desde: $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo "⚠️  Usando configuración por defecto (no recomendado para producción)"
fi

### ================= CONFIGURACIÓN DE DEBUG Y MÓDULOS =================
DEBUG_MODE=${DEBUG_MODE:-false}

INSTALL_SYSTEM_UPDATE=${INSTALL_SYSTEM_UPDATE:-true}
INSTALL_DOCKER=${INSTALL_DOCKER:-true}
INSTALL_BASE_PACKAGES=${INSTALL_BASE_PACKAGES:-true}
INSTALL_WIREGUARD=${INSTALL_WIREGUARD:-true}
INSTALL_WIREGUARD_UI=${INSTALL_WIREGUARD_UI:-true}
INSTALL_JAVA=${INSTALL_JAVA:-true}
INSTALL_GO=${INSTALL_GO:-true}
INSTALL_PHP=${INSTALL_PHP:-true}
INSTALL_REDIS=${INSTALL_REDIS:-true}
INSTALL_NODEJS=${INSTALL_NODEJS:-true}
INSTALL_PYTHON=${INSTALL_PYTHON:-true}
INSTALL_CODE_SERVER=${INSTALL_CODE_SERVER:-true}
INSTALL_OPENCODE_AI=${INSTALL_OPENCODE_AI:-true}
INSTALL_PHPMYADMIN=${INSTALL_PHPMYADMIN:-true}
INSTALL_ZSH=${INSTALL_ZSH:-true}
INSTALL_FIREWALL=${INSTALL_FIREWALL:-true}

LOG_FILE="/var/log/vpn-dev-install.log"
ERROR_LOG="/var/log/vpn-dev-install-errors.log"

### ================= WIREGUARD CONFIG =================
WG_ENDPOINT=${WG_ENDPOINT:-"vpn.example.com"}
WG_PORT=${WG_PORT:-51820}
WG_IPV4_ADDR=${WG_IPV4_ADDR:-"10.7.0.1/24"}
WG_IPV6_ADDR=${WG_IPV6_ADDR:-"fddd:2c4:2c4:2c4::1/64"}
DNS_IPV4=${DNS_IPV4:-"1.1.1.1"}
DNS_IPV6=${DNS_IPV6:-"2606:4700::1111"}
WG_HOST_IP=${WG_HOST_IP:-"10.7.0.1"}
WG_UI_DOMAIN=${WG_UI_DOMAIN:-"vpn.example.com"}
WG_UI_PORT=${WG_UI_PORT:-8082}
WG_UI_PROXY_PORT=${WG_UI_PROXY_PORT:-8083}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-"admin"}
DB_PATH="/etc/wireguard/db"
WG_PATH="/etc/wireguard"

### ================= DEV CONFIG =================
DEV_USER=${DEV_USER:-"dev"}
CODE_PORT=${CODE_PORT:-"8080"}
CODE_PASSWORD=${CODE_PASSWORD:-"CHANGE_ME"}

### ================= MYSQL / PHPMYADMIN =================
MYSQL_DEV_USER=${MYSQL_DEV_USER:-"dev"}
MYSQL_DEV_PASSWORD=${MYSQL_DEV_PASSWORD:-"DEV_STRONG_PASSWORD"}
MYSQL_ALLOWED_NET=${MYSQL_ALLOWED_NET:-"127.0.0.1,10.7.0.%"}
PHPMYADMIN_PORT=${PHPMYADMIN_PORT:-"8081"}

export DEBIAN_FRONTEND=noninteractive

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then 
   echo "Este script debe ejecutarse como root"
   exit 1
fi

# Inicializar archivos de log
mkdir -p "$(dirname "$LOG_FILE")"
echo "=== Instalación iniciada: $(date) ===" > "$LOG_FILE"
echo "=== Log de errores: $(date) ===" > "$ERROR_LOG"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# Caracteres del spinner
SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
SPINNER_PID=""

# Función de logging
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
    
    if [ "$DEBUG_MODE" = true ]; then
        echo -e "${CYAN}[DEBUG]${NC} $message"
    fi
}

log_error() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $message" >> "$ERROR_LOG"
    echo -e "${RED}[ERROR]${NC} $message"
}

# Función para ejecutar comandos con logging
run_command() {
    local cmd="$1"
    local description="$2"
    
    log_message "INFO" "Ejecutando: $description"
    log_message "DEBUG" "Comando: $cmd"
    
    if [ "$DEBUG_MODE" = true ]; then
        echo -e "${YELLOW}→${NC} $cmd"
        eval "$cmd" 2>&1 | tee -a "$LOG_FILE"
        local exit_code=${PIPESTATUS[0]}
    else
        eval "$cmd" >> "$LOG_FILE" 2>&1
        local exit_code=$?
    fi
    
    if [ $exit_code -ne 0 ]; then
        log_error "Falló: $description (exit code: $exit_code)"
        return $exit_code
    fi
    
    log_message "INFO" "Completado: $description"
    return 0
}

# Función para mostrar el spinner
show_spinner() {
    local message="$1"
    local i=0
    
    while true; do
        printf "\r${CYAN}${SPINNER_FRAMES[$i]}${NC} ${WHITE}%s${NC}" "$message"
        i=$(( (i + 1) % ${#SPINNER_FRAMES[@]} ))
        sleep 0.1
    done
}

# Iniciar spinner
start_spinner() {
    local message="$1"
    if [ "$DEBUG_MODE" != true ]; then
        show_spinner "$message" &
        SPINNER_PID=$!
        disown
    else
        echo -e "${CYAN}▶${NC} ${WHITE}${message}${NC}"
    fi
}

# Detener spinner con resultado
stop_spinner() {
    local status=$1
    local message="$2"
    
    if [ "$DEBUG_MODE" != true ] && [ -n "$SPINNER_PID" ]; then
        kill $SPINNER_PID 2>/dev/null || true
        wait $SPINNER_PID 2>/dev/null || true
    fi
    
    if [ $status -eq 0 ]; then
        printf "\r${GREEN}✓${NC} ${WHITE}%s${NC}\n" "$message"
        log_message "SUCCESS" "$message"
    else
        printf "\r${RED}✗${NC} ${WHITE}%s${NC}\n" "$message"
        log_error "$message"
    fi
    
    SPINNER_PID=""
}

# Función para verificar si un módulo está habilitado
check_module() {
    local module_var="$1"
    local module_name="$2"
    
    if [ "${!module_var}" != true ]; then
        echo -e "${YELLOW}⊘${NC} ${WHITE}Módulo deshabilitado: ${module_name}${NC}"
        log_message "INFO" "Módulo deshabilitado: $module_name"
        return 1
    fi
    return 0
}

# Función para mostrar títulos de sección
print_section() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log_message "SECTION" "$1"
}

# Función para pausar en modo debug
debug_pause() {
    if [ "$DEBUG_MODE" = true ]; then
        echo -e "${YELLOW}[DEBUG]${NC} Presiona Enter para continuar..."
        read -r
    fi
}

# Banner de inicio
clear
echo -e "${BOLD}${MAGENTA}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   ██╗   ██╗██████╗ ███╗   ██╗    ██████╗ ███████╗██╗   ██╗   ║
║   ██║   ██║██╔══██╗████╗  ██║    ██╔══██╗██╔════╝██║   ██║   ║
║   ██║   ██║██████╔╝██╔██╗ ██║    ██║  ██║█████╗  ██║   ██║   ║
║   ╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║    ██║  ██║██╔══╝  ╚██╗ ██╔╝   ║
║    ╚████╔╝ ██║     ██║ ╚████║    ██████╔╝███████╗ ╚████╔╝    ║
║     ╚═══╝  ╚═╝     ╚═╝  ╚═══╝    ╚═════╝ ╚══════╝  ╚═══╝     ║
║                                                              ║
║            Servidor de Desarrollo con WireGuard              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

if [ "$DEBUG_MODE" = true ]; then
    echo -e "${YELLOW}⚠️  MODO DEBUG ACTIVADO${NC}"
    echo -e "${CYAN}   Log principal: $LOG_FILE${NC}"
    echo -e "${CYAN}   Log de errores: $ERROR_LOG${NC}"
fi

echo ""
echo -e "${BOLD}${CYAN}Módulos habilitados:${NC}"
[ "$INSTALL_SYSTEM_UPDATE" = true ] && echo -e "  ${GREEN}✓${NC} Actualización del sistema"
[ "$INSTALL_DOCKER" = true ] && echo -e "  ${GREEN}✓${NC} Docker"
[ "$INSTALL_BASE_PACKAGES" = true ] && echo -e "  ${GREEN}✓${NC} Paquetes base"
[ "$INSTALL_WIREGUARD" = true ] && echo -e "  ${GREEN}✓${NC} WireGuard"
[ "$INSTALL_WIREGUARD_UI" = true ] && echo -e "  ${GREEN}✓${NC} WireGuard UI"
[ "$INSTALL_JAVA" = true ] && echo -e "  ${GREEN}✓${NC} Java"
[ "$INSTALL_GO" = true ] && echo -e "  ${GREEN}✓${NC} Go"
[ "$INSTALL_PHP" = true ] && echo -e "  ${GREEN}✓${NC} PHP"
[ "$INSTALL_REDIS" = true ] && echo -e "  ${GREEN}✓${NC} Redis"
[ "$INSTALL_NODEJS" = true ] && echo -e "  ${GREEN}✓${NC} Node.js"
[ "$INSTALL_PYTHON" = true ] && echo -e "  ${GREEN}✓${NC} Python"
[ "$INSTALL_CODE_SERVER" = true ] && echo -e "  ${GREEN}✓${NC} Code-server"
[ "$INSTALL_OPENCODE_AI" = true ] && echo -e "  ${GREEN}✓${NC} OpenCode AI"
[ "$INSTALL_PHPMYADMIN" = true ] && echo -e "  ${GREEN}✓${NC} phpMyAdmin"
[ "$INSTALL_ZSH" = true ] && echo -e "  ${GREEN}✓${NC} ZSH"
[ "$INSTALL_FIREWALL" = true ] && echo -e "  ${GREEN}✓${NC} Firewall"
echo ""

sleep 2

# Detectamos la interfaz principal de internet para el NAT
log_message "INFO" "Detectando interfaz de red principal..."
MAIN_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
log_message "INFO" "Interfaz principal: $MAIN_IFACE"

debug_pause

### ================= ACTUALIZACIÓN DEL SISTEMA =================
if check_module "INSTALL_SYSTEM_UPDATE" "Actualización del Sistema"; then
    print_section "ACTUALIZACIÓN DEL SISTEMA"

    start_spinner "Actualizando repositorios..."
    run_command "apt-get update" "Actualizar repositorios"
    stop_spinner $? "Repositorios actualizados"

    start_spinner "Actualizando paquetes del sistema..."
    run_command "apt-get upgrade -y" "Actualizar paquetes"
    stop_spinner $? "Sistema actualizado correctamente"
    
    debug_pause
fi

### ================= DOCKER (OFICIAL) =================
if check_module "INSTALL_DOCKER" "Docker"; then
    print_section "INSTALACIÓN DE DOCKER (REPOSITORIO OFICIAL)"

    start_spinner "Instalando dependencias de Docker..."
    run_command "apt-get install -y ca-certificates curl" "Instalar dependencias Docker"
    stop_spinner $? "Dependencias de Docker instaladas"

    start_spinner "Agregando repositorio oficial de Docker..."
    run_command "install -m 0755 -d /etc/apt/keyrings" "Crear directorio keyrings"
    run_command "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc" "Descargar GPG key"
    run_command "chmod a+r /etc/apt/keyrings/docker.asc" "Ajustar permisos GPG key"
    
    cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    stop_spinner $? "Repositorio Docker agregado"

    start_spinner "Actualizando repositorios..."
    run_command "apt-get update" "Actualizar repositorios con Docker"
    stop_spinner $? "Repositorios actualizados"

    start_spinner "Instalando Docker Engine y plugins..."
    run_command "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin" "Instalar Docker"
    stop_spinner $? "Docker instalado correctamente"
    
    start_spinner "Habilitando Docker..."
    run_command "systemctl enable docker" "Habilitar Docker"
    run_command "systemctl start docker" "Iniciar Docker"
    stop_spinner $? "Docker habilitado y corriendo"
    
    debug_pause
fi

### ================= PAQUETES BASE =================
if check_module "INSTALL_BASE_PACKAGES" "Paquetes Base"; then
    print_section "INSTALACIÓN DE PAQUETES BASE"

    start_spinner "Instalando paquetes esenciales..."
    run_command "apt-get install -y curl wget tar jq wireguard iptables ufw software-properties-common apt-transport-https ca-certificates lsb-release git unzip zsh tmux htop build-essential mysql-server python3 python3-pip" "Instalar paquetes base"
    stop_spinner $? "Paquetes base instalados"
    
    debug_pause
fi

### ================= WIREGUARD =================
if check_module "INSTALL_WIREGUARD" "WireGuard"; then
    print_section "INSTALACIÓN DE WIREGUARD DUAL-STACK"

    start_spinner "Instalando WireGuard y dependencias..."
    run_command "apt-get update" "Actualizar repositorios"
    run_command "apt-get install -y wireguard iptables" "Instalar WireGuard"
    stop_spinner $? "WireGuard y dependencias instaladas"

    start_spinner "Habilitando IP forwarding (v4 y v6)..."
    cat <<EOF >/etc/sysctl.d/99-wireguard-forward.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.${MAIN_IFACE}.accept_ra = 2
EOF
    run_command "sysctl -p /etc/sysctl.d/99-wireguard-forward.conf" "Aplicar sysctl"
    run_command "sysctl --system" "Recargar sysctl"
    stop_spinner $? "Forwarding dual-stack habilitado"

    start_spinner "Generando claves del servidor..."
    run_command "mkdir -p /etc/wireguard" "Crear directorio WireGuard"
    run_command "chmod 700 /etc/wireguard" "Ajustar permisos"
    umask 077
    SERVER_PRIV=$(wg genkey)
    stop_spinner $? "Clave generada con éxito"

    start_spinner "Creando configuración wg0.conf..."
    cat <<EOF >/etc/wireguard/wg0.conf
# ENDPOINT $WG_ENDPOINT
[Interface]
Address = $WG_IPV4_ADDR, $WG_IPV6_ADDR
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIV

PostUp = iptables -t nat -A POSTROUTING -o $MAIN_IFACE -j MASQUERADE; ip6tables -t nat -A POSTROUTING -o $MAIN_IFACE -j MASQUERADE; ip6tables -A FORWARD -i wg0 -j ACCEPT; ip6tables -A FORWARD -o wg0 -j ACCEPT;

PostDown = iptables -t nat -D POSTROUTING -o $MAIN_IFACE -j MASQUERADE; ip6tables -t nat -D POSTROUTING -o $MAIN_IFACE -j MASQUERADE; ip6tables -D FORWARD -i wg0 -j ACCEPT; ip6tables -D FORWARD -o wg0 -j ACCEPT;
EOF
    run_command "chmod 600 /etc/wireguard/wg0.conf" "Ajustar permisos wg0.conf"
    stop_spinner $? "Archivo wg0.conf configurado"

    start_spinner "Arrancando servicio WireGuard..."
    run_command "systemctl enable wg-quick@wg0" "Habilitar WireGuard"
    run_command "systemctl restart wg-quick@wg0" "Iniciar WireGuard"
    stop_spinner $? "WireGuard activo"
    
    debug_pause
fi

### ================= WIREGUARD UI =================
if check_module "INSTALL_WIREGUARD_UI" "WireGuard UI"; then
    print_section "INSTALACIÓN DE WIREGUARD UI"

    cd "$WG_PATH"

    start_spinner "Configurando scripts de WireGuard UI..."
    cat <<EOF >$WG_PATH/start-wgui.sh
#!/bin/bash
cd $WG_PATH
./wireguard-ui -bind-address $WG_HOST_IP:$WG_UI_PORT
EOF
    chmod +x start-wgui.sh

    cat <<EOF >/etc/systemd/system/wgui-web.service
[Unit]
Description=WireGuard UI
After=network.target

[Service]
Type=simple
ExecStart=$WG_PATH/start-wgui.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    cat <<'EOF' >$WG_PATH/update.sh
#!/bin/bash
VER=$(curl -sI https://github.com/ngoduykhanh/wireguard-ui/releases/latest | grep location | awk -F/ '{print $NF}' | tr -d '\r')
curl -sL "https://github.com/ngoduykhanh/wireguard-ui/releases/download/$VER/wireguard-ui-$VER-linux-amd64.tar.gz" -o wg-ui.tar.gz
tar xvf wg-ui.tar.gz
rm -f wg-ui.tar.gz
systemctl restart wgui-web.service
EOF
    chmod +x update.sh
    stop_spinner $? "Scripts configurados"

    start_spinner "Descargando WireGuard UI..."
    run_command "./update.sh" "Descargar WireGuard UI"
    stop_spinner $? "WireGuard UI descargado"

    start_spinner "Configurando systemd watcher..."
    cat <<EOF >/etc/systemd/system/wgui.service
[Unit]
Description=Restart WireGuard

[Service]
Type=oneshot
ExecStart=/bin/systemctl restart wg-quick@wg0.service
EOF

    cat <<EOF >/etc/systemd/system/wgui.path
[Unit]
Description=Watch WireGuard config

[Path]
PathModified=/etc/wireguard/wg0.conf

[Install]
WantedBy=multi-user.target
EOF

    run_command "touch /etc/wireguard/wg0.conf" "Touch wg0.conf"
    run_command "systemctl daemon-reload" "Recargar systemd"
    run_command "systemctl enable wgui.path wgui.service wgui-web.service wg-quick@wg0" "Habilitar servicios"
    run_command "systemctl start wgui.path wgui-web.service" "Iniciar servicios"
    stop_spinner $? "Systemd watcher configurado"

    start_spinner "Esperando inicialización de WireGuard UI..."
    for i in {1..30}; do
        if [ -f "$DB_PATH/users/admin.json" ]; then
            stop_spinner 0 "WireGuard UI inicializado"
            break
        fi
        sleep 1
    done

    if [ ! -f "$DB_PATH/users/admin.json" ]; then
        stop_spinner 1 "Timeout esperando WireGuard UI"
        log_error "WireGuard UI no inicializó correctamente"
    fi

    start_spinner "Configurando base de datos JSON..."
    if [ -f "$DB_PATH/users/admin.json" ]; then
        run_command "jq --arg pwd '$ADMIN_PASSWORD' '.password = \$pwd' '$DB_PATH/users/admin.json' > /tmp/admin.json && mv /tmp/admin.json '$DB_PATH/users/admin.json'" "Configurar admin password"
    fi

    if [ -f "$DB_PATH/server/global_settings.json" ]; then
        run_command "jq --arg endpoint '$WG_ENDPOINT' --arg dns4 '$DNS_IPV4' --arg dns6 '$DNS_IPV6' '.endpoint_address = \$endpoint | .dns_servers = [\$dns4,\$dns6]' '$DB_PATH/server/global_settings.json' > /tmp/global.json && mv /tmp/global.json '$DB_PATH/server/global_settings.json'" "Configurar global settings"
    fi

    if [ -f "$DB_PATH/server/interfaces.json" ]; then
        jq \
          --arg addr4 "$WG_IPV4_ADDR" \
          --arg addr6 "$WG_IPV6_ADDR" \
          --arg iface "$MAIN_IFACE" \
          --argjson port "$WG_PORT" \
          '
          .addresses = [$addr4, $addr6]
          | .listen_port = ($port|tostring)
          | .post_up = "iptables -t nat -A POSTROUTING -o \($iface) -j MASQUERADE; ip6tables -t nat -A POSTROUTING -o \($iface) -j MASQUERADE; ip6tables -A FORWARD -i wg0 -j ACCEPT; ip6tables -A FORWARD -o wg0 -j ACCEPT;"
          | .post_down = "iptables -t nat -D POSTROUTING -o \($iface) -j MASQUERADE; ip6tables -t nat -D POSTROUTING -o \($iface) -j MASQUERADE; ip6tables -D FORWARD -i wg0 -j ACCEPT; ip6tables -D FORWARD -o wg0 -j ACCEPT;"
          ' \
          "$DB_PATH/server/interfaces.json" > /tmp/interfaces.json \
          && mv /tmp/interfaces.json "$DB_PATH/server/interfaces.json"
    fi

    run_command "systemctl restart wgui-web.service" "Reiniciar WireGuard UI"
    run_command "systemctl restart wg-quick@wg0 || true" "Reiniciar WireGuard"
    stop_spinner $? "Configuración JSON aplicada"
    
    start_spinner "Instalando Caddy..."
    run_command "apt update && apt install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg" "Deps Caddy"

    run_command "curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg" "GPG Caddy"

    run_command "curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt | tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null" "Repo Caddy"

    run_command "chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg" "Permisos keyring"
    run_command "chmod o+r /etc/apt/sources.list.d/caddy-stable.list" "Permisos repo"

    run_command "apt update && apt install -y caddy" "Instalar Caddy"
    stop_spinner $? "Caddy instalado"

    start_spinner "Configurando Caddyfile..."
    cat <<EOF >/etc/caddy/Caddyfile
${WG_UI_DOMAIN}:${WG_UI_PROXY_PORT} {
    reverse_proxy ${WG_HOST_IP}:${WG_UI_PORT}
    encode gzip
    tls internal
}
EOF
    stop_spinner $? "Caddyfile creado"

    start_spinner "Iniciando Caddy..."
    run_command "systemctl enable caddy" "Enable Caddy"
    run_command "systemctl restart caddy" "Restart Caddy"
    stop_spinner $? "Caddy activo"
    
    debug_pause
fi

### ================= USUARIO DE DESARROLLO =================
print_section "USUARIO DE DESARROLLO"

start_spinner "Creando usuario '$DEV_USER'..."
if ! id "$DEV_USER" &>/dev/null; then
    run_command "useradd -m -s /usr/bin/zsh -G sudo,docker '$DEV_USER'" "Crear usuario"
    run_command "echo '$DEV_USER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$DEV_USER" "Configurar sudo"
fi
stop_spinner $? "Usuario '$DEV_USER' creado"

debug_pause

### ================= JAVA =================
if check_module "INSTALL_JAVA" "Java"; then
    print_section "INSTALACIÓN DE JAVA (OPENJDK)"

    start_spinner "Instalando OpenJDK 17 y 21..."
    run_command "apt-get install -y openjdk-17-jdk openjdk-21-jdk" "Instalar OpenJDK"
    stop_spinner $? "OpenJDK instalado"

    start_spinner "Configurando Java 17 como predeterminado..."
    run_command "update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java" "Configurar java"
    run_command "update-alternatives --set javac /usr/lib/jvm/java-17-openjdk-amd64/bin/javac" "Configurar javac"
    stop_spinner $? "Java 17 configurado como default"
    
    debug_pause
fi

### ================= GO =================
if check_module "INSTALL_GO" "Go"; then
    print_section "INSTALACIÓN DE GO"

    start_spinner "Instalando Go..."
    run_command "apt-get install -y golang-go" "Instalar Go"
    stop_spinner $? "Go instalado"

    start_spinner "Configurando entorno Go para usuario dev..."
    run_command "touch /home/$DEV_USER/.zshrc" "Crear .zshrc si no existe"
    run_command "chown $DEV_USER:$DEV_USER /home/$DEV_USER/.zshrc" "Ajustar permisos .zshrc"
    cat <<EOF >> /home/$DEV_USER/.zshrc

# Go
export GOPATH=\$HOME/go
export PATH=\$PATH:/usr/lib/go/bin:\$GOPATH/bin
EOF

    run_command "mkdir -p /home/$DEV_USER/go/{bin,src,pkg}" "Crear directorios Go"
    run_command "chown -R $DEV_USER:$DEV_USER /home/$DEV_USER/go" "Ajustar permisos Go"
    stop_spinner $? "Entorno Go configurado"
    
    debug_pause
fi

### ================= PHP =================
if check_module "INSTALL_PHP" "PHP"; then
    print_section "INSTALACIÓN DE PHP"

    start_spinner "Agregando repositorio de PHP..."
    run_command "add-apt-repository ppa:ondrej/php -y" "Agregar PPA PHP"
    run_command "apt-get update" "Actualizar repositorios"
    stop_spinner $? "Repositorio agregado"

    start_spinner "Instalando PHP y extensiones comunes..."
    run_command "apt-get install -y php7.4 php7.4-cli php7.4-fpm php7.4-mysql php7.4-curl php7.4-mbstring php7.4-xml php7.4-zip php7.4-intl php7.4-bcmath php7.4-gd php7.4-opcache php7.4-redis php8.1 php8.1-cli php8.1-fpm php8.1-mysql php8.1-curl php8.1-mbstring php8.1-xml php8.1-zip php8.1-intl php8.1-bcmath php8.1-gd php8.1-opcache php8.1-redis php8.2 php8.2-cli php8.2-fpm php8.2-mysql php8.2-curl php8.2-mbstring php8.2-xml php8.2-zip php8.2-intl php8.2-bcmath php8.2-gd php8.2-opcache php8.2-redis php8.3 php8.3-cli php8.3-fpm php8.3-mysql php8.3-curl php8.3-mbstring php8.3-xml php8.3-zip php8.3-intl php8.3-bcmath php8.3-gd php8.3-opcache php8.3-redis" "Instalar PHP y extensiones"
    run_command "update-alternatives --set php /usr/bin/php8.2" "Configurar PHP 8.2 como default"
    stop_spinner $? "PHP instalado con extensiones comunes (default: 8.2)"

    start_spinner "Instalando Composer..."
    if run_command "curl -sS https://getcomposer.org/installer | php" "Descargar Composer"; then
        if [ -f composer.phar ]; then
            run_command "mv composer.phar /usr/local/bin/composer" "Mover Composer"
            run_command "chmod +x /usr/local/bin/composer" "Hacer ejecutable Composer"
            stop_spinner 0 "Composer instalado"
        else
            stop_spinner 1 "Error: composer.phar no encontrado"
        fi
    else
        stop_spinner 1 "Error descargando Composer"
    fi
    
    debug_pause
fi

### ================= REDIS =================
if check_module "INSTALL_REDIS" "Redis"; then
    print_section "INSTALACIÓN DE REDIS"

    start_spinner "Instalando Redis Server..."
    run_command "apt-get install -y redis-server" "Instalar Redis"
    stop_spinner $? "Redis instalado"

    start_spinner "Configurando Redis para uso local..."
    run_command "sed -i 's/^supervised .*/supervised systemd/' /etc/redis/redis.conf" "Configurar supervised"
    run_command "sed -i 's/^bind .*/bind 127.0.0.1 ::1/' /etc/redis/redis.conf" "Configurar bind"
    run_command "systemctl enable redis-server" "Habilitar Redis"
    run_command "systemctl restart redis-server" "Reiniciar Redis"
    stop_spinner $? "Redis configurado y activo"
    
    debug_pause
fi

### ================= NODE.JS =================
if check_module "INSTALL_NODEJS" "Node.js"; then
    print_section "INSTALACIÓN DE NODE.JS"

    start_spinner "Instalando NVM y Node.js LTS..."
    su - $DEV_USER -c '
      set -e  # Salir en cualquier error
      curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
      export NVM_DIR="$HOME/.nvm"
      source "$NVM_DIR/nvm.sh"
      nvm install --lts
      npm install -g pnpm yarn
    ' >> "$LOG_FILE" 2>&1
    exit_code=$?
    stop_spinner $exit_code "Node.js LTS y gestores de paquetes instalados"
    
    debug_pause
fi

### ================= PYTHON =================
if check_module "INSTALL_PYTHON" "Python Tools"; then
    print_section "PYTHON - HERRAMIENTAS ADICIONALES"
    
    start_spinner "Instalando herramientas Python..."
    run_command "apt-get install -y python3-pip python3-venv --quiet" "Instalar pip y venv"
    run_command "su - $DEV_USER -c 'python3 -m pip install --user --upgrade pip virtualenv poetry openai --quiet'" "Instalar herramientas Python"
    stop_spinner $? "Herramientas Python instaladas"
    
    debug_pause
fi

### ================= CODE-SERVER =================
if check_module "INSTALL_CODE_SERVER" "Code-server"; then
    print_section "INSTALACIÓN DE CODE-SERVER"

    start_spinner "Descargando e instalando code-server..."
    run_command "curl -fsSL https://code-server.dev/install.sh | sh" "Instalar code-server"
    run_command "systemctl enable code-server@$DEV_USER" "Habilitar code-server"
    stop_spinner $? "Code-server instalado"

    start_spinner "Configurando code-server..."
    run_command "mkdir -p /home/$DEV_USER/.config/code-server" "Crear directorio config"
    cat <<EOF >/home/$DEV_USER/.config/code-server/config.yaml
bind-addr: $WG_HOST_IP:$CODE_PORT
auth: password
password: $CODE_PASSWORD
cert: false
EOF
    run_command "chown -R $DEV_USER:$DEV_USER /home/$DEV_USER/.config" "Ajustar permisos"
    run_command "systemctl start code-server@$DEV_USER" "Iniciar code-server"
    stop_spinner $? "Code-server configurado"
    
    debug_pause
fi

### ================= OPENCODE AI =================
if check_module "INSTALL_OPENCODE_AI" "OpenCode AI"; then
    print_section "INSTALACIÓN DE OPENCODE AI"

    start_spinner "Instalando OpenCode AI (CLI)..."
    su - $DEV_USER -c '
      export NVM_DIR="$HOME/.nvm"
      source "$NVM_DIR/nvm.sh"
      npm install -g opencode-ai
    ' >> "$LOG_FILE" 2>&1
    stop_spinner $? "OpenCode AI instalado"
    
    debug_pause
fi

### ================= PHPMYADMIN =================
if check_module "INSTALL_PHPMYADMIN" "phpMyAdmin"; then
    print_section "CONFIGURACIÓN DE PHPMYADMIN (DOCKER + MYSQL)"

    start_spinner "Configurando MySQL para aceptar conexiones de red..."
    run_command "sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf" "Configurar bind-address"
    if ! grep -q "^bind-address" /etc/mysql/mysql.conf.d/mysqld.cnf; then
        run_command "echo 'bind-address = 0.0.0.0' >> /etc/mysql/mysql.conf.d/mysqld.cnf" "Agregar bind-address"
    fi
    run_command "systemctl restart mysql" "Reiniciar MySQL"
    sleep 3
    stop_spinner $? "MySQL configurado para red"

    # Crear usuario MySQL
    IFS=',' read -ra NETS <<< "$MYSQL_ALLOWED_NET"
    for net in "${NETS[@]}"; do
        net=$(echo "$net" | xargs)
        start_spinner "Creando usuario MySQL '${MYSQL_DEV_USER}'@'${net}'..."
        run_command "mysql --protocol=socket <<EOF
DROP USER IF EXISTS '${MYSQL_DEV_USER}'@'${net}';
CREATE USER '${MYSQL_DEV_USER}'@'${net}' IDENTIFIED BY '${MYSQL_DEV_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_DEV_USER}'@'${net}' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
" "Usuario MySQL para '${net}'"
        stop_spinner $? "Usuario MySQL para '${net}' configurado"
    done

    start_spinner "Creando usuario MySQL para red Docker..."
    run_command "mysql --protocol=socket <<EOF
DROP USER IF EXISTS '${MYSQL_DEV_USER}'@'172.17.0.%';
CREATE USER '${MYSQL_DEV_USER}'@'172.17.0.%' IDENTIFIED BY '${MYSQL_DEV_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_DEV_USER}'@'172.17.0.%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
" "Usuario MySQL para Docker"
    stop_spinner $? "Usuario MySQL Docker configurado"

    # Detectar IP del host
    HOST_IP=$(ip -4 addr show docker0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    if [ -z "$HOST_IP" ]; then
        HOST_IP=$(ip -4 addr show "$MAIN_IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    fi
    log_message "INFO" "IP del host para Docker: $HOST_IP"

    # Levantar phpMyAdmin
    start_spinner "Instalando phpMyAdmin (Docker)..."
    run_command "docker rm -f phpmyadmin 2>/dev/null || true" "Limpiar contenedor anterior"
    run_command "
    docker run -d \
      --name phpmyadmin \
      --restart always \
      -e PMA_HOST=${HOST_IP} \
      -e PMA_PORT=3306 \
      -e PMA_ARBITRARY=0 \
      -e HIDE_PHP_VERSION=true \
      -e UPLOAD_LIMIT=64M \
      -p ${WG_HOST_IP}:${PHPMYADMIN_PORT}:80 \
      phpmyadmin/phpmyadmin:latest
    " "Crear contenedor phpMyAdmin"
    stop_spinner $? "phpMyAdmin instalado y corriendo"
    
    debug_pause
fi

### ================= ZSH =================
if check_module "INSTALL_ZSH" "ZSH"; then
    print_section "CONFIGURACIÓN DE ZSH"

    start_spinner "Instalando Oh My Zsh..."
    su - $DEV_USER -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' >> "$LOG_FILE" 2>&1
    stop_spinner $? "Oh My Zsh instalado"

    start_spinner "Instalando herramientas de terminal..."
    run_command "apt-get install -y fzf ripgrep bat" "Instalar herramientas"
    run_command "chown -R $DEV_USER:$DEV_USER /home/$DEV_USER" "Ajustar permisos usuario"
    stop_spinner $? "Herramientas de terminal instaladas"
    
    debug_pause
fi

### ================= FIREWALL =================
if check_module "INSTALL_FIREWALL" "Firewall"; then
    print_section "CONFIGURACIÓN DE FIREWALL"

    start_spinner "Configurando reglas UFW..."
    run_command "ufw --force reset" "Reset UFW"
    run_command "ufw default deny incoming" "Denegar entrante"
    run_command "ufw default allow outgoing" "Permitir saliente"
    run_command "ufw allow OpenSSH" "Permitir SSH"
    run_command "ufw allow ${WG_PORT}/udp" "Permitir WireGuard"
    run_command "ufw allow ${WG_UI_PROXY_PORT}/tcp" "Permitir WireGuard UI Proxy"
    run_command "ufw allow in on wg0" "Permitir tráfico VPN"
    run_command "ufw route allow in on wg0 out on $MAIN_IFACE" "Permitir tráfico foward VPN"
    run_command "ufw route allow in on $MAIN_IFACE out on wg0" "Permitir enrutamiento de tráfico VPN"
    run_command "ufw --force enable" "Habilitar UFW"
    stop_spinner $? "Firewall configurado"
    
    debug_pause
fi

### ================= RESUMEN FINAL =================
clear
echo -e "${BOLD}${GREEN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              ✓  INSTALACIÓN COMPLETADA                       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${WHITE}  ACCESO A SERVICIOS${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${YELLOW}Acceso PÚBLICO (antes de conectar VPN):${NC}"
echo -e "  ${GREEN}•${NC} WireGuard UI → ${CYAN}http://$WG_UI_DOMAIN:$WG_UI_PROXY_PORT${NC}"
echo ""
echo -e "  ${YELLOW}Acceso por VPN (después de conectar):${NC}"
echo -e "  ${GREEN}•${NC} WireGuard UI → ${CYAN}http://$WG_HOST_IP:$WG_UI_PORT${NC}"
echo -e "  ${GREEN}•${NC} VS Code      → ${CYAN}http://$WG_HOST_IP:$CODE_PORT${NC}"
echo -e "  ${GREEN}•${NC} phpMyAdmin   → ${CYAN}http://$WG_HOST_IP:$PHPMYADMIN_PORT${NC}"
echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${WHITE}  CREDENCIALES${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${YELLOW}WireGuard Admin:${NC}"
echo -e "    Usuario: ${WHITE}admin${NC}"
echo -e "    Password: ${WHITE}$ADMIN_PASSWORD${NC}"
echo ""
echo -e "  ${YELLOW}Code-server:${NC}"
echo -e "    Password: ${WHITE}$CODE_PASSWORD${NC}"
echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${WHITE}  LOGS  ${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}•${NC} Log principal: ${CYAN}$LOG_FILE${NC}"
echo -e "  ${GREEN}•${NC} Log de errores: ${CYAN}$ERROR_LOG${NC}"
echo ""
echo -e "  Para ver los logs:"
echo -e "    ${YELLOW}tail -f $LOG_FILE${NC}"
echo -e "    ${YELLOW}tail -f $ERROR_LOG${NC}"
echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${RED}  ⚠️  IMPORTANTE - SEGURIDAD${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${RED}1.${NC} Cambia TODAS las contraseñas predeterminadas"
echo -e "  ${RED}2.${NC} El usuario MySQL '${MYSQL_DEV_USER}' tiene privilegios de superusuario"
echo -e "  ${RED}3.${NC} Code-server password está en texto plano: /home/$DEV_USER/.config/code-server/config.yaml"
echo -e "  ${RED}4.${NC} Revisa los logs en caso de errores"
echo -e "  ${RED}5.${NC} Este servidor está configurado para DESARROLLO, NO para producción"
echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${WHITE}  PRÓXIMOS PASOS${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}1.${NC} Conéctate a WireGuard UI: ${CYAN}http://$WG_UI_DOMAIN:$WG_UI_PROXY_PORT${NC}"
echo -e "  ${GREEN}2.${NC} Crea un cliente VPN y descarga la configuración"
echo -e "  ${GREEN}3.${NC} Conecta tu dispositivo a la VPN"
echo -e "  ${GREEN}4.${NC} Accede a los servicios internos (VS Code, phpMyAdmin)"
echo ""

log_message "INFO" "Instalación completada exitosamente"
