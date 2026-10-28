#!/bin/bash

# functions used by other scripts

# referenced zoxide install script while writing this:
# https://github.com/ajeetdsouza/zoxide/blob/main/install.sh
# especially for:
# parse_args, try_sudo, need_sudo, need_cmd, check_cmd, ensure, assert_nz, err


# TODO: nonint mode
# TODO: set flag if run_all, then do arg checks after

_ASRC_remaining_args=()
_ASRC_common_args_parsed="${_ASRC_common_args_parsed:-''}"

_ASRC_DEFAULT_SUDO="sudo"
_ASRC_DEFAULT_PUSER="pi"
_ASRC_nomain="${_ASRC_nomain:-''}"

# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
parse_common_args() {
    if [ "$_ASRC_common_args_parsed" = "0" ]; then
        return 0
    fi

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
    _ASRC_common_args_parsed="0"
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

    if "${_ASRC_SUDO}" -Nn echo> /dev/null 2>&1; then
        return 0
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

source_if_exists() {
    if [ -f "$1" ]; then
        source "$@"
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

append_line() {
    local FILE=$1  # file path to append to
    local LINE=$2  # line to append
    local PATTERN="$3"  # optional pattern to match lines to remove
    eval $LINE  # add to current environment
    grep -qF -- "$LINE" "$FILE" || return 0
    if [ -n "$PATTERN" ]; then
        remove_lines "$FILE" "$PATTERN"
    fi
    echo "$LINE" >> "$FILE"
}

remove_lines() {
    local FILE=$1  # file path to append to
    local PATTERN=$2  # pattern to match lines to remove
    grep -vF -- "$PATTERN" "$FILE" > _asrc_temp && mv _asrc_temp "$FILE"
}

remote_branch_exists() {
    git ls-remote --exit-code --heads origin "$1" >/dev/null 2>&1
    return $?
}

ensure_localbin() {  # ensures ~/.local/bin exists and is in PATH
    if [ ! -d "$HOME/.local/bin" ]; then
        echo "Creating $HOME/.local/bin"
        mkdir -p "$HOME/.local/bin"
    fi
    if ! echo "$PATH" | grep -qF "$HOME/.local/bin"; then
        echo "Prepending $HOME/.local/bin to PATH"
        export PATH="$HOME/.local/bin:$PATH"
    fi
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

assert_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        err 'This script should not be run by root'
    fi
    return 0
}

err() {
    echo "Error: $1" >&2
    exit 1
}
