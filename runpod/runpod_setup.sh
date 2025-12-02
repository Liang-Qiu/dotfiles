#!/bin/bash

# Get script directory before any cd commands
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1) Setup linux dependencies
su -c 'apt-get update && apt-get install -y sudo'
sudo apt-get install -y less nano htop ncdu nvtop lsof rsync btop jq

# 2) Setup virtual environment
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env
uv python install 3.11
uv venv
source .venv/bin/activate
uv pip install ipykernel simple-gpu-scheduler # very useful on runpod with multi-GPUs https://pypi.org/project/simple-gpu-scheduler/
python -m ipykernel install --user --name=venv # so it shows up in jupyter notebooks within vscode

# 3) Setup dotfiles and ZSH
cd /workspace
git clone https://github.com/Liang-Qiu/dotfiles.git
cd dotfiles
./install.sh --zsh --tmux
chsh -s /usr/bin/zsh
./deploy.sh

# 4) Setup github
echo ./scripts/setup_github.sh "liangqiu@outlook.com" "Liang-Qiu"

# 5) Install Claude Code for root
echo "=== Installing Claude Code for root ==="
if [ -x ~/.local/bin/claude ] || [ -d ~/.local/share/claude ]; then
    echo "Claude Code is already installed for root, skipping..."
else
    curl -fsSL https://claude.ai/install.sh | bash
fi

# 6) Setup ubuntu-cmd user with Claude Code
"${SCRIPT_DIR}/setup-ubuntu-cmd.sh"

# 7) Source cred.sh in .zshrc for root and ubuntu-cmd
CRED_LINE='[ -f /workspace/cred.sh ] && source /workspace/cred.sh'
# Root user
if [ -f ~/.zshrc ]; then
    grep -qxF "$CRED_LINE" ~/.zshrc 2>/dev/null || echo "$CRED_LINE" >> ~/.zshrc
fi
# ubuntu-cmd user
if [ -f /home/ubuntu-cmd/.zshrc ]; then
    grep -qxF "$CRED_LINE" /home/ubuntu-cmd/.zshrc 2>/dev/null || echo "$CRED_LINE" >> /home/ubuntu-cmd/.zshrc
fi
