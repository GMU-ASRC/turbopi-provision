#!/bin/bash

source ./common.sh
# source ./inet_aton.sh
parse_common_args "$@"

_HOSTNAME_CHANGED=1  # 1/false until changed
_ASRC_DEFAULT_HOSTNAMES=(
    "turbopi-00"
    "raspberrypi"
)
_ASRC_set_name_ip_args_parsed=1
ROBOT_NAME_PREFIX=${ROBOT_NAME_PREFIX:-'turbopi-'}
GATEWAY=${GATEWAY:-'192.168.0.1'}
NAMESERVER=${NAMESERVER:-$GATEWAY}
CIDR=${CIDR:-'20'}
BASEIP=${BASEIP:-'192.168.9.'}
BASEN=${BASEN:-'100'}
MAX_ROBOT_SUFFIX=154

parse_setname_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --skip_non_default)
                _ASRC_PROMPT_DEFAULT_NAME=0
                shift
                ;;
            --prefix)
                shift
                ROBOT_NAME_PREFIX="$1"
                shift
                ;;
            --prefix=*)
                ROBOT_NAME_PREFIX="${1#*=}"
                shift
                ;;
            --connection)
                shift
                CONNECTION="$1"
                shift
                ;;
            --connection=*)
                CONNECTION="${1#*=}"
                shift
                ;;
            --gateway)
                shift
                GATEWAY="$1"
                shift
                ;;
            --gateway=*)
                GATEWAY="${1#*=}"
                shift
                ;;
            --nameserver)
                shift
                NAMESERVER="$1"
                shift
                ;;
            --nameserver=*)
                NAMESERVER="${1#*=}"
                shift
                ;;
            --cidr)
                shift
                CIDR="$1"
                shift
                ;;
            --cidr=*)
                CIDR="${1#*=}"
                shift
                ;;
            --base-ip)
                shift
                BASEIP="$1"
                shift
                ;;
            --base-ip=*)
                BASEIP="${1#*=}"
                shift
                ;;
            --base-n)
                shift
                BASEN="$1"
                shift
                ;;
            --base-n=*)
                BASEN="${1#*=}"
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
    _ASRC_set_name_ip_args_parsed=0
}


if [ "$_ASRC_set_name_ip_args_parsed" -ne "0" ]; then
    _remaining_args_temp=("${_ASRC_remaining_args[@]}")
    _ASRC_remaining_args=()
    parse_setname_args "${_remaining_args_temp[@]}"
fi


set_persistent_hostname() {
    echo "Changing hostname from $(hostname) to $1"
    # set hostname
    echo "$1" | do_sudo tee /etc/hostname
    _HOSTNAME_CHANGED=0
}

is_default_hostname() {
    local current="$(cat /etc/hostname)"
    for default_hostname in "${_ASRC_DEFAULT_HOSTNAMES}"; do
        if [[ "$current" == "$default_hostname" ]]; then
            return 0
        fi
    done
    return 1
}

# https://whiptail.readthedocs.io/en/latest/docs.html
# https://mywiki.wooledge.org/BashFAQ/050
# https://en.wikibooks.org/wiki/Bash_Shell_Scripting/Whiptail

whiptail_choose_connection() {
    # local connections=()
    # mapfile -t connections <<< $(nmcli -g NAME connection show)
    local conn_status=()
    mapfile -t conn_status <<< $(nmcli -g NAME,TYPE,STATE connection show | tr : ' ')

    local name
    local type
    local state
    local shorttype

    local options=()
    local whiptail_desc
    for line in "${conn_status[@]}"; do
        read -r name type state <<< "$line"
        if [ "$type" == "loopback" ]; then
            continue
        fi
        shorttype="$(echo $type | sed -r 's/802-[[:digit:]]{1,2}-//')"  # remove 802-11-, 802-3-
        # echo "$name ($shorttype): $state"
        options+=( "$name" )
        whiptail_desc="$shorttype"
        if [ -n "$state" ]; then
            whiptail_desc+=" ($state)"
        fi
        options+=( "$whiptail_desc" )
    done
    _ASRC_CONNECTION=$(whiptail --menu --nocancel \
"Choose a connection to modify the IP address of" 30 60 10 "${options[@]}" 3>&1 1>&2 2>&3)
    echo "$_ASRC_CONNECTION"
}

whiptail_input_suffix() {
    local
    while true; do
        suffix=$(whiptail --inputbox "Enter the number of the robot (0-$MAX_ROBOT_SUFFIX)" 8 30 3>&1 1>&2 2>&3)
        if [ "$?" -ne "0" ]; then
            return 1
        fi
        suffix=$(strip_lead_zeros "$suffix")
        if [ "$?" -ne "0" ]; then
            (whiptail --msgbox "Please enter a valid suffix number." 8 50 3>&1 1>&2 2>&3)
            continue
        elif [ "$suffixi" -lt "0" -o "$suffixi" -gt "$MAX_ROBOT_SUFFIX" ]; then
            (whiptail --msgbox "Suffix must be between 0 and $MAX_ROBOT_SUFFIX." 8 50 3>&1 1>&2 2>&3)
            continue
        fi
        break
    done
    echo "$suffix"
}

strip_lead_zeros() {
    local suffixi
    declare -i suffixi
    if [ -z "$1" ]; then
        echo "No suffix number entered" >&2
        return 1
    fi
    # https://stackoverflow.com/questions/11123717/removing-leading-zeros-before-passing-a-shell-variable-to-another-command
    suffixi=$((10#$1))
    echo "$suffixi"
}

format_robot_name_from_number() {
    echo $ROBOT_NAME_PREFIX$(printf "%02d" $1)
}

calculate_new_ip_from_suffix() {
    local ip_last="$(($BASEN + $1))"
    NEW_IP_FULL="$BASEIP""$ip_last"/"$CIDR"
}

do_rename_robot() {
    local suffix="$1"
    local new_name="$(format_robot_name_from_number $suffix)"
    if [ -z "$CONNECTION" ]; then
        CONNECTION=$(whiptail_choose_connection)
    fi
    if [ -z "$CONNECTION" ]; then
        echo "No connection selected"
        return 1
    fi
    set_persistent_hostname "$new_name"
    echo "Setting IP address for $CONNECTION"
    if [ -z "$NEW_IP_FULL" ]; then
        calculate_new_ip_from_suffix $suffix
    fi
    echo "New IP: $NEW_IP_FULL"
    # check if ip already there
    # local addresses="$(nmcli -g ipv4.addresses connection show netplan-eth0)"
    # local ip_already_set=1
    # (IFS=', '; for existing_ip in "${addresses}"; do
    #     echo $existing_ip
    #     ip_already_set=([ "$new_ip_full" -eq "$existing_ip" ]) && break
    # done)
    # if ! [[ "$ip_already_set" -eq '0' ]]; then
    #     (IFS=,; addresses+=$new_ip_full)
    #     nmcli connection modify "$CONNECTION" ipv4.addresses $addresses
    # fi
    do_sudo nmcli connection modify "$CONNECTION" ipv4.addresses "$NEW_IP_FULL"
    do_sudo nmcli connection modify "$CONNECTION" ipv4.gateway "$GATEWAY"
    do_sudo nmcli connection modify "$CONNECTION" ipv4.dns "$NAMESERVER"
    do_sudo nmcli connection modify "$CONNECTION" ipv4.method manual
    do_sudo nmcli connection up "$CONNECTION"
    echo "Done"
}


whiptail_menu() {
    local phostname="$(cat /etc/hostname)"
    if [ "$phostname" != "$(hostname)" ]; then
        local afterreboot=' (takes effect after reboot)'
    fi
    whiptail --yesno "\
Would you like to rename the suffix of this robot?\n\
Current persistent hostname: $phostname$afterreboot\n\
" 8 60
    return $?
}

whiptail_confirm_correct() {
    local new_name="$(format_robot_name_from_number $suffix)"
    if [ -z "$NEW_IP_FULL" ]; then
        calculate_new_ip_from_suffix $suffix
    fi
    whiptail --yesno --yes-button "Confirm and Change" --no-button "Retry" "\
Please confirm these details are correct:\n\n\
New persistent hostname: $new_name\n\n\
Connection to Modify: $CONNECTION\n\
Method: manual\n\
IP: $NEW_IP_FULL\n\
Gateway: $GATEWAY\n\
DNS Nameserver: $NAMESERVER\n\
" 20 60
    return $?
}

whiptail_reboot_reminder() {
    local phostname="$(cat /etc/hostname)"
    if [ "$phostname" != "$(hostname)" ]; then
        local afterreboot=' (takes effect after reboot)'
    fi
    whiptail --msgbox "\
Changes have been made.\n\
A reboot may be required for some of these changes to take effect.\n\n\
Don't forget to write down the new hostname for when you re-connect with SSH!\n\n\
Persistent hostname: $phostname$afterreboot\n\
Connection Name: $CONNECTION\n\
Method: $(nmcli -g ipv4.method connection show "$CONNECTION")\n\
IP: $(nmcli -g ipv4.addresses connection show "$CONNECTION")\n\
Gateway: $(nmcli -g ipv4.gateway connection show "$CONNECTION")\n\
DNS Nameserver: $(nmcli -g ipv4.dns connection show "$CONNECTION")\n\
" 20 60
}

whiptail_menu() {
    local phostname="$(cat /etc/hostname)"
    if [ "$phostname" != "$(hostname)" ]; then
        local afterreboot=' (takes effect after reboot)'
    fi
    whiptail --yesno "\
Would you like to rename the suffix of this robot?\n\
Current persistent hostname: $phostname$afterreboot\n\
" 20 60
    return $?
}

interactive_rename() {
    echo "Prompting for new suffix"
    local suffix

    suffix="$(whiptail_input_suffix)"
    if [ "$?" -ne "0" ]; then
        return 1
    fi
    if [ -z "$CONNECTION" ]; then
        local connection_was_empty=0
        CONNECTION="$(whiptail_choose_connection)"
    fi
    calculate_new_ip_from_suffix $suffix
    whiptail_confirm_correct
    if [ "$?" -ne "0" ]; then
        if [ "$connection_was_empty" -eq "0" ]; then CONNECTION=''; fi
        interactive_rename
        return $?
    fi
    # do_rename_robot $suffix
    whiptail_reboot_reminder
    echo
}

main() {
    if [ "${_ASRC_PROMPT_DEFAULT_NAME}" = "0" ] && ! is_default_hostname ; then
        echo "Current static/persistent hostname does not match any default hostnames."
        echo "Assuming no change needed. Please cd to your setup scripts dir and run"
        echo "bash ./set_name_ip.sh"
        echo "if you would like to change it later."
        return 0
    fi
    whiptail_menu
    if [ $? -eq "0" ]; then
        interactive_rename
    fi
}


if [ ! "${_ASRC_nomain}" = "0" ]; then
    main
fi