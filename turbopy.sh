#!/bin/bash

if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi

source ./common.sh
parse_common_args "$@"

sudo_nopasswd() {
    assert_nz "${_ASRC_PUSER}" "_ASRC_PUSER"
    if [ ! -f /etc/sudoers.d/020_"${_ASRC_PUSER}" ]; then
        ensure try_sudo echo "${_ASRC_PUSER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/020_"${_ASRC_PUSER}"
    fi
}

main() {
    sudo_nopasswd
    try_sudo apt update

    set -e  # exit on error

    # this didn't work but i didn't try it fully:
    # https://www.reddit.com/r/debian/comments/166cuem/help_easy_vnc_steps/

    # CONFIGURE VNC AND I2C
    # (
    # INTERACTIVE=False
    # source /usr/bin/raspi-config
    # do_vnc 0  # enable
    # )
    # oh wait we can actually just add nonint lol
    # https://loganmarchione.com/2021/07/raspi-configs-mostly-undocumented-non-interactive-mode/
    # of course i find this after figuring out how to do it a different way
    echo Enabling VNC
    try_sudo raspi-config nonint do_vnc 0  # enable wayvnc
    echo Enabling I2C
    try_sudo raspi-config nonint do_i2c 0  # enable i2c
    # sudo apt install tigervnc-standalone-server

    install_uv
    double_deactivate
    uninstall_buttonman
    remove_turbopy
    install_turbopy
    install_buttonman
}


# chsh -s /usr/bin/fish

install_uv() {
    echo Installing uv
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.local/bin/env
}

double_deactivate() {
    # deactivate any virtual environments
    echo Deactivating virtual environments
    if command -v deactivate &> /dev/null; then deactivate ; fi
    if command -v deactivate &> /dev/null; then deactivate ; fi
}

uninstall_buttonman() {
    if [ -f /turbopy/core/scripts/uninstall_buttonman.sh ]; then
    echo Uninstalling buttonman \& TurboPi core services
    try_sudo bash /turbopy/core/scripts/uninstall_buttonman.sh
    fi
}

remove_turbopy() {
    echo Removing /turbopy/\*\*
    try_sudo rm -rf /turbopy
}

install_turbopy() {
    # sudo rm -rf /home/pi/.venv
    # uv tool install swig
    echo Creating user virtual environment in /home/"${_ASRC_PUSER}"/.venv
    do_venv /home/"${_ASRC_PUSER}"/.venv --prompt "${_ASRC_PUSER}" --clear --system-site-packages

    echo Creating /turbopy
    try_sudo mkdir -p /turbopy
    try_sudo chown :"${_ASRC_PUSER}" /turbopy
    try_sudo chmod 775 /turbopy
    echo Creating CORE virtual environment in /turbopy/.venv
    do_venv /turbopy/.venv --prompt CORE --clear --system-site-packages

    echo Cloning turbopi-driver to /turbopy/rasadapter
    git clone https://github.com/GMU-ASRC/turbopi-driver.git /turbopy/rasadapter
    echo Cloning turbopi-coreservices to /turbopy/core
    git clone https://github.com/GMU-ASRC/turbopi-coreservices.git /turbopy/core

    echo Activating CORE virtual environment
    source /turbopy/.venv/bin/activate
    echo Installing turbopi-driver and turbopi-coreservices
    do_pip install -e /turbopy/rasadapter
    do_pip install -e /turbopy/core
    echo Deactivating CORE virtual environment
    deactivate

    echo Activating user virtual environment
    source /home/pi/.venv/bin/activate
    echo Installing turbopi-driver and turbopi-coreservices
    do_pip install -e /turbopy/rasadapter
    do_pip install -e /turbopy/core
}

install_buttonman() {
    echo Installing buttonman \& TurboPi core services
    do_sudo bash /turbopy/core/scripts/install_buttonman.sh
}

# TODO: custom environment marker perhaps using pi symbol for default env

if [ ! "${_ASRC_nomain}" -eq 0 ]; then
    check_no_remaining_args
    main "$@"
fi
