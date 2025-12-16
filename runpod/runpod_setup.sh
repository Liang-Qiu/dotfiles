#!/bin/bash

# Get script directory before any cd commands
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1) Setup linux dependencies
su -c 'apt-get update && apt-get install -y sudo'
sudo apt-get install -y less nano vim htop ncdu nvtop lsof rsync btop jq

# 2) Setup virtual environment
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env
uv python install 3.11
uv venv
source .venv/bin/activate
uv pip install ipykernel simple-gpu-scheduler # very useful on runpod with multi-GPUs https://pypi.org/project/simple-gpu-scheduler/
python -m ipykernel install --user --name=venv # so it shows up in jupyter notebooks within vscode
deactivate # Deactivate venv so user can activate their own environment

# 3) Setup github
"${SCRIPT_DIR}/setup_github.sh" "liangqiu@outlook.com" "Liang-Qiu"

# 4) Install Claude Code for root
echo "=== Installing Claude Code for root ==="
if [ -x ~/.local/bin/claude ] || [ -d ~/.local/share/claude ]; then
    echo "Claude Code is already installed for root, skipping..."
else
    curl -fsSL https://claude.ai/install.sh | bash
fi

# 5) Setup ubuntu-cmd user with Claude Code
"${SCRIPT_DIR}/setup-ubuntu-cmd.sh"

# 6) Setup dotfiles and ZSH (last because deploy.sh starts interactive zsh)
# Note: cred.sh is sourced from config/zshrc.sh directly
cd /workspace
git clone https://github.com/Liang-Qiu/dotfiles.git
cd dotfiles
./install.sh --zsh --tmux
chsh -s /usr/bin/zsh
./deploy.sh
