#!/bin/bash

set -Eeuo pipefail
set -x

# ============================================================
# ARCH LINUX + i3
# INSTALADOR SEGURO / IDEMPOTENTE
# ============================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
I3_DIR="$HOME/.config/i3"
PICOM_DIR="$HOME/.config/picom"
BUMBLEBEE_DIR="$HOME/.config/bumblebee-status"
FONT_DIR="$HOME/.local/share/fonts"

echo "============================================================"
echo "🚀 INSTALADOR i3"
echo "============================================================"
echo "📂 Directorio del script: $SCRIPT_DIR"
echo ""

# ============================================================
# FUNCIONES
# ============================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

package_installed() {
    pacman -Q "$1" >/dev/null 2>&1
}

aur_package_installed() {
    pacman -Q "$1" >/dev/null 2>&1
}

install_pacman_if_missing() {
    local packages=()
    local package

    for package in "$@"; do
        if package_installed "$package"; then
            echo "✅ Ya instalado: $package"
        else
            packages+=("$package")
        fi
    done

    if [ "${#packages[@]}" -gt 0 ]; then
        echo "📦 Instalando: ${packages[*]}"
        sudo pacman -S --needed --noconfirm "${packages[@]}"
    else
        echo "✅ Todos los paquetes ya están instalados."
    fi
}

install_aur_if_missing() {
    local packages=()
    local package

    for package in "$@"; do
        if aur_package_installed "$package"; then
            echo "✅ Ya instalado: $package"
        else
            packages+=("$package")
        fi
    done

    if [ "${#packages[@]}" -gt 0 ]; then
        echo "📦 Instalando desde AUR: ${packages[*]}"
        yay -S --needed --noconfirm "${packages[@]}"
    else
        echo "✅ Todos los paquetes AUR ya están instalados."
    fi
}

backup_file() {
    local file="$1"

    if [ -f "$file" ]; then
        local backup="${file}.backup-$(date +%Y%m%d-%H%M%S)"
        echo "💾 Copia de seguridad: $backup"
        cp -a "$file" "$backup"
    fi
}

# ============================================================
# 1. COMPROBAR SUDO
# ============================================================

echo "🔐 Comprobando sudo..."

if ! command_exists sudo; then
    echo "❌ sudo no está instalado."
    echo "Instálalo primero con:"
    echo "sudo pacman -S sudo"
    exit 1
fi

sudo -v

# Mantener sudo activo durante la instalación
(
    while true; do
        sudo -n true
        sleep 50
        kill -0 "$$" 2>/dev/null || exit
    done
) 2>/dev/null &

SUDO_KEEPALIVE_PID=$!

cleanup() {
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}

trap cleanup EXIT

# ============================================================
# 2. ACTUALIZAR SISTEMA
# ============================================================

echo ""
echo "🔄 Actualizando repositorios y sistema..."

sudo pacman -Syu --noconfirm

# ============================================================
# 3. PAQUETES OFICIALES
# ============================================================

echo ""
echo "📦 Comprobando paquetes..."

install_pacman_if_missing \
    git \
    curl \
    wget \
    unzip \
    zip \
    base-devel \
    i3-wm \
    i3status \
    i3lock \
    picom \
    feh \
    rofi \
    alacritty \
    cbatticon \
    network-manager-applet \
    blueman \
    pavucontrol \
    brightnessctl \
    scrot \
    thunar \
    gvfs \
    gvfs-mtp \
    gvfs-gphoto2 \
    udiskie \
    code \
    xdg-user-dirs \
    python-psutil \
    firefox \
    lightdm \
    lightdm-gtk-greeter \
    linux-headers \
    linux-firmware \
    bluez \
    bluez-utils \
    fontconfig

# ============================================================
# 4. NETWORKMANAGER
# ============================================================

echo ""
echo "🌐 Configurando NetworkManager..."

if systemctl list-unit-files \
    | grep -q '^NetworkManager.service'
then
    sudo systemctl enable NetworkManager.service
    sudo systemctl start NetworkManager.service || true
else
    echo "⚠️ NetworkManager.service no encontrado."
fi

# ============================================================
# 5. BLUETOOTH
# ============================================================

echo ""
echo "🔵 Configurando Bluetooth..."

if systemctl list-unit-files \
    | grep -q '^bluetooth.service'
then
    sudo systemctl enable bluetooth.service
    sudo systemctl start bluetooth.service || true
fi

# ============================================================
# 6. YAY
# ============================================================

echo ""
echo "📦 Comprobando yay..."

if command_exists yay; then

    echo "✅ yay ya está instalado."

else

    echo "📦 yay no está instalado."

    YAY_TMP="$(mktemp -d)"

    cleanup_yay() {
        rm -rf "$YAY_TMP"
    }

    trap 'cleanup_yay; cleanup' EXIT

    git clone \
        https://aur.archlinux.org/yay.git \
        "$YAY_TMP/yay"

    cd "$YAY_TMP/yay"

    makepkg -si --noconfirm

    cd "$SCRIPT_DIR"

    rm -rf "$YAY_TMP"

    echo "✅ yay instalado."
fi

# ============================================================
# 7. BROADCOM WI-FI
# ============================================================

echo ""
echo "📡 Comprobando Broadcom Wi-Fi..."

if package_installed broadcom-wl-dkms; then
    echo "✅ broadcom-wl-dkms ya está instalado."
else
    echo "📡 Instalando broadcom-wl-dkms..."
    yay -S --needed --noconfirm broadcom-wl-dkms
fi

# ============================================================
# 8. BROADCOM BLUETOOTH
# ============================================================

echo ""
echo "🔵 Comprobando firmware Bluetooth Broadcom..."

if package_installed broadcom-bt-firmware; then
    echo "✅ broadcom-bt-firmware ya está instalado."
else
    echo "📦 Instalando broadcom-bt-firmware..."
    yay -S --needed --noconfirm broadcom-bt-firmware
fi

# ============================================================
# 9. DISCORD
# ============================================================

echo ""
echo "💬 Comprobando Discord..."

if package_installed discord; then
    echo "✅ Discord ya está instalado."
else
    yay -S --needed --noconfirm discord
fi

# ============================================================
# 10. LIGHTDM
# ============================================================

echo ""
echo "🔐 Configurando LightDM..."

# Desactivar gestores alternativos solamente si existen
if systemctl list-unit-files | grep -q '^ly.service'; then
    sudo systemctl disable ly.service 2>/dev/null || true
fi

if systemctl list-unit-files | grep -q '^lydm.service'; then
    sudo systemctl disable lydm.service 2>/dev/null || true
fi

# Configuración de LightDM
sudo mkdir -p /etc/lightdm

if [ -f /etc/lightdm/lightdm.conf ]; then

    echo "ℹ️ /etc/lightdm/lightdm.conf ya existe."

    if ! grep -q '^\[Seat:\*\]' /etc/lightdm/lightdm.conf; then

        backup_file "/etc/lightdm/lightdm.conf"

        sudo tee -a /etc/lightdm/lightdm.conf >/dev/null <<'EOF'

[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=i3
EOF

    else
        echo "✅ Configuración [Seat:*] ya existe."
    fi

else

    echo "📝 Creando configuración LightDM..."

    sudo tee /etc/lightdm/lightdm.conf >/dev/null <<'EOF'
[LightDM]

[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=i3
EOF

fi

sudo systemctl enable lightdm.service

echo "✅ LightDM preparado."

# ============================================================
# 11. OH-MY-BASH USUARIO
# ============================================================

echo ""
echo "🐚 Comprobando oh-my-bash..."

if [ -d "$HOME/.oh-my-bash" ]; then

    echo "✅ oh-my-bash ya está instalado."

else

    echo "📦 Instalando oh-my-bash..."

    curl -fsSL \
        https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh \
        | bash -s -- --unattended

fi

# Configurar tema sin duplicar
if [ -f "$HOME/.bashrc" ]; then

    if grep -q '^OSH_THEME=' "$HOME/.bashrc"; then

        sed -i \
            's/^OSH_THEME=.*/OSH_THEME="agnoster"/' \
            "$HOME/.bashrc"

    else

        echo 'OSH_THEME="agnoster"' >> "$HOME/.bashrc"

    fi
fi

# ============================================================
# 12. OH-MY-BASH ROOT
# ============================================================

echo ""
echo "🐚 Comprobando oh-my-bash para root..."

if sudo test -d /root/.oh-my-bash; then

    echo "✅ oh-my-bash root ya está instalado."

else

    sudo bash -c \
        'curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash -s -- --unattended'

fi

if sudo test -f /root/.bashrc; then

    if sudo grep -q '^OSH_THEME=' /root/.bashrc; then

        sudo sed -i \
            's/^OSH_THEME=.*/OSH_THEME="agnoster"/' \
            /root/.bashrc

    else

        echo 'OSH_THEME="agnoster"' \
            | sudo tee -a /root/.bashrc >/dev/null

    fi
fi

# ============================================================
# 13. FIRA CODE NERD FONT
# ============================================================

echo ""
echo "🔠 Comprobando FiraCode Nerd Font..."

mkdir -p "$FONT_DIR"

if find "$FONT_DIR" \
    -type f \
    \( -iname 'FiraCodeNerdFont*.ttf' \
    -o -iname 'FiraCode*.ttf' \) \
    | grep -q .
then

    echo "✅ FiraCode ya está instalada."

else

    echo "📥 Descargando FiraCode Nerd Font..."

    FONT_TMP="$(mktemp -d)"

    wget -q \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip \
        -O "$FONT_TMP/FiraCode.zip"

    unzip -qo \
        "$FONT_TMP/FiraCode.zip" \
        -d "$FONT_DIR"

    rm -rf "$FONT_TMP"

    echo "✅ FiraCode instalada."
fi

fc-cache -f >/dev/null 2>&1 || true

# ============================================================
# 14. CREAR ~/.config/i3
# ============================================================

echo ""
echo "🧩 Preparando i3..."

mkdir -p "$I3_DIR"

# ============================================================
# 15. COPIAR CONFIG DESDE EL DIRECTORIO DEL SCRIPT
# ============================================================

SOURCE_CONFIG="$SCRIPT_DIR/config"
TARGET_CONFIG="$I3_DIR/config"

if [ -f "$SOURCE_CONFIG" ]; then

    echo "📄 Encontrado config:"
    echo "   $SOURCE_CONFIG"

    # No hacer backup si el archivo es exactamente igual
    if [ -f "$TARGET_CONFIG" ] \
        && cmp -s "$SOURCE_CONFIG" "$TARGET_CONFIG"
    then

        echo "✅ La configuración de i3 ya es idéntica."

    else

        if [ -f "$TARGET_CONFIG" ]; then
            backup_file "$TARGET_CONFIG"
        fi

        cp -f \
            "$SOURCE_CONFIG" \
            "$TARGET_CONFIG"

        echo "✅ config copiado."

    fi

else

    echo "⚠️ No se encontró:"
    echo "   $SOURCE_CONFIG"

    if [ -f "$TARGET_CONFIG" ]; then
        echo "✅ Se conserva el config existente."

    else
        echo "⚠️ No existe configuración de i3."
    fi
fi

# ============================================================
# 16. WALLPAPER
# ============================================================

SOURCE_WALLPAPER="$SCRIPT_DIR/wallpaper.jpg"
TARGET_WALLPAPER="$I3_DIR/wallpaper.jpg"

if [ -f "$SOURCE_WALLPAPER" ]; then

    echo "🖼️ Encontrado wallpaper:"
    echo "   $SOURCE_WALLPAPER"

    if [ -f "$TARGET_WALLPAPER" ] \
        && cmp -s "$SOURCE_WALLPAPER" "$TARGET_WALLPAPER"
    then

        echo "✅ El wallpaper ya está actualizado."

    else

        if [ -f "$TARGET_WALLPAPER" ]; then
            backup_file "$TARGET_WALLPAPER"
        fi

        cp -f \
            "$SOURCE_WALLPAPER" \
            "$TARGET_WALLPAPER"

        echo "✅ wallpaper.jpg copiado."
    fi

else

    echo "⚠️ No se encontró:"
    echo "   $SOURCE_WALLPAPER"

    if [ -f "$TARGET_WALLPAPER" ]; then
        echo "✅ Se conserva el wallpaper existente."
    fi
fi

# ============================================================
# 17. CARPETAS DE USUARIO
# ============================================================

echo ""
echo "📁 Configurando carpetas de usuario..."

xdg-user-dirs-update || true

mkdir -p \
    "$HOME/Documentos" \
    "$HOME/Descargas" \
    "$HOME/Música" \
    "$HOME/Videos" \
    "$HOME/Imágenes" \
    "$HOME/Escritorio"

# ============================================================
# 18. BUMBLEBEE-STATUS
# ============================================================

echo ""
echo "🐝 Comprobando bumblebee-status..."

if [ -d "$BUMBLEBEE_DIR/.git" ]; then

    echo "✅ bumblebee-status ya está instalado."

else

    if [ -e "$BUMBLEBEE_DIR" ]; then
        echo "⚠️ Existe $BUMBLEBEE_DIR pero no es un repositorio Git."
        echo "✅ No se sobrescribirá."
    else

        git clone \
            https://github.com/tobi-wan-kenobi/bumblebee-status.git \
            "$BUMBLEBEE_DIR"

    fi
fi

if [ -f "$BUMBLEBEE_DIR/bumblebee-status" ]; then

    chmod +x "$BUMBLEBEE_DIR/bumblebee-status"

    sudo ln -sf \
        "$BUMBLEBEE_DIR/bumblebee-status" \
        /usr/local/bin/bumblebee-status

    echo "✅ bumblebee-status preparado."

else

    echo "⚠️ No se encontró el ejecutable de bumblebee-status."
fi

# ============================================================
# 19. PICOM
# ============================================================

echo ""
echo "✨ Configurando Picom..."

mkdir -p "$PICOM_DIR"

PICOM_CONFIG="$PICOM_DIR/picom.conf"

if [ -f "$PICOM_CONFIG" ]; then

    echo "✅ picom.conf ya existe."
    echo "ℹ️ No se sobrescribe tu configuración."

else

    cat > "$PICOM_CONFIG" <<'EOF'
backend = "glx";

vsync = true;

shadow = true;
shadow-radius = 12;
shadow-offset-x = -10;
shadow-offset-y = -10;
shadow-opacity = 0.45;

fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
fade-delta = 10;

inactive-opacity = 1.0;
active-opacity = 1.0;
frame-opacity = 1.0;

blur-method = "dual_kawase";
blur-strength = 5;

corner-radius = 8;

rounded-corners-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'"
];

wintypes:
{
    tooltip = {
        fade = true;
        shadow = true;
        opacity = 0.95;
    };

    dock = {
        shadow = false;
    };

    dnd = {
        shadow = false;
    };

    popup_menu = {
        opacity = 0.95;
    };

    dropdown_menu = {
        opacity = 0.95;
    };
};
EOF

    echo "✅ picom.conf creado."

fi

# ============================================================
# 20. SCRIPT DE ARRANQUE DE PICOM
# ============================================================

PICOM_START="$I3_DIR/picom-autostart.sh"

if [ -f "$PICOM_START" ]; then

    echo "✅ Script de Picom ya existe."

else

    cat > "$PICOM_START" <<'EOF'
#!/bin/bash

if ! pgrep -x picom >/dev/null 2>&1; then
    picom \
        --config "$HOME/.config/picom/picom.conf" \
        --daemon
fi
EOF

    chmod +x "$PICOM_START"

    echo "✅ Autostart de Picom creado."
fi

# ============================================================
# 21. WALLPAPER SCRIPT
# ============================================================

WALLPAPER_SCRIPT="$I3_DIR/set-wallpaper.sh"

if [ -f "$TARGET_WALLPAPER" ]; then

    if [ -f "$WALLPAPER_SCRIPT" ]; then

        echo "✅ Script de wallpaper ya existe."

    else

        cat > "$WALLPAPER_SCRIPT" <<'EOF'
#!/bin/bash

if command -v feh >/dev/null 2>&1 \
    && [ -f "$HOME/.config/i3/wallpaper.jpg" ]
then
    feh \
        --no-fehbg \
        --bg-fill \
        "$HOME/.config/i3/wallpaper.jpg"
fi
EOF

        chmod +x "$WALLPAPER_SCRIPT"

        echo "✅ Script de wallpaper creado."
    fi
fi

# ============================================================
# 22. AÑADIR PICOM AL CONFIG DE i3
# ============================================================

if [ -f "$TARGET_CONFIG" ]; then

    if grep -Fq \
        "picom-autostart.sh" \
        "$TARGET_CONFIG"
    then

        echo "✅ Picom ya está en el autostart de i3."

    else

        cat >> "$TARGET_CONFIG" <<'EOF'

# ============================================================
# PICOM
# ============================================================

exec_always --no-startup-id ~/.config/i3/picom-autostart.sh
EOF

        echo "✅ Picom añadido al inicio de i3."
    fi
fi

# ============================================================
# 23. AÑADIR WALLPAPER AL CONFIG
# ============================================================

if [ -f "$TARGET_WALLPAPER" ] \
    && [ -f "$TARGET_CONFIG" ]
then

    if grep -Fq \
        "set-wallpaper.sh" \
        "$TARGET_CONFIG"
    then

        echo "✅ Wallpaper ya está en el autostart."

    else

        cat >> "$TARGET_CONFIG" <<'EOF'

# ============================================================
# WALLPAPER
# ============================================================

exec_always --no-startup-id ~/.config/i3/set-wallpaper.sh
EOF

        echo "✅ Wallpaper añadido al inicio de i3."
    fi
fi

# ============================================================
# 24. VALIDAR CONFIGURACIÓN DE PICOM
# ============================================================

echo ""
echo "🔍 Comprobando Picom..."

if command_exists picom; then

    if picom \
        --config "$PICOM_CONFIG" \
        --config-file "$PICOM_CONFIG" \
        --diagnostics >/dev/null 2>&1
    then
        echo "✅ Configuración de Picom válida."
    else
        echo "ℹ️ No se pudo ejecutar el diagnóstico de Picom."
        echo "ℹ️ No se modificará una configuración existente."
    fi

fi

# ============================================================
# 25. ACTUALIZAR INITRAMFS
# ============================================================

echo ""
echo "🔧 Actualizando initramfs..."

sudo mkinitcpio -P

# ============================================================
# 26. COMPROBACIONES FINALES
# ============================================================

echo ""
echo "============================================================"
echo "🔍 COMPROBACIÓN FINAL"
echo "============================================================"

check_command() {
    if command_exists "$1"; then
        echo "✅ $1"
    else
        echo "⚠️ Falta: $1"
    fi
}

check_command i3
check_command picom
check_command feh
check_command rofi
check_command alacritty
check_command firefox
check_command yay
check_command bumblebee-status

echo ""

if package_installed lightdm; then
    echo "✅ LightDM instalado"
else
    echo "⚠️ LightDM no está instalado"
fi

if systemctl is-enabled lightdm.service >/dev/null 2>&1; then
    echo "✅ LightDM habilitado"
else
    echo "⚠️ LightDM no está habilitado"
fi

if [ -f "$I3_DIR/config" ]; then
    echo "✅ $I3_DIR/config"
else
    echo "⚠️ No existe $I3_DIR/config"
fi

if [ -f "$I3_DIR/wallpaper.jpg" ]; then
    echo "✅ $I3_DIR/wallpaper.jpg"
else
    echo "⚠️ No existe $I3_DIR/wallpaper.jpg"
fi

if [ -f "$PICOM_CONFIG" ]; then
    echo "✅ $PICOM_CONFIG"
fi

# ============================================================
# 27. FINAL
# ============================================================

cd "$SCRIPT_DIR"

echo ""
echo "============================================================"
echo "✅ INSTALACIÓN TERMINADA"
echo "============================================================"
echo ""
echo "📂 Archivos utilizados desde:"
echo "   $SCRIPT_DIR"
echo ""
echo "🧩 i3:"
echo "   $I3_DIR/config"
echo ""
echo "🖼️ Wallpaper:"
echo "   $I3_DIR/wallpaper.jpg"
echo ""
echo "✨ Picom:"
echo "   $PICOM_CONFIG"
echo ""
echo "🔐 Login manager:"
echo "   LightDM + lightdm-gtk-greeter"
echo ""
echo "🐝 Status:"
echo "   $BUMBLEBEE_DIR"
echo ""
echo "============================================================"
echo "🔄 Para terminar, reinicia:"
echo ""
echo "   sudo reboot"
echo ""
echo "============================================================"
