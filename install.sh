#!/usr/bin/env bash

set -Eeuo pipefail
set -x

# ============================================================
# ACER ASPIRE E5-571
# ARCH LINUX + i3
#
# Intel Core i3-4005U
# Intel Haswell-ULT
# ~6 GiB RAM
#
# Instalador robusto / idempotente
# - Detecta kernel(s)
# - Detecta Broadcom
# - DKMS + headers correctos
# - LightDM + autologin
# - sudo NOPASSWD
# - i3
# - Intel/Mesa
# - zram
# - Bluetooth
# - NetworkManager
# - Picom ligero
# - HDMI 1920x1080@120 seguro
# ============================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

I3_DIR="$HOME/.config/i3"
PICOM_DIR="$HOME/.config/picom"
BUMBLEBEE_DIR="$HOME/.config/bumblebee-status"
FONT_DIR="$HOME/.local/share/fonts"

USER_NAME="$(id -un)"
HOME_DIR="$HOME"

echo
echo "============================================================"
echo "🚀 ACER ASPIRE E5-571 - ARCH + i3"
echo "============================================================"
echo "👤 Usuario:        $USER_NAME"
echo "📂 Script:         $SCRIPT_DIR"
echo "🧠 Kernel actual:  $(uname -r)"
echo "💾 RAM:            $(free -h | awk '/Mem:/ {print $2}')"
echo "============================================================"
echo

# ============================================================
# FUNCIONES
# ============================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

package_installed() {
    pacman -Q "$1" >/dev/null 2>&1
}

backup_file() {
    local file="$1"

    if [ -f "$file" ]; then
        local backup="${file}.backup-$(date +%Y%m%d-%H%M%S)"

        echo "💾 Backup:"
        echo "   $backup"

        sudo cp -a "$file" "$backup"
    fi
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

        echo
        echo "📦 Instalando:"
        echo "   ${packages[*]}"

        sudo pacman -S --needed --noconfirm "${packages[@]}"

    else

        echo "✅ Todos los paquetes ya están instalados."

    fi
}

install_aur_if_missing() {

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

        echo
        echo "📦 AUR:"
        echo "   ${packages[*]}"

        yay -S --needed --noconfirm "${packages[@]}"

    else

        echo "✅ Paquetes AUR ya instalados."

    fi
}

# ============================================================
# 1. SUDO
# ============================================================

echo
echo "🔐 Comprobando sudo..."

if ! command_exists sudo; then

    echo "❌ sudo no está instalado."

    echo "Instala primero:"
    echo "sudo pacman -S sudo"

    exit 1
fi

sudo -v

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
# 2. ACTUALIZAR ARCH
# ============================================================

echo
echo "🔄 Actualizando Arch Linux..."

sudo pacman -Syu --noconfirm

# ============================================================
# 3. PAQUETES BASE
# ============================================================

echo
echo "📦 Instalando base gráfica y herramientas..."

install_pacman_if_missing \
    sudo \
    git \
    curl \
    wget \
    unzip \
    zip \
    base-devel \
    dkms \
    pciutils \
    usbutils \
    psmisc \
    procps-ng \
    lsof \
    htop \
    fastfetch \
    xorg-server \
    xorg-xinit \
    xorg-xrandr \
    xorg-xset \
    xorg-xsetroot \
    mesa \
    mesa-utils \
    vulkan-intel \
    libva \
    libva-utils \
    i3-wm \
    i3status \
    i3lock \
    rofi \
    alacritty \
    feh \
    picom \
    scrot \
    brightnessctl \
    cbatticon \
    network-manager-applet \
    blueman \
    pavucontrol \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    wireplumber \
    thunar \
    gvfs \
    gvfs-mtp \
    gvfs-gphoto2 \
    udiskie \
    xdg-user-dirs \
    xdg-utils \
    firefox \
    lightdm \
    lightdm-gtk-greeter \
    bluez \
    bluez-utils \
    linux-firmware \
    fontconfig \
    zram-generator

# ============================================================
# 4. DETECTAR KERNELS
# ============================================================

echo
echo "============================================================"
echo "🧠 DETECTANDO KERNELS"
echo "============================================================"

KERNEL_PACKAGES=()
HEADER_PACKAGES=()

# Detectar kernels Arch instalados.
if pacman -Qq linux >/dev/null 2>&1; then
    KERNEL_PACKAGES+=("linux")
    HEADER_PACKAGES+=("linux-headers")
fi

if pacman -Qq linux-lts >/dev/null 2>&1; then
    KERNEL_PACKAGES+=("linux-lts")
    HEADER_PACKAGES+=("linux-lts-headers")
fi

if pacman -Qq linux-zen >/dev/null 2>&1; then
    KERNEL_PACKAGES+=("linux-zen")
    HEADER_PACKAGES+=("linux-zen-headers")
fi

if pacman -Qq linux-hardened >/dev/null 2>&1; then
    KERNEL_PACKAGES+=("linux-hardened")
    HEADER_PACKAGES+=("linux-hardened-headers")
fi

# Si no se encontró un kernel estándar, mantener linux.
if [ "${#KERNEL_PACKAGES[@]}" -eq 0 ]; then

    echo "⚠️ No se detectó kernel Arch estándar."
    echo "📦 Instalando linux + headers..."

    install_pacman_if_missing \
        linux \
        linux-headers

else

    echo "✅ Kernels detectados:"
    printf '   %s\n' "${KERNEL_PACKAGES[@]}"

    echo
    echo "📦 Headers correspondientes:"
    printf '   %s\n' "${HEADER_PACKAGES[@]}"

    install_pacman_if_missing "${HEADER_PACKAGES[@]}"

fi

# ============================================================
# 5. ASEGURAR LINUX-FIRMWARE
# ============================================================

echo
echo "🧩 Firmware..."

install_pacman_if_missing \
    linux-firmware

# ============================================================
# 6. DETECTAR CPU / GPU
# ============================================================

echo
echo "============================================================"
echo "🖥️ HARDWARE"
echo "============================================================"

CPU_INFO="$(lscpu | grep -E '^Model name:' || true)"

echo "CPU:"
echo "   $CPU_INFO"

echo
echo "GPU:"

lspci | grep -Ei \
    'VGA|3D|Display' \
    || true

# ============================================================
# 7. DETECTAR WIFI
# ============================================================

echo
echo "============================================================"
echo "📡 DETECTANDO WI-FI"
echo "============================================================"

WIFI_INFO="$(lspci -nn | grep -Ei \
    'network controller|wireless|broadcom|wifi' \
    || true)"

echo "$WIFI_INFO"

# ============================================================
# 8. BROADCOM
# ============================================================

if echo "$WIFI_INFO" | grep -qi broadcom; then

    echo
    echo "📡 Broadcom detectado."

    # Broadcom WL normalmente necesita DKMS + headers.
    install_pacman_if_missing dkms

    if command_exists yay; then

        if package_installed broadcom-wl-dkms; then

            echo "✅ broadcom-wl-dkms ya está instalado."

        else

            echo "📦 Instalando broadcom-wl-dkms..."

            yay -S --needed --noconfirm broadcom-wl-dkms \
                || echo "⚠️ broadcom-wl-dkms no pudo instalarse."

        fi

    else

        echo "⚠️ yay todavía no está disponible."

    fi

else

    echo "ℹ️ No se detectó Broadcom PCI."
    echo "ℹ️ No se instalará broadcom-wl-dkms innecesariamente."

fi

# ============================================================
# 9. YAY
# ============================================================

echo
echo "============================================================"
echo "📦 YAY"
echo "============================================================"

if command_exists yay; then

    echo "✅ yay ya está instalado."

else

    echo "📦 Instalando yay..."

    YAY_TMP="$(mktemp -d)"

    git clone \
        https://aur.archlinux.org/yay.git \
        "$YAY_TMP/yay"

    (
        cd "$YAY_TMP/yay"
        makepkg -si --noconfirm
    )

    rm -rf "$YAY_TMP"

    echo "✅ yay instalado."

fi

# Si Broadcom existe, intentar WL después de yay.
if echo "$WIFI_INFO" | grep -qi broadcom; then

    if ! package_installed broadcom-wl-dkms; then

        echo "📡 Instalando Broadcom WL mediante yay..."

        yay -S --needed --noconfirm broadcom-wl-dkms \
            || echo "⚠️ No fue posible instalar broadcom-wl-dkms."

    fi

fi

# ============================================================
# 10. BRcmfmac
# ============================================================

echo
echo "============================================================"
echo "📡 BRCMFMAC"
echo "============================================================"

# IMPORTANTE:
# No forzamos brcmfmac si el equipo usa wl.
#
# Si el módulo existe, creamos la configuración solicitada.
# Si no existe, no se instala una configuración inútil.

if modinfo brcmfmac >/dev/null 2>&1; then

    echo "✅ brcmfmac disponible."

    sudo tee /etc/modprobe.d/brcmfmac.conf >/dev/null <<'EOF'
# Broadcom brcmfmac
# Optimización de roaming solicitada.

options brcmfmac roamoff=1 feature_disable=0x82000
EOF

    echo "✅ /etc/modprobe.d/brcmfmac.conf configurado."

    sudo modprobe -r brcmfmac 2>/dev/null || true
    sudo modprobe brcmfmac 2>/dev/null || true

else

    echo "ℹ️ brcmfmac no está disponible para este kernel."
    echo "ℹ️ No se fuerza la carga del módulo."

fi

# ============================================================
# 11. NETWORKMANAGER
# ============================================================

echo
echo "🌐 NetworkManager..."

install_pacman_if_missing \
    networkmanager

sudo systemctl enable NetworkManager.service

sudo systemctl restart NetworkManager.service \
    || true

# ============================================================
# 12. BLUETOOTH
# ============================================================

echo
echo "🔵 Bluetooth..."

sudo systemctl enable bluetooth.service

sudo systemctl restart bluetooth.service \
    || true

# ============================================================
# 13. PIPEWIRE
# ============================================================

echo
echo "🔊 PipeWire..."

systemctl --user enable pipewire.service \
    pipewire-pulse.service \
    wireplumber.service \
    2>/dev/null || true

systemctl --user start pipewire.service \
    pipewire-pulse.service \
    wireplumber.service \
    2>/dev/null || true

# ============================================================
# 14. ZRAM
# ============================================================

echo
echo "🧠 Configurando zram..."

sudo mkdir -p /etc/systemd

sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = lz4
swap-priority = 100
EOF

sudo systemctl daemon-reload

sudo systemctl start systemd-zram-setup@zram0.service \
    2>/dev/null || true

echo
echo "📊 ZRAM:"
swapon --show || true

# ============================================================
# 15. LIGHTDM
# ============================================================

echo
echo "============================================================"
echo "🔐 LIGHTDM + AUTOLOGIN"
echo "============================================================"

sudo mkdir -p /etc/lightdm

if [ -f /etc/lightdm/lightdm.conf ]; then
    backup_file /etc/lightdm/lightdm.conf
fi

sudo tee /etc/lightdm/lightdm.conf >/dev/null <<EOF
[LightDM]
run-directory=/run/lightdm

[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=i3

# ============================================================
# AUTOLOGIN
# ============================================================

autologin-user=$USER_NAME
autologin-user-timeout=0
autologin-session=i3

# Evitar problemas gráficos con Xorg/i3.
logind-check-graphical=true
EOF

# ============================================================
# 16. AUTOLOGIN GROUP
# ============================================================

echo
echo "👤 Grupo autologin..."

if ! getent group autologin >/dev/null; then

    sudo groupadd -r autologin

fi

sudo usermod -aG autologin "$USER_NAME"

# ============================================================
# 17. NOPASSWD LOGIN
# ============================================================

echo
echo "🔓 Configurando login sin contraseña..."

if ! getent group nopasswdlogin >/dev/null; then

    sudo groupadd -r nopasswdlogin

fi

sudo usermod -aG nopasswdlogin "$USER_NAME"

# PAM LightDM.
#
# Hacer backup solamente una vez por ejecución.

if [ -f /etc/pam.d/lightdm ]; then

    backup_file /etc/pam.d/lightdm

fi

# Insertar regla solamente si no existe.
if ! sudo grep -q \
    'pam_succeed_if.so user ingroup nopasswdlogin' \
    /etc/pam.d/lightdm 2>/dev/null
then

    sudo sed -i \
        '/^auth[[:space:]]\+include[[:space:]]\+system-login/i auth        sufficient  pam_succeed_if.so user ingroup nopasswdlogin' \
        /etc/pam.d/lightdm

fi

# ============================================================
# 18. SUDO SIN CONTRASEÑA
# ============================================================

echo
echo "============================================================"
echo "🔓 SUDO NOPASSWD"
echo "============================================================"

# Esto permite:
#
# sudo comando
#
# sin solicitar contraseña.
#
# NO se activa sudo para todos los usuarios.
# Solamente para el usuario actual.

sudo tee "/etc/sudoers.d/90-$USER_NAME-nopasswd" >/dev/null <<EOF
$USER_NAME ALL=(ALL:ALL) NOPASSWD: ALL
EOF

sudo chmod 440 \
    "/etc/sudoers.d/90-$USER_NAME-nopasswd"

sudo visudo -cf \
    "/etc/sudoers.d/90-$USER_NAME-nopasswd"

echo "✅ sudo NOPASSWD configurado para: $USER_NAME"

# ============================================================
# 19. OH-MY-BASH
# ============================================================

echo
echo "🐚 oh-my-bash..."

if [ -d "$HOME/.oh-my-bash" ]; then

    echo "✅ oh-my-bash ya instalado."

else

    curl -fsSL \
        https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh \
        | bash -s -- --unattended

fi

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
# 20. FIRA CODE NERD FONT
# ============================================================

echo
echo "🔠 FiraCode Nerd Font..."

mkdir -p "$FONT_DIR"

if find "$FONT_DIR" \
    -type f \
    \( \
        -iname 'FiraCodeNerdFont*.ttf' \
        -o \
        -iname 'FiraCode*.ttf' \
    \) \
    | grep -q .
then

    echo "✅ FiraCode ya instalada."

else

    FONT_TMP="$(mktemp -d)"

    wget -q \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip \
        -O "$FONT_TMP/FiraCode.zip"

    unzip -qo \
        "$FONT_TMP/FiraCode.zip" \
        -d "$FONT_DIR"

    rm -rf "$FONT_TMP"

fi

fc-cache -f >/dev/null 2>&1 || true

# ============================================================
# 21. DIRECTORIOS
# ============================================================

echo
echo "📁 Directorios..."

mkdir -p "$I3_DIR"
mkdir -p "$PICOM_DIR"
mkdir -p "$FONT_DIR"

xdg-user-dirs-update || true

mkdir -p \
    "$HOME/Documentos" \
    "$HOME/Descargas" \
    "$HOME/Música" \
    "$HOME/Videos" \
    "$HOME/Imágenes" \
    "$HOME/Escritorio"

# ============================================================
# 22. COPIAR CONFIG i3
# ============================================================

SOURCE_CONFIG="$SCRIPT_DIR/config"
TARGET_CONFIG="$I3_DIR/config"

if [ -f "$SOURCE_CONFIG" ]; then

    if [ -f "$TARGET_CONFIG" ] \
        && cmp -s "$SOURCE_CONFIG" "$TARGET_CONFIG"
    then

        echo "✅ Config i3 idéntico."

    else

        if [ -f "$TARGET_CONFIG" ]; then
            cp -a \
                "$TARGET_CONFIG" \
                "$TARGET_CONFIG.backup-$(date +%Y%m%d-%H%M%S)"
        fi

        cp -f \
            "$SOURCE_CONFIG" \
            "$TARGET_CONFIG"

        echo "✅ Config i3 copiado."

    fi

else

    echo "⚠️ No existe:"
    echo "   $SOURCE_CONFIG"

fi

# ============================================================
# 23. WALLPAPER
# ============================================================

SOURCE_WALLPAPER="$SCRIPT_DIR/wallpaper.jpg"
TARGET_WALLPAPER="$I3_DIR/wallpaper.jpg"

if [ -f "$SOURCE_WALLPAPER" ]; then

    cp -f \
        "$SOURCE_WALLPAPER" \
        "$TARGET_WALLPAPER"

    echo "✅ Wallpaper copiado."

fi

# ============================================================
# 24. PICOM ULTRALIGERO
# ============================================================

echo
echo "✨ Picom ligero..."

cat > "$PICOM_DIR/picom.conf" <<'EOF'
# ============================================================
# PICOM - ACER E5-571
# Intel Haswell - configuración ligera
# ============================================================

backend = "xrender";

vsync = true;

shadow = false;

fading = false;

inactive-opacity = 1.0;
active-opacity = 1.0;
frame-opacity = 1.0;

blur-method = "none";

corner-radius = 0;

detect-client-opacity = true;

use-damage = true;
EOF

echo "✅ Picom optimizado para hardware antiguo."

# ============================================================
# 25. PICOM AUTOSTART
# ============================================================

PICOM_START="$I3_DIR/picom-autostart.sh"

cat > "$PICOM_START" <<'EOF'
#!/usr/bin/env bash

if command -v picom >/dev/null 2>&1; then

    if ! pgrep -x picom >/dev/null 2>&1; then

        picom \
            --config "$HOME/.config/picom/picom.conf" \
            --daemon

    fi

fi
EOF

chmod +x "$PICOM_START"

# ============================================================
# 26. WALLPAPER AUTOSTART
# ============================================================

WALLPAPER_SCRIPT="$I3_DIR/set-wallpaper.sh"

cat > "$WALLPAPER_SCRIPT" <<'EOF'
#!/usr/bin/env bash

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

# ============================================================
# 27. HDMI 1920x1080 120Hz
# ============================================================

echo
echo "============================================================"
echo "🖥️ HDMI"
echo "============================================================"

HDMI_SCRIPT="$I3_DIR/setup-hdmi.sh"

cat > "$HDMI_SCRIPT" <<'EOF'
#!/usr/bin/env bash

# ============================================================
# HDMI-2 -> 1920x1080 @ 120Hz
# ============================================================

if ! command -v xrandr >/dev/null 2>&1; then
    exit 0
fi

OUTPUT="HDMI-2"

if ! xrandr --query | grep -q "^${OUTPUT} connected"; then
    exit 0
fi

if ! xrandr --query \
    | grep -Eq '1920x1080.*120(\.00)?'
then
    echo "ℹ️ HDMI-2 1920x1080@120 no está disponible."
    exit 0
fi

xrandr \
    --output "$OUTPUT" \
    --mode 1920x1080 \
    --rate 120.00
EOF

chmod +x "$HDMI_SCRIPT"

# ============================================================
# 28. i3 AUTOSTART
# ============================================================

if [ -f "$TARGET_CONFIG" ]; then

    # Quitar bloques que este instalador haya añadido anteriormente.
    sed -i \
        '/# ACER E5-571 AUTOSTART BEGIN/,/# ACER E5-571 AUTOSTART END/d' \
        "$TARGET_CONFIG"

    cat >> "$TARGET_CONFIG" <<'EOF'

# ============================================================
# ACER E5-571 AUTOSTART BEGIN
# ============================================================

# Picom ligero
exec_always --no-startup-id ~/.config/i3/picom-autostart.sh

# Wallpaper
exec_always --no-startup-id ~/.config/i3/set-wallpaper.sh

# HDMI automático si existe HDMI-2 y 1920x1080@120.
exec_always --no-startup-id ~/.config/i3/setup-hdmi.sh

# ============================================================
# HDMI MANUAL SOLICITADO
# ============================================================

# exec_always --no-startup-id xrandr --output HDMI-2 --mode 1920x1080 --rate 120.00

# ACER E5-571 AUTOSTART END
EOF

    echo "✅ Autostart i3 configurado."

fi

# ============================================================
# 29. BRILLO / ACER
# ============================================================

echo
echo "💡 Configurando brillo..."

sudo usermod -aG video "$USER_NAME" 2>/dev/null || true

# ============================================================
# 30. THERMAL / POWER
# ============================================================

echo
echo "🔋 Optimización energética..."

install_pacman_if_missing \
    thermald

sudo systemctl enable thermald.service \
    2>/dev/null || true

sudo systemctl start thermald.service \
    2>/dev/null || true

# ============================================================
# 31. DISABLE SERVICIOS INNECESARIOS SI EXISTEN
# ============================================================

echo
echo "🧹 Revisando servicios..."

# No tocar NetworkManager, Bluetooth, LightDM ni PipeWire.

for service in \
    cups.service \
    avahi-daemon.service \
    ModemManager.service
do

    if systemctl list-unit-files \
        | grep -q "^${service}"
    then

        echo "ℹ️ $service instalado; no se desactiva automáticamente."

    fi

done

# ============================================================
# 32. REGENERAR MODULOS
# ============================================================

echo
echo "🧩 Regenerando dependencias de módulos..."

sudo depmod -a

# DKMS para todos los kernels instalados.
if command_exists dkms; then

    sudo dkms autoinstall \
        || echo "⚠️ Algún módulo DKMS no pudo compilar."

fi

# ============================================================
# 33. MKINITCPIO
# ============================================================

echo
echo "🔧 Actualizando initramfs..."

sudo mkinitcpio -P

# ============================================================
# 34. LIGHTDM
# ============================================================

echo
echo "🔐 Activando LightDM..."

# Desactivar gestores alternativos conocidos.
for dm in \
    gdm.service \
    sddm.service \
    ly.service \
    lydm.service
do

    if systemctl list-unit-files \
        | grep -q "^${dm}"
    then

        sudo systemctl disable "$dm" \
            2>/dev/null || true

    fi

done

sudo systemctl enable lightdm.service

# ============================================================
# 35. VALIDAR LIGHTDM
# ============================================================

echo
echo "🔍 Configuración LightDM..."

if command_exists lightdm; then

    lightdm --show-config \
        || true

fi

# ============================================================
# 36. VALIDAR SUDOERS
# ============================================================

echo
echo "🔍 Validando sudoers..."

sudo visudo -c

# ============================================================
# 37. VALIDAR i3
# ============================================================

echo
echo "🔍 Validando i3..."

if command_exists i3; then

    i3 --version

fi

# ============================================================
# 38. VALIDAR PICOM
# ============================================================

echo
echo "🔍 Validando Picom..."

if command_exists picom; then

    picom --version

fi

# ============================================================
# 39. VALIDAR XRANDR
# ============================================================

echo
echo "🖥️ Salidas de vídeo detectadas:"

if command_exists xrandr; then

    xrandr --query \
        || true

fi

# ============================================================
# 40. VALIDAR WIFI
# ============================================================

echo
echo "📡 Interfaces de red:"

ip -br link \
    || true

echo
echo "📡 NetworkManager:"

nmcli device status \
    || true

# ============================================================
# 41. VALIDAR BLUETOOTH
# ============================================================

echo
echo "🔵 Bluetooth:"

systemctl is-enabled bluetooth.service \
    2>/dev/null \
    || true

# ============================================================
# 42. MEMORIA
# ============================================================

echo
echo "============================================================"
echo "🧠 MEMORIA"
echo "============================================================"

free -h

echo
echo "SWAP / ZRAM:"

swapon --show \
    || true

# ============================================================
# 43. KERNELS
# ============================================================

echo
echo "============================================================"
echo "🧠 KERNELS INSTALADOS"
echo "============================================================"

pacman -Q \
    | grep -E '^linux(-lts|-zen|-hardened)? ' \
    || true

echo
echo "Kernel actual:"
uname -r

# ============================================================
# 44. DKMS
# ============================================================

echo
echo "============================================================"
echo "🧩 DKMS"
echo "============================================================"

if command_exists dkms; then

    dkms status \
        || true

fi

# ============================================================
# 45. DRIVERS GPU
# ============================================================

echo
echo "============================================================"
echo "🎮 GPU"
echo "============================================================"

if command_exists glxinfo; then

    glxinfo -B \
        2>/dev/null \
        | grep -E \
            'OpenGL vendor|OpenGL renderer|OpenGL version' \
        || true

fi

# ============================================================
# 46. COMPROBACIÓN FINAL
# ============================================================

echo
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
check_command i3status
check_command xrandr
check_command picom
check_command feh
check_command rofi
check_command alacritty
check_command firefox
check_command yay
check_command nmcli
check_command brightnessctl
check_command fastfetch

echo

if package_installed lightdm; then
    echo "✅ LightDM instalado"
else
    echo "⚠️ LightDM no instalado"
fi

if systemctl is-enabled lightdm.service \
    >/dev/null 2>&1
then

    echo "✅ LightDM habilitado"

else

    echo "⚠️ LightDM no está habilitado"

fi

if id -nG "$USER_NAME" \
    | grep -qw autologin
then

    echo "✅ Usuario en grupo autologin"

else

    echo "⚠️ Usuario no aparece en autologin"

fi

if id -nG "$USER_NAME" \
    | grep -qw nopasswdlogin
then

    echo "✅ Usuario en grupo nopasswdlogin"

else

    echo "⚠️ Usuario no aparece en nopasswdlogin"

fi

if [ -f "/etc/sudoers.d/90-$USER_NAME-nopasswd" ]; then

    echo "✅ sudo NOPASSWD configurado"

fi

if [ -f "$I3_DIR/config" ]; then
    echo "✅ $I3_DIR/config"
fi

if [ -f "$I3_DIR/wallpaper.jpg" ]; then
    echo "✅ $I3_DIR/wallpaper.jpg"
fi

if [ -f "$PICOM_DIR/picom.conf" ]; then
    echo "✅ $PICOM_DIR/picom.conf"
fi

if [ -f "$I3_DIR/setup-hdmi.sh" ]; then
    echo "✅ HDMI script"
fi

if [ -f "/etc/modprobe.d/brcmfmac.conf" ]; then
    echo "✅ /etc/modprobe.d/brcmfmac.conf"
fi

# ============================================================
# 47. FINAL
# ============================================================

cd "$SCRIPT_DIR"

echo
echo "============================================================"
echo "✅ INSTALACIÓN TERMINADA"
echo "============================================================"
echo
echo "🖥️ Equipo:"
echo "   Acer Aspire E5-571"
echo
echo "🧠 CPU:"
echo "   Intel Core i3-4005U"
echo
echo "🎮 GPU:"
echo "   Intel Haswell-ULT"
echo
echo "🧩 i3:"
echo "   $I3_DIR/config"
echo
echo "🖼️ Wallpaper:"
echo "   $I3_DIR/wallpaper.jpg"
echo
echo "✨ Picom:"
echo "   $PICOM_DIR/picom.conf"
echo
echo "🖥️ HDMI:"
echo "   $I3_DIR/setup-hdmi.sh"
echo
echo "🔐 Login:"
echo "   LightDM + autologin + i3"
echo
echo "🔓 sudo:"
echo "   NOPASSWD para $USER_NAME"
echo
echo "🧠 Memoria:"
echo "   zram activado"
echo
echo "📡 Wi-Fi:"
echo "   Driver Broadcom solamente si el hardware lo requiere"
echo
echo "============================================================"
echo
echo "⚠️ IMPORTANTE:"
echo
echo "El usuario $USER_NAME debe cerrar sesión o reiniciar"
echo "para que todos los nuevos grupos surtan efecto."
echo
echo "Recomendado:"
echo
echo "   sudo reboot"
echo
echo "============================================================"
