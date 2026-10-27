source ./common.sh

source ./set_name_ip.sh --skip_non_default

if remote_branch_exists asrc; then
    _ASRC_HOME_BRANCH=asrc
fi
source ./install_asrc.sh
