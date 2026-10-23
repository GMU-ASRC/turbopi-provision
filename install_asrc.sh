#!/bin/bash

source ./config
assert_not_root
parse_common_args "$@"

_ASRC_HOME_BRANCH="${_ASRC_HOME_BRANCH:-main}"

main() {
    need_cmd git
    need_cmd python
    need_cmd pip

    clean_repos
    install_home_repo
    install_asrc_module
    echo "========================="
    echo "Done installing home repo"
    echo "========================="
}


clean_repos() {
    try_sudo rm -rf $HOME/.git
    try_sudo rm -f $HOME/.gitmodules

    # try_sudo rm -rf $HOME/hiwonder_common
    # try_sudo rm -rf $HOME/caspyan
    # try_sudo rm -rf $HOME/boot
}

install_home_repo() {
    cd $HOME
    assert_nz "${_ASRC_HOME_BRANCH}"
    git config --global pull.ff only
    git init -b "${_ASRC_HOME_BRANCH}"
    git remote add origin https://github.com/GMU-ASRC/turbopi-root.git
    git fetch
    git reset origin/"${_ASRC_HOME_BRANCH}" --hard
    git branch -u origin/"${_ASRC_HOME_BRANCH}" "${_ASRC_HOME_BRANCH}"
    git switch "${_ASRC_HOME_BRANCH}" --force
    git pull

    git submodule update --init --recursive
}

install_asrc_module() {
    cd $HOME
    do_pip install -e asrc
}

if [ ! "${_ASRC_nomain}" = "0" ]; then
    check_no_remaining_args
    main "$@"
fi
