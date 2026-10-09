#!/bin/bash

if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi

if [ ! -f /etc/sudoers.d/020_pi ]; then
    sudo cat "pi ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/020_pi
fi
sudo apt update

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
sudo raspi-config nonint do_vnc 0  # enable wayvnc
echo Enabling I2C
sudo raspi-config nonint do_i2c 0  # enable i2c
# sudo apt install tigervnc-standalone-server


# chsh -s /usr/bin/fish

echo Installing uv
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env

# deactivate any virtual environments
echo Deactivating virtual environments
if command -v deactivate &> /dev/null; then deactivate ; fi
if command -v deactivate &> /dev/null; then deactivate ; fi

if [ -f /turbopy/core/scripts/uninstall_buttonman.sh ]; then
   echo Uninstalling buttonman \& TurboPi core services
   sudo bash /turbopy/core/scripts/uninstall_buttonman.sh
fi

# sudo rm -rf /home/pi/.venv
uv tool install swig
echo Creating user virtual environment in /home/pi/.venv
uv venv /home/pi/.venv --prompt pi --clear

echo Removing /turbopy/\*\*
sudo rm -rf /turbopy
echo Creating /turbopy
sudo mkdir -p /turbopy
sudo chown :pi /turbopy
sudo chmod 775 /turbopy
echo Creating CORE virtual environment in /turbopy/.venv
uv venv /turbopy/.venv --prompt CORE --clear

echo Cloning turbopi-driver to /turbopy/rasadapter
git clone https://github.com/GMU-ASRC/turbopi-driver.git /turbopy/rasadapter
echo Cloning turbopi-coreservices to /turbopy/core
git clone https://github.com/GMU-ASRC/turbopi-coreservices.git /turbopy/core

echo Activating CORE virtual environment
source /turbopy/.venv/bin/activate
echo Installing turbopi-driver and turbopi-coreservices
uv pip install -e /turbopy/rasadapter
uv pip install -e /turbopy/core
echo Deactivating CORE virtual environment
deactivate

echo Activating user virtual environment
source /home/pi/.venv/bin/activate
echo Installing turbopi-driver and turbopi-coreservices
uv pip install -e /turbopy/rasadapter
uv pip install -e /turbopy/core

echo Installing buttonman \& TurboPi core services
sudo bash /turbopy/core/scripts/install_buttonman.sh

# TODO: custom environment marker perhaps using pi symbol for default env

