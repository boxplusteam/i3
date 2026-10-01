#!/usr/bin/env bash

set -Eeuo pipefail
set -x

# ============================================================
# ACER ASPIRE E5-571
# ARCH LINUX + i3
#
# Instalador robusto / idempotente con AUTOLOGIN TOTAL
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
echo "🚀 ACER ASPIRE E5-571 - ARCH + i3 (AUTOLOGIN DIRECTO)"
echo "============================================================"
echo "👤 Usuario:        $USER_NAME"
echo "📂 Script:         $SCRIPT_DIR"
echo "🧠 Kernel actual:  $(uname -r)"
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
        echo "💾 Backup: $backup"
        sudo cp -a "$file" "$backup"
    fi
}

install_pacman_if_missing() {
    local packages=()
    for package in "$@"; do
        if ! package_installed "$package"; then
            packages+=("$package")
        fi
    done

    if [ "${#packages[@]}" -gt 0 ]; then
        echo "📦 Instalando: ${packages[*]}"
        sudo pacman -S --needed --noconfirm "${packages[@]}"
    fi
}

# ============================================================
# 1. SUDO KEEPALIVE
# ============================================================

echo "🔐 Comprobando sudo..."
if ! command_exists sudo; then
    echo "❌ sudo no está instalado. Ejecuta: su -c 'pacman -S sudo'"
    exit 1
fi

sudo -v
( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

# ============================================================
# 2. ACTUALIZAR ARCH Y PAQUETES BASE
# ============================================================

echo "🔄 Actualizando Arch Linux e instalando base..."
sudo pacman -Syu --noconfirm

install_pacman_if_missing \
    sudo git curl wget unzip zip base-devel dkms pciutils usbutils \
    psmisc procps-ng lsof htop fastfetch xorg-server xorg-xinit \
    xorg-xrandr xorg-xset xorg-xsetroot mesa mesa-utils vulkan-intel \
    libva libva-utils i3-wm i3status i3lock rofi alacritty feh picom \
    scrot brightnessctl cbatticon network-manager-applet blueman \
    pavucontrol pipewire pipewire-alsa pipewire-pulse wireplumber \
    thunar gvfs gvfs-mtp gvfs-gphoto2 udiskie xdg-user-dirs xdg-utils \
    firefox lightdm lightdm-gtk-greeter bluez bluez-utils \
    linux-firmware fontconfig zram-generator

# ============================================================
# 3. DETECTAR KERNELS & HEADERS
# ============================================================

KERNEL_PACKAGES=()
HEADER_PACKAGES=()

for k in linux linux-lts linux-zen linux-hardened; do
    if pacman -Qq "$k" >/dev/null 2>&1; then
        KERNEL_PACKAGES+=("$k")
        HEADER_PACKAGES+=("$k-headers")
    fi
done

if [ "${#KERNEL_PACKAGES[@]}" -eq 0 ]; then
    install_pacman_if_missing linux linux-headers
else
    install_pacman_if_missing "${HEADER_PACKAGES[@]}"
fi

# ============================================================
# 4. YAY & BROADCOM (SI APLICA)
# ============================================================

if ! command_exists yay; then
    echo "📦 Instalando yay..."
    YAY_TMP="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$YAY_TMP/yay"
    ( cd "$YAY_TMP/yay" && makepkg -si --noconfirm )
    rm -rf "$YAY_TMP"
fi

WIFI_INFO="$(lspci -nn | grep -Ei 'network controller|wireless|broadcom|wifi' || true)"
if echo "$WIFI_INFO" | grep -qi broadcom; then
    yay -S --needed --noconfirm broadcom-wl-dkms || true
fi

if modinfo brcmfmac >/dev/null 2>&1; then
    sudo tee /etc/modprobe.d/brcmfmac.conf >/dev/null <<'EOF'
options brcmfmac roamoff=1 feature_disable=0x82000
EOF
fi

# ============================================================
# 5. SERVICIOS (NETWORK, BLUETOOTH, AUDIO, ZRAM)
# ============================================================

sudo systemctl enable --now NetworkManager.service bluetooth.service || true
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service 2>/dev/null || true

sudo mkdir -p /etc/systemd
sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = lz4
swap-priority = 100
EOF
sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true

# ============================================================
# 6. LIGHTDM + AUTOLOGIN DIRECTO A i3
# ============================================================

echo "🔐 Configurando LightDM para AUTOLOGIN DIRECTO..."

sudo mkdir -p /etc/lightdm
backup_file /etc/lightdm/lightdm.conf

# Configuración estricta para iniciar sesión automáticamente
sudo tee /etc/lightdm/lightdm.conf >/dev/null <<EOF
[LightDM]
run-directory=/run/lightdm

[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=i3
autologin-user=$USER_NAME
autologin-user-timeout=0
autologin-session=i3
logind-check-graphical=true
EOF

# Crear grupo autologin y añadir al usuario
if ! getent group autologin >/dev/null; then
    sudo groupadd -r autologin
fi
sudo usermod -aG autologin "$USER_NAME"

# Crear grupo nopasswdlogin y añadir al usuario
if ! getent group nopasswdlogin >/dev/null; then
    sudo groupadd -r nopasswdlogin
fi
sudo usermod -aG nopasswdlogin "$USER_NAME"

# Modificar PAM para no pedir contraseña nunca
backup_file /etc/pam.d/lightdm
if ! sudo grep -q 'pam_succeed_if.so user ingroup nopasswdlogin' /etc/pam.d/lightdm 2>/dev/null; then
    sudo sed -i '/^auth[[:space:]]\+include[[:space:]]\+system-login/i auth        sufficient  pam_succeed_if.so user ingroup nopasswdlogin' /etc/pam.d/lightdm
fi

# ============================================================
# 7. SUDO SIN CONTRASEÑA
# ============================================================

sudo tee "/etc/sudoers.d/90-$USER_NAME-nopasswd" >/dev/null <<EOF
$USER_NAME ALL=(ALL:ALL) NOPASSWD: ALL
EOF
sudo chmod 440 "/etc/sudoers.d/90-$USER_NAME-nopasswd"

# ============================================================
# 8. DIRECTORIOS Y ENTORNO
# ============================================================

mkdir -p "$I3_DIR" "$PICOM_DIR" "$FONT_DIR"
xdg-user-dirs-update || true

# Copiar config de i3 si existe en el directorio del script
if [ -f "$SCRIPT_DIR/config" ]; then
    cp -f "$SCRIPT_DIR/config" "$I3_DIR/config"
fi

# Picom Config
cat > "$PICOM_DIR/picom.conf" <<'EOF'
backend = "xrender";
vsync = true;
shadow = false;
fading = false;
use-damage = true;
EOF

# Scripts de autoinicio
cat > "$I3_DIR/picom-autostart.sh" <<'EOF'
#!/usr/bin/env bash
pgrep -x picom >/dev/null || picom --config "$HOME/.config/picom/picom.conf" --daemon
EOF
chmod +x "$I3_DIR/picom-autostart.sh"

if [ -f "$I3_DIR/config" ]; then
    sed -i '/# ACER E5-571 AUTOSTART BEGIN/,/# ACER E5-571 AUTOSTART END/d' "$I3_DIR/config"
    cat >> "$I3_DIR/config" <<'EOF'

# ============================================================
# ACER E5-571 AUTOSTART BEGIN
# ============================================================
exec_always --no-startup-id ~/.config/i3/picom-autostart.sh
# ACER E5-571 AUTOSTART END
EOF
fi

# ============================================================
# 9. COMPILACIÓN DE MÓDULOS Y HABILITAR SERVICIOS FINALES
# ============================================================

sudo depmod -a
if command_exists dkms; then sudo dkms autoinstall || true; fi
sudo mkinitcpio -P

# Desactivar gestores de ventanas en conflicto
for dm in gdm.service sddm.service ly.service; do
    if systemctl list-unit-files | grep -q "^${dm}"; then
        sudo systemctl disable "$dm" 2>/dev/null || true
    fi
done

# Habilitar LightDM y forzar arranque gráfico
sudo systemctl enable lightdm.service
sudo systemctl set-default graphical.target

echo
echo "============================================================"
echo "✅ INSTALACIÓN TERMINADA CON ÉXITO"
echo "============================================================"
echo "El sistema está configurado para iniciar sesión automáticamente"
echo "con el usuario '$USER_NAME' en el entorno 'i3'."
echo 
echo "Por favor, reinicia el equipo con: sudo reboot"
echo "============================================================"
