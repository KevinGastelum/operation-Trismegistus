#!/usr/bin/env bash
# ============================================================
# Ubuntu Linux Setup Script — Lucratitan Device
# Run this on your Ubuntu machine to set up collaboration
# with the Windows machine (KevinGastelum)
#
# Usage: chmod +x setup-linux-collab.sh && ./setup-linux-collab.sh
# ============================================================

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Cross-Device Collaboration Setup (Ubuntu Side)  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ----- Step 1: SSH Server -----
echo -e "${YELLOW}[1/6] Setting up SSH Server...${NC}"
if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
    echo -e "${GREEN}  ✅ SSH server is already running${NC}"
else
    echo "  Installing and enabling OpenSSH server..."
    sudo apt update -qq
    sudo apt install -y openssh-server
    sudo systemctl enable ssh
    sudo systemctl start ssh
    echo -e "${GREEN}  ✅ SSH server installed and started${NC}"
fi

LOCAL_IP=$(hostname -I | awk '{print $1}')
echo -e "  ${BLUE}📡 Your local IP: ${LOCAL_IP}${NC}"
echo -e "  ${BLUE}   Use this IP in your Windows SSH config (Host ubuntu-dev)${NC}"
echo ""

# ----- Step 2: Git Configuration -----
echo -e "${YELLOW}[2/6] Configuring Git identity (Lucratitan)...${NC}"
read -rp "  Enter the email for your Lucratitan GitHub account: " LUCRATITAN_EMAIL

git config --global user.name "Lucratitan"
git config --global user.email "$LUCRATITAN_EMAIL"
git config --global core.autocrlf input
git config --global core.pager "less -FRX"
echo -e "${GREEN}  ✅ Git configured: Lucratitan <${LUCRATITAN_EMAIL}>${NC}"
echo ""

# ----- Step 3: SSH Key for GitHub -----
echo -e "${YELLOW}[3/6] Setting up SSH key for GitHub...${NC}"
SSH_KEY="$HOME/.ssh/id_lucratitan"

if [ -f "$SSH_KEY" ]; then
    echo -e "${GREEN}  ✅ SSH key already exists: ${SSH_KEY}${NC}"
else
    echo "  Generating new ed25519 key..."
    ssh-keygen -t ed25519 -C "$LUCRATITAN_EMAIL" -f "$SSH_KEY" -N ""
    echo -e "${GREEN}  ✅ SSH key generated${NC}"
fi

# Configure SSH for GitHub
SSH_CONFIG="$HOME/.ssh/config"
if grep -q "github.com" "$SSH_CONFIG" 2>/dev/null; then
    echo -e "  ${YELLOW}⚠️  GitHub entry already in SSH config — skipping${NC}"
else
    mkdir -p "$HOME/.ssh"
    cat >> "$SSH_CONFIG" <<EOF

# === GitHub (Lucratitan) ===
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_lucratitan
    IdentitiesOnly yes
EOF
    chmod 600 "$SSH_CONFIG"
    echo -e "${GREEN}  ✅ SSH config updated${NC}"
fi

echo ""
echo -e "  ${RED}🔑 IMPORTANT: Add this public key to your Lucratitan GitHub account:${NC}"
echo -e "  ${BLUE}   Go to: https://github.com/settings/keys → New SSH Key${NC}"
echo ""
echo "  --- Copy everything below this line ---"
cat "${SSH_KEY}.pub"
echo "  --- End of key ---"
echo ""
read -rp "  Press Enter after you've added the key to GitHub..."

# Test connection
echo "  Testing GitHub SSH connection..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo -e "${GREEN}  ✅ GitHub SSH authentication successful!${NC}"
else
    echo -e "${YELLOW}  ⚠️  Could not verify — you may need to accept GitHub's host key first.${NC}"
    echo -e "  Try running: ssh -T git@github.com"
fi
echo ""

# ----- Step 4: Clone the repo -----
echo -e "${YELLOW}[4/6] Setting up the repository...${NC}"
CODING_DIR="$HOME/Coding"
REPO_DIR="$CODING_DIR/operation-Trismegistus"

mkdir -p "$CODING_DIR"

if [ -d "$REPO_DIR" ]; then
    echo -e "${GREEN}  ✅ Repository already exists at: ${REPO_DIR}${NC}"
else
    read -rp "  Clone operation-Trismegistus? (y/n): " DO_CLONE
    if [[ "$DO_CLONE" =~ ^[Yy]$ ]]; then
        echo "  Cloning..."
        git clone git@github.com:KevinGastelum/operation-Trismegistus.git "$REPO_DIR"
        echo -e "${GREEN}  ✅ Repository cloned to ${REPO_DIR}${NC}"
    else
        echo -e "  ${YELLOW}Skipping clone${NC}"
    fi
fi
echo ""

# ----- Step 5: Install Syncthing -----
echo -e "${YELLOW}[5/6] Setting up Syncthing...${NC}"
if command -v syncthing &>/dev/null; then
    echo -e "${GREEN}  ✅ Syncthing already installed$(syncthing --version 2>/dev/null | head -1)${NC}"
else
    read -rp "  Install Syncthing? (y/n): " DO_SYNCTHING
    if [[ "$DO_SYNCTHING" =~ ^[Yy]$ ]]; then
        sudo apt install -y syncthing
        systemctl --user enable syncthing.service
        systemctl --user start syncthing.service
        echo -e "${GREEN}  ✅ Syncthing installed and running${NC}"
        echo -e "  ${BLUE}   Web GUI: http://127.0.0.1:8384${NC}"
    fi
fi

# Create shared folders
mkdir -p "$CODING_DIR/shared-assets"
mkdir -p "$CODING_DIR/scratch-pad"
mkdir -p "$CODING_DIR/agent-outputs"
echo -e "${GREEN}  ✅ Shared folders created in ${CODING_DIR}/${NC}"
echo ""

# ----- Step 6: Install LocalSend -----
echo -e "${YELLOW}[6/6] LocalSend for quick file/message sharing...${NC}"
if command -v localsend &>/dev/null || flatpak list 2>/dev/null | grep -q localsend; then
    echo -e "${GREEN}  ✅ LocalSend already installed${NC}"
else
    read -rp "  Install LocalSend via Flatpak? (y/n): " DO_LOCALSEND
    if [[ "$DO_LOCALSEND" =~ ^[Yy]$ ]]; then
        if ! command -v flatpak &>/dev/null; then
            sudo apt install -y flatpak
            flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        fi
        flatpak install -y flathub org.localsend.localsend_app
        echo -e "${GREEN}  ✅ LocalSend installed${NC}"
    fi
fi
echo ""

# ----- Summary -----
echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Setup Complete!                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}📡 Your IP: ${LOCAL_IP}${NC}"
echo -e "  ${GREEN}📁 Coding dir: ${CODING_DIR}${NC}"
echo ""
echo -e "  ${YELLOW}👉 NEXT STEPS:${NC}"
echo -e "  1. On your Windows machine, update ~/.ssh/config:"
echo -e "     Change '192.168.1.XXX' to '${LOCAL_IP}'"
echo -e "     Change 'YOUR_UBUNTU_USERNAME' to '$(whoami)'"
echo ""
echo -e "  2. Accept the collaborator invite for operation-Trismegistus:"
echo -e "     https://github.com/notifications"
echo ""
echo -e "  3. Open Syncthing Web GUI (http://127.0.0.1:8384)"
echo -e "     and pair with your Windows device"
echo ""
echo -e "  4. Open LocalSend — it should auto-discover your Windows machine"
echo ""
