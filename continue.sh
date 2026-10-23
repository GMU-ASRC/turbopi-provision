source ./common.sh

if [ $(hostname) ~= "raspberrypi|turbopi\s*$|turbopi-000?\s*$" ]; then
    source ./set_hostname.sh
fi

if remote_branch_exists asrc; then
    _ASRC_HOME_BRANCH=asrc
fi
source ./install_asrc.sh
