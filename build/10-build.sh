#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Main Build Script
###############################################################################
# This script follows the @ublue-os/bluefin pattern for build scripts.
# It uses set -eoux pipefail for strict error handling and debugging.
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

echo "::group:: Copy Custom Files"

# Copy Brewfiles to standard location
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/ublue-os/homebrew/

# Consolidate Just Files
mkdir -p /usr/share/ublue-os/just/
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just

# Copy Flatpak preinstall files
mkdir -p /etc/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /etc/flatpak/preinstall.d/

echo "::endgroup::"

echo "::group:: Install Packages"

# Install packages using dnf5
# Example: dnf5 install -y tmux

# Base packages from Fedora repos - common to all versions
FEDORA_PACKAGES=(
    adw-gtk3-theme
    adwaita-fonts-all
    bash-color-prompt
    bootc
    ddcutil
    fastfetch
    gcc
    git-credential-libsecret
    gnome-tweaks
    igt-gpu-tools
    iwd
    just
    lm_sensors
    make
    mesa-libGLU
    pulseaudio-utils
    python3-pip
    setools-console
    wireguard-tools
    wl-clipboard
    edk2-ovmf
    libvirt
    libvirt-nss
    podman-compose
    podman-machine
    qemu
    qemu-char-spice
    qemu-device-display-virtio-gpu
    qemu-device-display-virtio-vga
    qemu-device-usb-redirect
    qemu-img
    qemu-system-x86-core
    qemu-user-binfmt
    qemu-user-static
    udica
    virt-manager
    virt-viewer
    virt-v2v
)

# Install all Fedora packages (bulk - safe from COPR injection)
echo "Installing ${#FEDORA_PACKAGES[@]} packages from Fedora repos..."
dnf -y install "${FEDORA_PACKAGES[@]}"

# Example using COPR with isolated pattern:
# copr_install_isolated "ublue-os/staging" package-name

# Packages to exclude - common to all versions
EXCLUDED_PACKAGES=(
    fedora-bookmarks
    fedora-chromium-config
    fedora-chromium-config-gnome
    firefox
    firefox-langpacks
    gnome-extensions-app
    gnome-software-rpm-ostree
    podman-docker
)

# Remove excluded packages if they are installed
if [[ "${#EXCLUDED_PACKAGES[@]}" -gt 0 ]]; then
    readarray -t INSTALLED_EXCLUDED < <(rpm -qa --queryformat='%{NAME}\n' "${EXCLUDED_PACKAGES[@]}" 2>/dev/null || true)
    if [[ "${#INSTALLED_EXCLUDED[@]}" -gt 0 ]]; then
        dnf -y remove "${INSTALLED_EXCLUDED[@]}"
    else
        echo "No excluded packages found to remove."
    fi
fi

# brave
/ctx/build/20-brave.sh

echo "::endgroup::"

echo "::group:: System Configuration"

# Enable/disable systemd services
#systemctl enable podman.socket
systemctl --global enable podman-auto-update.timer
# Example: systemctl mask unwanted-service

echo "Disabling print services"
systemctl disable cups.socket
systemctl mask cups.socket
systemctl disable cups.service
systemctl mask cups.service
systemctl disable cups-browsed.service
systemctl mask cups-browsed.service

echo "Disabling avahi-daemon"
systemctl disable avahi-daemon.socket
systemctl mask avahi-daemon.socket
systemctl disable avahi-daemon.service
systemctl mask avahi-daemon.service

echo "Disabling the modem manager"
systemctl disable ModemManager.service
systemctl mask ModemManager.service

echo "Disabling the sssd daemons"
systemctl disable sssd.service
systemctl mask sssd.service
systemctl disable sssd-kcm.service
systemctl mask sssd-kcm.service
systemctl disable sssd-kcm.socket
systemctl mask sssd-kcm.socket

echo "Disabling the location service"
systemctl disable geoclue.service
systemctl mask geoclue.service

echo "::endgroup::"

echo "::group:: Clean Up"

/ctx/build/60-clean.sh
/ctx/build/70-validate-repos.sh

echo "::endgroup::"

echo "Custom build complete!"
