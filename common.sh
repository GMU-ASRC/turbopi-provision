#!/bin/bash

# functions used by other scripts

# referenced zoxide install script while writing this:
# https://github.com/ajeetdsouza/zoxide/blob/main/install.sh
# especially for:
# parse_args, try_sudo, need_sudo, need_cmd, check_cmd, ensure, assert_nz, err


main() {
    parse_args "$@"

    need_sudo

    need_cmd git

}

_ASRC_remaining_args=()

_ASRC_DEFAULT_SUDO="sudo"
_ASRC_DEFAULT_PUSER="pi"
_ASRC_nomain=''

# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
parse_common_args() {

    _ASRC_SUDO="${_ASRC_DEFAULT_SUDO}"
    _ASRC_DIR_DOWNLOAD="${_ASRC_DEFAULT_DIR_DOWNLOAD}"

    _ASRC_PUSER="${_ASRC_DEFAULT_PUSER}"

    while [ $# -gt 0 ]; do
        case "$1" in
            --sudo)
                shift
                _ASRC_SUDO="$1"
                shift
                ;;
            --sudo=*)
                _ASRC_SUDO="${1#*=}"
                shift
                ;;
            --user)
                shift
                _ASRC_PUSER="$1"
                shift
                ;;
            --user=*)
                _ASRC_PUSER="${1#*=}"
                shift
                ;;
            --nomain)
                _ASRC_nomain=0
                shift
                ;;
            --pip)
                shift
                _ASRC_pip="$1"
                shift
                ;;
            --pip=*)
                _ASRC_pip="${1#*=}"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                # err "unknown argument: $1"
                _ASRC_remaining_args+=("$1")
                shift
                ;;
        esac
    done
}

check_no_remaining_args() {
    if [ ${#_ASRC_remaining_args[@]} -gt 0 ]; then
        err "unrecognized arguments: ${_ASRC_remaining_args[*]}"
    fi
}


try_sudo() {
    if "$@" >/dev/null 2>&1; then
        return 0
    fi

    need_sudo
    "${_ASRC_SUDO}" "$@"
}

do_sudo() {
    need_sudo
    "${_ASRC_SUDO}" "$@"
}

need_sudo() {
    if ! check_cmd "${_ASRC_SUDO}"; then
        err "\
could not find the command \`${_ASRC_SUDO}\` needed to get permissions for install.
"
    fi

    if ! "${_ASRC_SUDO}" -v; then
        err "sudo permissions not granted, aborting installation"
    fi
}

has_uv() {
    return $(check_cmd uv)
}

do_pip() {
    if [ -z "${_ASRC_pip}" ]; then
        if has_uv; then
            uv pip "$@"
        else
            pip "$@"
        fi
    else
        "${_ASRC_pip}" "$@"
    fi
}

ensure_virtualenv_available() {
    if (python3 -m virtualenv &> /dev/null); then
        return 0
    elif has_uv; then
        uv tool install virtualenv
    else
        do_pip install virtualenv
    fi
}

do_venv() {
    if has_uv; then
        uv venv "$@"
    else
        ensure_virtualenv_available
        python3 -m virtualenv "$@"
    fi
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
