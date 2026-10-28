#!/bin/bash
source ./common.sh
assert_not_root
parse_common_args "$@"

ASRC_HOME_BRANCH="${ASRC_HOME_BRANCH:-main}"

parse_install_asrc_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --home-branch)
                shift
                ASRC_HOME_BRANCH="$1"
                shift
                ;;
            --home-branch=*)
                ASRC_HOME_BRANCH="${1#*=}"
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
    _ASRC_install_asrc_args_parsed=0
}


_remaining_args_temp=("${_ASRC_remaining_args[@]}")
_ASRC_remaining_args=()
parse_install_asrc_args "${_remaining_args_temp[@]}"


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
    assert_nz "${ASRC_HOME_BRANCH}"
    git config --global pull.ff only
    git init -b "${ASRC_HOME_BRANCH}"
    git remote add origin https://github.com/GMU-ASRC/turbopi-root.git
    git fetch
    git reset origin/"${ASRC_HOME_BRANCH}" --hard
    git branch -u origin/"${ASRC_HOME_BRANCH}" "${ASRC_HOME_BRANCH}"
    git switch "${ASRC_HOME_BRANCH}" --force
    git pull

    git submodule update --init --recursive
}

install_asrc_module() {
    cd $HOME
    do_pip install -e turboswarmlib
}

if [ ! "${_ASRC_nomain}" = "0" ]; then
    main
fi
