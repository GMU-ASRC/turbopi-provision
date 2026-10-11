#!/bin/bash

if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi

set -e  # exit on error

if [ -f ./config ]; then
    source ./config
fi

H=${H:-'/home/pi'}
BASHRC=${BASHRC:-"$(realpath $H/.bashrc)"}
echo $BASHRC

sudo chown :pi $BASHRC
sudo chmod 775 $BASHRC

function update_bashrc {
    LINE=$1  # arg 1
    eval $LINE  # add to current environment
    grep -qF -- "$LINE" "$BASHRC"
    RES=$?
    if [ $RES -eq 1 ]; then
        echo "$LINE" >> "$BASHRC"
        return 0
    else
        return 1
    fi
}

function removefrom_bashrc {
    LINE=$1
    grep -v "$LINE" $BASHRC > temp && mv temp $BASHRC
    return
}

echo


# FISH FISH FISH FISH FISH FISH FISH FISH FISH
# https://software.opensuse.org/download.html?project=shells%3Afish%3Arelease%3A4&package=fish
if ! command -v fish &> /dev/null; then
    echo fish not found. installing fish.
    if [ -d "/etc/apt/sources.list.d/shells:fish:release:4.list" ]; then
        echo "/etc/apt/sources.list.d/shells:fish:release:4.list already exists"
    else
        echo 'deb http://download.opensuse.org/repositories/shells:/fish:/release:/4/Debian_13/ /' | sudo tee /etc/apt/sources.list.d/shells:fish:release:4.list
        curl -fsSL https://download.opensuse.org/repositories/shells:fish:release:4/Debian_13/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/shells_fish_release_4.gpg > /dev/null
    fi
    sudo apt update
    sudo apt install fish -y
else
    echo running apt update
    sudo apt update
fi


echo
echo installing ncdu, bat, aptitude, vim, gparted
sudo apt install ncdu bat aptitude vim gparted -y

echo $PATH

if [ ! -d "/opt/vim_runtime" ]; then
	echo Installing vimrc
	sudo git clone --depth=1 https://github.com/amix/vimrc.git /opt/vim_runtime
	# to install for all users with home directories, note that root will not be included
	sudo bash /opt/vim_runtime/install_awesome_parameterized.sh /opt/vim_runtime --all
	sudo bash /opt/vim_runtime/install_awesome_parameterized.sh /opt/vim_runtime root
else
	echo "/opt/vim_runtime already exists. Skipping install of vimrc."
fi

# if zoxide is not installed, install it
export PATH="$HOME/.local/bin:$PATH"
if ! command -v zoxide &> /dev/null
then
	echo "Installing zoxide"
	curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
fi
echo "updating bashrc with zoxide init"
update_bashrc "export PATH=\"\$HOME/.local/bin:\$PATH\""  || true
update_bashrc "eval \"\$(zoxide init bash --cmd cd)\""  || true
if [ ! -f "$H/.config/fish/conf.d/020-zoxide.fish" ]; then
	echo "zoxide init fish --cmd cd | source" > "$H/.config/fish/conf.d/020-zoxide.fish"
fi

# if fzf is not installed, install it
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

echo "modifying bashrc to source venv on login"
update_bashrc "if [ -d \"$H/.venv\" ]; then source \"$H/.venv/bin/activate\" ; fi"
if [ ! -f "$H/.config/fish/conf.d/050-pivenv.fish" ]; then
    echo "adding fish config for venv activation on login"
	echo "source $H/.venv/bin/activate.fish" > "$H/.config/fish/conf.d/050-pivenv.fish"
fi


# remove old aliases
# removefrom_bashrc "eval \"\$(zoxide init bash)\""
# removefrom_bashrc "alias cd=z"

# echo adding alias to bat
# update_bashrc "alias bat='batcat'" || true

echo Installing eza
sudo apt install eza -y

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

curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish
fish -c "omf install https://github.com/kenblu24/fishbun.git"
fish -c "set -U default_user $U"
fish -c "set -U fish_prompt_pwd_full_dirs 3"
fish -c "set -U fish_prompt_pwd_dir_length 4"

# sudo apt install dnsmasq -y
# sudo systemctl disable dnsmasq
# sudo systemctl stop dnsmasq

# great! now a bunch of stuff is installed by default.
# other stuff you may wish to do:
# Install rust:
# curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
