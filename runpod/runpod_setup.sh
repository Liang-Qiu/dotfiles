#!/bin/bash

# Get script directory before any cd commands
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
ubuntu_cmd=false
while (( "$#" )); do
    case "$1" in
        --ubuntu-cmd)
            ubuntu_cmd=true && shift ;;
        -h|--help)
            echo "Usage: $0 [--ubuntu-cmd]"
            echo "  --ubuntu-cmd    Setup ubuntu-cmd user with Claude Code"
            exit 0 ;;
        --) # end argument parsing
            shift && break ;;
        -*|--*=) # unsupported flags
            echo "Error: Unsupported flag $1" >&2 && exit 1 ;;
        *) # preserve positional arguments
            shift ;;
    esac
done

# 1) Setup linux dependencies
su -c 'apt-get update && apt-get install -y sudo'
sudo apt-get install -y less vim htop ncdu nvtop lsof rsync btop jq

# 2) Setup virtual environment
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env
uv python install 3.12
uv venv
source .venv/bin/activate
uv pip install ipykernel simple-gpu-scheduler # very useful on runpod with multi-GPUs https://pypi.org/project/simple-gpu-scheduler/
python -m ipykernel install --user --name=venv # so it shows up in jupyter notebooks within vscode

# 3) Setup github
if [ -f "${SCRIPT_DIR}/setup_github.sh" ]; then
    "${SCRIPT_DIR}/setup_github.sh" "liangqiu@outlook.com" "Liang-Qiu"
else
    echo "Warning: setup_github.sh not found in ${SCRIPT_DIR}, skipping GitHub setup"
    echo "Make sure setup_github.sh is in the same directory as runpod_setup.sh"
fi

# 4) Install Claude Code for root
echo "=== Installing Claude Code for root ==="
if [ -x ~/.local/bin/claude ] || [ -d ~/.local/share/claude ]; then
    echo "Claude Code is already installed for root, skipping..."
else
    curl -fsSL https://claude.ai/install.sh | bash
fi

# 5) Setup ubuntu-cmd user with Claude Code (only if --ubuntu-cmd flag is set)
if [ "$ubuntu_cmd" == "true" ]; then
    "${SCRIPT_DIR}/setup-ubuntu-cmd.sh"
fi

# 6) Setup dotfiles and ZSH (last because deploy.sh starts interactive zsh)
cd /workspace
git clone https://github.com/Liang-Qiu/dotfiles.git
cd dotfiles
./install.sh
chsh -s /usr/bin/zsh
cd /workspace
./dotfiles/deploy.sh --vim
