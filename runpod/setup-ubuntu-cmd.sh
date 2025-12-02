#!/bin/bash
set -e

# Script to create ubuntu-cmd user, grant /workspace access, install Claude Code, and source credentials

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

# Create .zshrc if it doesn't exist
su - ubuntu-cmd -c '[ -f ~/.zshrc ] || touch ~/.zshrc' 2>/dev/null || true

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

echo "=== Installing Claude Code for ubuntu-cmd ==="
# Check if Claude Code is already installed for ubuntu-cmd
if su - ubuntu-cmd -c '[ -x ~/.local/bin/claude ] || [ -d ~/.local/share/claude ]' 2>/dev/null; then
    echo "Claude Code is already installed for ubuntu-cmd, skipping..."
else
    # Clean up stale lock files that may prevent installation
    su - ubuntu-cmd -c 'rm -f /tmp/claude-install.lock ~/.claude/.installing ~/.local/share/claude/.installing 2>/dev/null' || true
    su - ubuntu-cmd -c 'curl -fsSL https://claude.ai/install.sh | bash'
fi

echo "=== Configuring shell for ubuntu-cmd ==="
# Add ~/.local/bin to PATH
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
# Add to bash configs
su - ubuntu-cmd -c "grep -qxF '$PATH_LINE' ~/.bashrc 2>/dev/null || echo '$PATH_LINE' >> ~/.bashrc"
su - ubuntu-cmd -c "grep -qxF '$PATH_LINE' ~/.bash_profile 2>/dev/null || echo '$PATH_LINE' >> ~/.bash_profile" || true
# Add to zsh configs (both .zshrc for interactive and .zprofile for login shells)
su - ubuntu-cmd -c "grep -qxF '$PATH_LINE' ~/.zshrc 2>/dev/null || echo '$PATH_LINE' >> ~/.zshrc"
su - ubuntu-cmd -c "grep -qxF '$PATH_LINE' ~/.zprofile 2>/dev/null || echo '$PATH_LINE' >> ~/.zprofile"

# Add cred.sh sourcing
CRED_LINE='[ -f /workspace/cred.sh ] && source /workspace/cred.sh'
su - ubuntu-cmd -c "grep -qxF '$CRED_LINE' ~/.bashrc 2>/dev/null || echo '$CRED_LINE' >> ~/.bashrc"
su - ubuntu-cmd -c "grep -qxF '$CRED_LINE' ~/.bash_profile 2>/dev/null || echo '$CRED_LINE' >> ~/.bash_profile" || true
su - ubuntu-cmd -c "grep -qxF '$CRED_LINE' ~/.zshrc 2>/dev/null || echo '$CRED_LINE' >> ~/.zshrc"
su - ubuntu-cmd -c "grep -qxF '$CRED_LINE' ~/.zprofile 2>/dev/null || echo '$CRED_LINE' >> ~/.zprofile"
echo "Added PATH and credential sourcing to ubuntu-cmd's shell configs"

echo "=== Setup complete ==="
echo "Switch to ubuntu-cmd with: su - ubuntu-cmd"
