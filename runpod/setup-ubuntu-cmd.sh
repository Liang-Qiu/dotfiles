#!/bin/bash
set -e

# Script to setup ubuntu-cmd user with the same environment as root (minus root privileges)
# Prerequisites: Run install.sh first to install shared oh-my-zsh and plugins to /usr/local/share
# Per-user installs: uv, Claude Code, dotfiles config

# Get script and dotfiles directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Creating user 'ubuntu-cmd' ==="
if id "ubuntu-cmd" &>/dev/null; then
    echo "User 'ubuntu-cmd' already exists"
else
    useradd -m -s /bin/zsh ubuntu-cmd
    echo "User 'ubuntu-cmd' created with zsh"
fi

# Ensure zsh is the default shell
if [ "$(getent passwd ubuntu-cmd | cut -d: -f7)" != "/bin/zsh" ] && [ -x /bin/zsh ]; then
    chsh -s /bin/zsh ubuntu-cmd
    echo "Changed ubuntu-cmd shell to zsh"
fi

echo "=== Granting access to /workspace ==="
# Add ubuntu-cmd to workspace group or use ACLs
if command -v setfacl &>/dev/null; then
    setfacl -R -m u:ubuntu-cmd:rwx /workspace 2>/dev/null || true
    setfacl -R -d -m u:ubuntu-cmd:rwx /workspace 2>/dev/null || true
    echo "ACL permissions granted to ubuntu-cmd on /workspace"
else
    # Fallback: make /workspace group-writable and add user
    chmod -R g+rwx /workspace 2>/dev/null || true
    usermod -aG "$(stat -c '%G' /workspace)" ubuntu-cmd 2>/dev/null || true
    echo "Group permissions granted to ubuntu-cmd on /workspace"
fi

echo "=== Installing uv (Python package manager) for ubuntu-cmd ==="
if su - ubuntu-cmd -c '[ -x ~/.local/bin/uv ]' 2>/dev/null; then
    echo "uv is already installed for ubuntu-cmd, skipping..."
else
    su - ubuntu-cmd -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
fi

echo "=== Installing Claude Code for ubuntu-cmd ==="
if su - ubuntu-cmd -c '[ -x ~/.local/bin/claude ] || [ -d ~/.local/share/claude ]' 2>/dev/null; then
    echo "Claude Code is already installed for ubuntu-cmd, skipping..."
else
    # Clean up stale lock files that may prevent installation
    su - ubuntu-cmd -c 'rm -f /tmp/claude-install.lock ~/.claude/.installing ~/.local/share/claude/.installing 2>/dev/null' || true
    su - ubuntu-cmd -c 'curl -fsSL https://claude.ai/install.sh | bash'
fi

echo "=== Deploying dotfiles for ubuntu-cmd ==="
# Create .zshrc and .tmux.conf that source from the shared dotfiles
# (oh-my-zsh and plugins are already installed system-wide by install.sh)
UBUNTU_CMD_HOME=$(getent passwd ubuntu-cmd | cut -d: -f6)

# Deploy tmux config
echo "source $DOTFILES_DIR/config/tmux.conf" > "$UBUNTU_CMD_HOME/.tmux.conf"
chown ubuntu-cmd:ubuntu-cmd "$UBUNTU_CMD_HOME/.tmux.conf"

# Deploy zshrc (will use shared oh-my-zsh from /usr/local/share)
echo "source $DOTFILES_DIR/config/zshrc.sh" > "$UBUNTU_CMD_HOME/.zshrc"
chown ubuntu-cmd:ubuntu-cmd "$UBUNTU_CMD_HOME/.zshrc"

echo "=== Configuring shell environment for ubuntu-cmd ==="
# Add ~/.local/bin to PATH in .zprofile
# Note: .zprofile is used for login shells and survives .zshrc changes
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

# Bash config (fallback)
su - ubuntu-cmd -c "grep -qxF '$PATH_LINE' ~/.bashrc 2>/dev/null || echo '$PATH_LINE' >> ~/.bashrc"

# Zsh config (.zprofile for login shells)
su - ubuntu-cmd -c "grep -qxF '$PATH_LINE' ~/.zprofile 2>/dev/null || echo '$PATH_LINE' >> ~/.zprofile"
echo "Added PATH to ubuntu-cmd's shell configs"

echo "=== Setup complete ==="
echo "ubuntu-cmd has the same setup as root (shared oh-my-zsh, uv, Claude Code, dotfiles)"
echo "Switch to ubuntu-cmd with: su - ubuntu-cmd"
