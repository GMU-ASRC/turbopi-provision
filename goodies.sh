#!/bin/bash

if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi

set -e  # exit on error

# TODO: make everything into a function
# TODO: use config for user and paths

source ./common.sh

parse_common_args "$@"

_ASRC_APT_UPDATED=1

parse_goodies_args() {
    U=${U:-"$USER"}
    H=${H:-"/home/$U"}
    BASHRC=${BASHRC:-"$(realpath $H/.bashrc)"}

    while [ $# -gt 0 ]; do
        case "$1" in
            --user)
                shift
                U="$1"
                shift
                ;;
            --user=*)
                U="${1#*=}"
                shift
                ;;
            --home)
                shift
                H="$1"
                shift
                ;;
            --home=*)
                H="${1#*=}"
                shift
                ;;
            --bashrc)
                shift
                BASHRC="(realpath $1)"
                shift
                ;;
            --bashrc=*)
                BASHRC="${1#*=}"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                _ASRC_remaining_args+=("$1")
                shift
                ;;
        esac
    done

    echo .bashrc: $BASHRC

    sudo chown :$U $BASHRC
    sudo chmod 775 $BASHRC

}


main() {

    local _remaining_args_temp=_ASRC_remaining_args
    _ASRC_remaining_args=()
    parse_goodies_args _remaining_args_temp

    echo "Installing goodies"
    install_fish
    echo
    install_apt_stuff
    echo $PATH
    echo
    install_vimrc
    echo
    install_zoxide
    echo
    install_fzf
    echo
    login_activate_venv
    echo
    goodies_aliases
    echo
    echo "--------------------------"
    echo "done installing goodies!!!"
    echo "--------------------------"
}


function update_bashrc {
    append_line "$BASHRC" "$1" "$2"
}

function removefrom_bashrc {
    remove_lines "$BASHRC" "$1"
}

echo


# FISH FISH FISH FISH FISH FISH FISH FISH FISH
# https://software.opensuse.org/download.html?project=shells%3Afish%3Arelease%3A4&package=fish
install_fish() {
    if ! command -v fish &> /dev/null; then
        echo fish not found. installing fish.
        if [ -d "/etc/apt/sources.list.d/shells:fish:release:4.list" ]; then
            echo "/etc/apt/sources.list.d/shells:fish:release:4.list already exists"
        else
            echo 'deb http://download.opensuse.org/repositories/shells:/fish:/release:/4/Debian_13/ /' \
            | sudo tee /etc/apt/sources.list.d/shells:fish:release:4.list
            curl -fsSL https://download.opensuse.org/repositories/shells:fish:release:4/Debian_13/Release.key \
            | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/shells_fish_release_4.gpg > /dev/null
        fi
        sudo apt update
        _ASRC_APT_UPDATED=0
        sudo apt install fish -y
    fi
}


install_apt_stuff() {
    echo installing ncdu, bat, aptitude, vim, gparted, eza
    sudo apt install ncdu bat aptitude vim gparted eza -y
}


install_vimrc() {
    if [ ! -d "/opt/vim_runtime" ]; then
        echo Installing vimrc
        sudo git clone --depth=1 https://github.com/amix/vimrc.git /opt/vim_runtime
        # to install for all users with home directories, note that root will not be included
        sudo bash /opt/vim_runtime/install_awesome_parameterized.sh /opt/vim_runtime --all
        sudo bash /opt/vim_runtime/install_awesome_parameterized.sh /opt/vim_runtime root
    else
        echo "/opt/vim_runtime already exists. Skipping install of vimrc."
    fi
}


install_zoxide() {
    ensure_localbin
    if ! command -v zoxide &> /dev/null ; then
        echo "Installing zoxide"
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    fi
    echo "updating bashrc with zoxide init"
    update_bashrc "export PATH=\"\$HOME/.local/bin:\$PATH\""  || true
    update_bashrc "eval \"\$(zoxide init bash --cmd cd)\""  || true
    if [ ! -f "$H/.config/fish/conf.d/020-zoxide.fish" ]; then
        echo "zoxide init fish --cmd cd | source" > "$H/.config/fish/conf.d/020-zoxide.fish"
    fi
}

install_fzf() {
    if [ ! -d "$H/.fzf" ]; then
        echo "Installing fzf"
        git clone --depth 1 https://github.com/junegunn/fzf.git $H/.fzf
        $H/.fzf/install --all
    else
        echo Skipping fzf as $H/.fzf already exists
    fi
    if [ ! -f "$H/.config/fish/conf.d/021-fzf.fish" ]; then
        echo "fzf --fish | source" > "$H/.config/fish/conf.d/021-fzf.fish"
    fi
}

login_activate_venv() {
    echo "modifying bashrc to source venv on login"
    update_bashrc "if [ -d \"$H/.venv\" ]; then source \"$H/.venv/bin/activate\" ; fi" || true
    if [ ! -f "$H/.config/fish/conf.d/050-pivenv.fish" ]; then
        echo "adding fish config for venv activation on login"
        echo "source $H/.venv/bin/activate.fish" > "$H/.config/fish/conf.d/050-pivenv.fish"
    fi
}



goodies_aliases() {
    # remove old aliases
    # removefrom_bashrc "eval \"\$(zoxide init bash)\""
    # removefrom_bashrc "alias cd=z"

    # echo adding alias to bat
    # update_bashrc "alias bat='batcat'" || true

    echo Adding ls/eza aliases to .bashrc
    set +e
    update_bashrc "if command -v eza &> /dev/null ; then alias ls='eza' ; else alias ls='ls --color --classify --human-readable' ; fi"
    update_bashrc "alias la='ls -Ah'"
    update_bashrc "alias ll='ls -laF'"
    update_bashrc "alias lls='ls -lah --sort=size'"
    update_bashrc "alias llt='ls -lah --sort=time'"

    fish -c "alias --save ls 'eza --classify'"
    fish -c "alias --save lls 'ls -lah --sort=size'"
    fish -c "alias --save llt 'ls -lah --sort=time'"

    fish -c "fish_add_path $H/.local/bin"

    if [ ! -d "$H/.local/share/omf" ]; then
        echo "Installing oh-my-fish"
        curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install \
        | fish -C "set -gx NONINTERACTIVE 1"  # avoid trap at end of install script
    else
        echo "oh-my-fish already installed"
    fi
    fish -c "omf install https://github.com/kenblu24/fishbun.git"
    set -x
    fish -c "set -U default_user $U"
    fish -c "set -U fish_prompt_pwd_full_dirs 3"
    fish -c "set -U fish_prompt_pwd_dir_length 4"
    fish -c "set -U VIRTUAL_ENV_DISABLE_PROMPT 1"
    # add fish aliases provided by turbopy services i.e. stop, batt
    if [ -f /turbopy/core/scripts/add_fish_aliases.sh ]; then
        sudo -s source /turbopy/core/scripts/add_fish_aliases.sh $U
    fi
    set +x
    # set fish as default shell
    if grep -qF -- "/usr/bin/fish" /etc/shells ; then
        do_sudo chsh -s /usr/bin/fish
        echo "fish shell set as default shell"
    fi
}

# sudo apt install dnsmasq -y
# sudo systemctl disable dnsmasq
# sudo systemctl stop dnsmasq

# great! now a bunch of stuff is installed by default.
# other stuff you may wish to do:
# Install rust:
# curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

if [ ! "${_ASRC_nomain}" = "0" ]; then
    main
fi
