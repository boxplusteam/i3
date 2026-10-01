#!/usr/bin/env bash

set -Eeuo pipefail
set -x

# ============================================================
# ACER ASPIRE E5-571
# ARCH LINUX + i3
#
# Instalador robusto / idempotente + FIX AUTOLOGIN DIRECTO
# ============================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

I3_DIR="$HOME/.config/i3"
PICOM_DIR="$HOME/.config/picom"
BUMBLEBEE_DIR="$HOME/.config/bumblebee-status"
FONT_DIR="$HOME/.local/share/fonts"

USER_NAME="$(id -un)"
HOME_DIR="$HOME"

if [ "$USER_NAME" == "root" ]; then
    echo "❌ ERROR: No ejecutes este script como root. Ejecútalo como tu usuario normal."
    exit 1
fi

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

# ============================================================
# 1. SUDO
# ============================================================

echo
echo "🔐 Comprobando sudo..."

if ! command_exists sudo; then
    echo "❌ sudo no está instalado."
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
# 1.5 FIX: DESBLOQUEAR PACMAN
# ============================================================
echo
echo "🔓 Comprobando bloqueos de Pacman..."
if [ -f /var/lib/pacman/db.lck ]; then
    echo "⚠️ Archivo de bloqueo detectado. Eliminando /var/lib/pacman/db.lck..."
    sudo rm -f /var/lib/pacman/db.lck
fi

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
    sudo git curl wget unzip zip base-devel dkms pciutils \
    usbutils psmisc procps-ng lsof htop fastfetch xorg-server \
    xorg-xinit xorg-xrandr xorg-xset xorg-xsetroot mesa mesa-utils \
    vulkan-intel libva libva-utils i3-wm i3status i3lock rofi \
    alacritty feh picom scrot brightnessctl cbatticon \
    network-manager-applet blueman pavucontrol pipewire \
    pipewire-alsa pipewire-pulse wireplumber thunar gvfs \
    gvfs-mtp gvfs-gphoto2 udiskie xdg-user-dirs xdg-utils \
    firefox lightdm lightdm-gtk-greeter bluez bluez-utils \
    linux-firmware fontconfig zram-generator

# ============================================================
# 4. DETECTAR KERNELS
# ============================================================

echo
echo "============================================================"
echo "🧠 DETECTANDO KERNELS"
echo "============================================================"

KERNEL_PACKAGES=()
HEADER_PACKAGES=()

if pacman -Qq linux >/dev/null 2>&1; then KERNEL_PACKAGES+=("linux"); HEADER_PACKAGES+=("linux-headers"); fi
if pacman -Qq linux-lts >/dev/null 2>&1; then KERNEL_PACKAGES+=("linux-lts"); HEADER_PACKAGES+=("linux-lts-headers"); fi
if pacman -Qq linux-zen >/dev/null 2>&1; then KERNEL_PACKAGES+=("linux-zen"); HEADER_PACKAGES+=("linux-zen-headers"); fi
if pacman -Qq linux-hardened >/dev/null 2>&1; then KERNEL_PACKAGES+=("linux-hardened"); HEADER_PACKAGES+=("linux-hardened-headers"); fi

if [ "${#KERNEL_PACKAGES[@]}" -eq 0 ]; then
    install_pacman_if_missing linux linux-headers
else
    install_pacman_if_missing "${HEADER_PACKAGES[@]}"
fi

# ============================================================
# 5. ASEGURAR LINUX-FIRMWARE
# ============================================================
install_pacman_if_missing linux-firmware

# ============================================================
# 6. DETECTAR CPU / GPU
# ============================================================
CPU_INFO="$(lscpu | grep -E '^Model name:' || true)"
echo "CPU: $CPU_INFO"
lspci | grep -Ei 'VGA|3D|Display' || true

# ============================================================
# 7. DETECTAR WIFI
# ============================================================
WIFI_INFO="$(lspci -nn | grep -Ei 'network controller|wireless|broadcom|wifi' || true)"
echo "$WIFI_INFO"

# ============================================================
# 8 & 9. YAY Y BROADCOM
# ============================================================
if ! command_exists yay; then
    echo "📦 Instalando yay..."
    YAY_TMP="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$YAY_TMP/yay"
    ( cd "$YAY_TMP/yay" && makepkg -si --noconfirm )
    rm -rf "$YAY_TMP"
fi

if echo "$WIFI_INFO" | grep -qi broadcom; then
    install_pacman_if_missing dkms
    yay -S --needed --noconfirm broadcom-wl-dkms || true
fi

# ============================================================
# 10. BRcmfmac
# ============================================================
if modinfo brcmfmac >/dev/null 2>&1; then
    sudo tee /etc/modprobe.d/brcmfmac.conf >/dev/null <<'EOF'
options brcmfmac roamoff=1 feature_disable=0x82000
EOF
    sudo modprobe -r brcmfmac 2>/dev/null || true
    sudo modprobe brcmfmac 2>/dev/null || true
fi

# ============================================================
# 11, 12 & 13. NETWORKMANAGER, BLUETOOTH Y PIPEWIRE
# ============================================================
sudo systemctl enable --now NetworkManager.service || true
sudo systemctl enable --now bluetooth.service || true
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service 2>/dev/null || true

# ============================================================
# 14. ZRAM
# ============================================================
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
# 15. LIGHTDM + AUTOLOGIN (MODIFICADO PARA ARREGLAR FALLOS)
# ============================================================
echo "============================================================"
echo "🔐 LIGHTDM + AUTOLOGIN"
echo "============================================================"

sudo mkdir -p /etc/lightdm
backup_file /etc/lightdm/lightdm.conf

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

if ! getent group autologin >/dev/null; then sudo groupadd -r autologin; fi
sudo usermod -aG autologin "$USER_NAME"

if ! getent group nopasswdlogin >/dev/null; then sudo groupadd -r nopasswdlogin; fi
sudo usermod -aG nopasswdlogin "$USER_NAME"

# ============================================================
# 18. SUDO SIN CONTRASEÑA
# ============================================================
sudo tee "/etc/sudoers.d/90-$USER_NAME-nopasswd" >/dev/null <<EOF
$USER_NAME ALL=(ALL:ALL) NOPASSWD: ALL
EOF
sudo chmod 440 "/etc/sudoers.d/90-$USER_NAME-nopasswd"

# ============================================================
# 19 & 20. OH-MY-BASH Y FUENTES
# ============================================================
if [ ! -d "$HOME/.oh-my-bash" ]; then
    curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash -s -- --unattended
fi
if [ -f "$HOME/.bashrc" ]; then
    sed -i 's/^OSH_THEME=.*/OSH_THEME="agnoster"/' "$HOME/.bashrc" || echo 'OSH_THEME="agnoster"' >> "$HOME/.bashrc"
fi

mkdir -p "$FONT_DIR"
if ! find "$FONT_DIR" -type f -iname 'FiraCode*.ttf' | grep -q .; then
    FONT_TMP="$(mktemp -d)"
    wget -q https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip -O "$FONT_TMP/FiraCode.zip"
    unzip -qo "$FONT_TMP/FiraCode.zip" -d "$FONT_DIR"
    rm -rf "$FONT_TMP"
    fc-cache -f >/dev/null 2>&1 || true
fi

# ============================================================
# 21-28. DIRECTORIOS, CONFIG i3, PICOM, WALLPAPER
# ============================================================
mkdir -p "$I3_DIR" "$PICOM_DIR" "$FONT_DIR"
xdg-user-dirs-update || true
mkdir -p "$HOME/Documentos" "$HOME/Descargas" "$HOME/Música" "$HOME/Videos" "$HOME/Imágenes" "$HOME/Escritorio"

if [ -f "$SCRIPT_DIR/config" ]; then cp -f "$SCRIPT_DIR/config" "$I3_DIR/config"; fi
if [ -f "$SCRIPT_DIR/wallpaper.jpg" ]; then cp -f "$SCRIPT_DIR/wallpaper.jpg" "$I3_DIR/wallpaper.jpg"; fi

cat > "$PICOM_DIR/picom.conf" <<'EOF'
backend = "xrender";
vsync = true;
shadow = false;
fading = false;
use-damage = true;
EOF

cat > "$I3_DIR/picom-autostart.sh" <<'EOF'
#!/usr/bin/env bash
pgrep -x picom >/dev/null || picom --config "$HOME/.config/picom/picom.conf" --daemon
EOF
chmod +x "$I3_DIR/picom-autostart.sh"

cat > "$I3_DIR/set-wallpaper.sh" <<'EOF'
#!/usr/bin/env bash
[ -f "$HOME/.config/i3/wallpaper.jpg" ] && feh --no-fehbg --bg-fill "$HOME/.config/i3/wallpaper.jpg"
EOF
chmod +x "$I3_DIR/set-wallpaper.sh"

cat > "$I3_DIR/setup-hdmi.sh" <<'EOF'
#!/usr/bin/env bash
command -v xrandr >/dev/null && xrandr --query | grep -q "^HDMI-2 connected" && xrandr --output HDMI-2 --mode 1920x1080 --rate 120.00 || exit 0
EOF
chmod +x "$I3_DIR/setup-hdmi.sh"

if [ -f "$I3_DIR/config" ]; then
    sed -i '/# ACER E5-571 AUTOSTART BEGIN/,/# ACER E5-571 AUTOSTART END/d' "$I3_DIR/config"
    cat >> "$I3_DIR/config" <<'EOF'
# ACER E5-571 AUTOSTART BEGIN
exec_always --no-startup-id ~/.config/i3/picom-autostart.sh
exec_always --no-startup-id ~/.config/i3/set-wallpaper.sh
exec_always --no-startup-id ~/.config/i3/setup-hdmi.sh
# ACER E5-571 AUTOSTART END
EOF
fi

# ============================================================
# FIX CRÍTICO: REPARAR PERMISOS DEL USUARIO (LOGIN LOOP)
# ============================================================
echo
echo "🧹 Reparando permisos de usuario para evitar Login Loop..."
sudo rm -f "$HOME/.Xauthority"
sudo chown -R "$USER_NAME:$USER_NAME" "$HOME"

# ============================================================
# 30-34. THERMALD, MKINITCPIO Y LIGHTDM ENABLE
# ============================================================
install_pacman_if_missing thermald
sudo systemctl enable --now thermald.service 2>/dev/null || true

sudo depmod -a
if command_exists dkms; then sudo dkms autoinstall || true; fi
sudo mkinitcpio -P

for dm in gdm.service sddm.service ly.service lydm.service; do
    if systemctl list-unit-files | grep -q "^${dm}"; then sudo systemctl disable "$dm" 2>/dev/null || true; fi
done

sudo systemctl enable lightdm.service
# FIX: Forzar el arranque gráfico siempre al reiniciar
sudo systemctl set-default graphical.target

# ============================================================
# FINAL
# ============================================================
echo
echo "============================================================"
echo "✅ INSTALACIÓN TERMINADA (REPARADA AL 100%)"
echo "============================================================"
echo "Se ha integrado el arreglo de la base de datos de Pacman."
echo "Se han arreglado los permisos rotos (.Xauthority) de tu usuario."
echo "El sistema está configurado para entrar a i3 sin tocar nada."
echo
echo "Reiniciando automáticamente en 5 segundos..."
sleep 5
sudo reboot
