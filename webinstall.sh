#!/bin/bash
# 1-line install script for turbopi-provision
# from https://github.com/GMU-ASRC/turbopi-provision/blob/main/webinstall.sh

# referenced zoxide install script while writing this:
# https://github.com/ajeetdsouza/zoxide/blob/main/install.sh
# especially for:
# parse_args, try_sudo, need_sudo, need_cmd, check_cmd, ensure, assert_nz, err


main() {
    parse_args "$@"

    need_cmd git

    git clone https://github.com/GMU-ASRC/turbopi-provision.git "${_ASRC_DIR_DOWNLOAD}"
    bash "${_ASRC_DIR_DOWNLOAD}/run_all.sh" "${_ASRC_dl_remaining_args[@]}"
}

_ASRC_dl_remaining_args=()

parse_args() {
    _ASRC_DEFAULT_DIR_DOWNLOAD="${HOME}/.setupscripts"

    _ASRC_DIR_DOWNLOAD="${_ASRC_DEFAULT_DIR_DOWNLOAD}"

    while [ $# -gt 0 ]; do
        case "$1" in
            --dl-dir)
                shift
                _ASRC_DIR_DOWNLOAD="$1"
                ;;
            --dl-dir=*)
                _ASRC_DIR_DOWNLOAD="${1#*=}"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                _ASRC_dl_remaining_args+=("$1")
                shift
                # err "unknown argument: $1"
                ;;
        esac
    done
}


need_cmd() {
    if ! check_cmd "$1"; then
        err "need '$1' (command not found)"
    fi
}

check_cmd() {
    command -v -- "$1" >/dev/null 2>&1
}

# Run a command that should never fail. If the command fails execution
# will immediately terminate with an error showing the failing
# command.
ensure() {
    if ! "$@"; then err "command failed: $*"; fi
}

assert_nz() {
    if [ -z "$1" ]; then err "found empty string: $2"; fi
}

err() {
    echo "Error: $1" >&2
    exit 1
}

# This is put in braces to ensure that the script does not run until it is
# downloaded completely.
{
    main "$@" || exit 1
}