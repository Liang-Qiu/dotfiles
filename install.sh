#!/bin/bash
set -euo pipefail
USAGE=$(cat <<-END
    Usage: ./install.sh [OPTION]
    Install dotfile dependencies on mac or linux

    OPTIONS:
        --tmux       install tmux
        --zsh        install zsh
        --extras     install extra dependencies

    If OPTIONS are passed they will be installed
    with apt if on linux or brew if on OSX
END
)

zsh=false
tmux=false
extras=false
force=false
while (( "$#" )); do
    case "$1" in
        -h|--help)
            echo "$USAGE" && exit 1 ;;
        --zsh)
            zsh=true && shift ;;
        --tmux)
            tmux=true && shift ;;
        --extras)
            extras=true && shift ;;
        --force)
            force=true && shift ;;
        --) # end argument parsing
            shift && break ;;
        -*|--*=) # unsupported flags
            echo "Error: Unsupported flag $1" >&2 && exit 1 ;;
    esac
done

operating_system="$(uname -s)"
case "${operating_system}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    *)          machine="UNKNOWN:${operating_system}"
                echo "Error: Unsupported operating system ${operating_system}" && exit 1
esac

# Installing on linux with apt
if [ $machine == "Linux" ]; then
    DOT_DIR=$(dirname $(realpath $0))
    sudo apt-get update -y
    [ $zsh == true ] && sudo apt-get install -y zsh
    [ $tmux == true ] && sudo apt-get install -y tmux
    sudo apt-get install -y less nano htop ncdu nvtop lsof rsync jq
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Install Claude Code if not already installed
    if [ -x ~/.local/bin/claude ] || [ -d ~/.local/share/claude ]; then
        echo "Claude Code is already installed, skipping..."
    else
        curl -fsSL https://claude.ai/install.sh | bash
    fi

    if [ $extras == true ]; then
        sudo apt-get install -y ripgrep

        yes | curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | /bin/bash
        yes | brew install dust jless

        yes | curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        . "$HOME/.cargo/env" 
        yes | cargo install code2prompt
        yes | brew install peco

        sudo apt-get install -y npm
        yes | npm i -g shell-ask
    fi

# Installing on mac with homebrew
elif [ $machine == "Mac" ]; then
    brew install coreutils ncdu htop ncdu rsync btop jq || true  # Mac won't have realpath before coreutils installed
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Install Claude Code if not already installed
    if [ -x ~/.local/bin/claude ] || [ -d ~/.local/share/claude ]; then
        echo "Claude Code is already installed, skipping..."
    else
        curl -fsSL https://claude.ai/install.sh | bash
    fi

    if [ $extras == true ]; then
        brew install ripgrep dust jless || true

        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        . "$HOME/.cargo/env"
        cargo install code2prompt || true
        brew install peco || true
    fi

    DOT_DIR=$(dirname $(realpath $0))
    [ $zsh == true ] && brew install zsh || true
    [ $tmux == true ] && brew install tmux || true
    # macOS system preferences removed - user preference
    # defaults write -g InitialKeyRepeat -int 10 # normal minimum is 15 (225 ms)
    # defaults write -g KeyRepeat -int 1 # normal minimum is 2 (30 ms)
    # defaults write -g com.apple.mouse.scaling 5.0
    # defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
fi

# Setting up oh my zsh and plugins to SHARED system location
# This allows multiple users to share the same installation
ZSH_SHARED=/usr/local/share/oh-my-zsh
ZSH_CUSTOM_SHARED=$ZSH_SHARED/custom
TMUX_THEMEPACK_SHARED=/usr/local/share/tmux-themepack

if [ -d $ZSH_SHARED ] && [ "$force" = "false" ]; then
    echo "Skipping download of oh-my-zsh and related plugins, pass --force to force redownload"
else
    echo " --------- INSTALLING DEPENDENCIES ⏳ ----------- "
    sudo rm -rf $ZSH_SHARED

    # Install oh-my-zsh to shared location
    sudo mkdir -p $ZSH_SHARED
    sudo git clone https://github.com/ohmyzsh/ohmyzsh.git $ZSH_SHARED
    sudo mkdir -p $ZSH_CUSTOM_SHARED/themes $ZSH_CUSTOM_SHARED/plugins

    sudo git clone https://github.com/romkatv/powerlevel10k.git \
        $ZSH_CUSTOM_SHARED/themes/powerlevel10k

    sudo git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
        $ZSH_CUSTOM_SHARED/plugins/zsh-syntax-highlighting

    sudo git clone https://github.com/zsh-users/zsh-autosuggestions \
        $ZSH_CUSTOM_SHARED/plugins/zsh-autosuggestions

    sudo git clone https://github.com/zsh-users/zsh-completions \
        $ZSH_CUSTOM_SHARED/plugins/zsh-completions

    sudo git clone https://github.com/zsh-users/zsh-history-substring-search \
        $ZSH_CUSTOM_SHARED/plugins/zsh-history-substring-search

    # Install tmux-themepack to shared location
    sudo rm -rf $TMUX_THEMEPACK_SHARED
    sudo git clone https://github.com/jimeh/tmux-themepack.git $TMUX_THEMEPACK_SHARED

    # Make shared directories readable by all users
    sudo chmod -R a+rX $ZSH_SHARED
    sudo chmod -R a+rX $TMUX_THEMEPACK_SHARED

    echo " --------- INSTALLED SUCCESSFULLY ✅ ----------- "
    echo " --------- NOW RUN ./deploy.sh [OPTION] -------- "
fi

if [ $extras == true ]; then
    echo " --------- INSTALLING EXTRAS ⏳ ----------- "
    if command -v cargo &> /dev/null; then
        NO_ASK_OPENAI_API_KEY=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/hmirin/ask.sh/main/install.sh)"
    fi
fi
