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
_ASRC_PROMPT_DEFAULT_NAME=1
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
            --try-auto-set)
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
    for default_hostname in "${_ASRC_DEFAULT_HOSTNAMES[@]}"; do
        if [[ "$current" == "$default_hostname" ]]; then
            return 0
        fi
    done
    return 1
}

_filter_connection_types() {
    # split input args on '--' https://unix.stackexchange.com/a/807690
    local connections=()
    local keywords=()
    local addto=keywords
    for arg in "$@"; do
        if [[ $arg == -- && $addto == keywords ]]; then
            addto=connections
        else
            if [[ $addto == keywords ]]; then
                keywords+=( "$arg" )
            else
                local sepcount=$(grep -o ":" <<< "$arg" | wc -l)
                if [[ $sepcount -gt 3 ]]; then
                    err "Bash didn't read your input arguments correctly. Please make sure your connections coming after the -- do not have quotes."
                fi
                connections+=( "$arg" )
            fi
        fi
    done
    # if '--' not seen, use $CONNECTION9S
    if [[ $addto == keywords ]]; then
        connections=("${CONNECTIONS[@]}")
    fi
    # rebuild array, excluding/including lines whose connection type matches
    local filtered=()
    local name type state
    for line in "${connections[@]}"; do
        IFS=: read -r name type state <<< "$line"
        local match=1
        for keyword in "${keywords[@]}"; do
            if [ "$type" == "$keyword" ]; then
                match=0
                break
            fi
        done
        # _ASRC_FILTER_CONNECTION_MODE is 1 for exclude, 0 for include
        if [ "$match" -eq "$_ASRC_FILTER_CONNECTION_MODE" ]; then
            filtered+=($line)
        fi
    done
    echo "${filtered[@]}"
}

exclude_connection_types() {
    # examples (note the double quotes or lack thereof):
    # exclude_connection_types loopback 802-3-ethernet -- "${connection_array[@]}"
    # exclude_connection_types loopback -- $(read_connections)
    _ASRC_FILTER_CONNECTION_MODE=1
    _filter_connection_types "$@"
}

include_connection_types() {
    _ASRC_FILTER_CONNECTION_MODE='0'
    _filter_connection_types "$@"
}

simplify_connection_types() {
    local connections=()
    # if '--' not seen, use $CONNECTION9S
    if [[ $# -eq 0 ]]; then
        connections=("${CONNECTIONS[@]}")
    else
        connections=("$@")
    fi
    # rebuild array, excluding lines whose connection type matches
    local simplified=()
    local name type state
    for line in "${connections[@]}"; do
        IFS=: read -r name type state <<< "$line"
        type="$(echo $type | sed -r 's/802-[[:digit:]]{1,2}-//')"  # remove 802-11-, 802-3-
        simplified+=($name:$type:$state)
    done
    echo "${simplified[@]}"
}

read_connections() {
    mapfile -t CONNECTIONS <<< $(nmcli -g NAME,TYPE,STATE connection show)
    echo "${CONNECTIONS[@]}"
}

try_get_single_wifi_connection() {
    local conns=$(include_connection_types wireless -- $(simplify_connection_types $(read_connections)))
    if [ ${#conns[@]} -eq 1 ]; then
        IFS=: read -r name type state <<< "$conns"
        echo $name
    else
        return 1
    fi
}

# https://whiptail.readthedocs.io/en/latest/docs.html
# https://mywiki.wooledge.org/BashFAQ/050
# https://en.wikibooks.org/wiki/Bash_Shell_Scripting/Whiptail

whiptail_choose_connection() {
    local name type state
    local conns=$(exclude_connection_types loopback -- $(simplify_connection_types $(read_connections)))
    local options=()
    local whiptail_desc
    for line in ${conns[@]}; do
        IFS=: read -r name type state <<< "$line"
        options+=( "$name" )
        if [ -n "$state" ]; then type+=" ($state)"; fi
        options+=( "$type" )
    done
    _ASRC_CONNECTION=$(whiptail --menu --nocancel \
"Choose a connection to modify the IP address of" 12 60 4 "${options[@]}" 3>&1 1>&2 2>&3)
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
        elif [ "$suffix" -lt "0" -o "$suffix" -gt "$MAX_ROBOT_SUFFIX" ]; then
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

infer_suffix_from_hostname() {
    if [ -z "$1" ]; then
        CURRENT_HOSTNAME="$(cat /etc/hostname)"
    else
        CURRENT_HOSTNAME="$1"
    fi
    repattern="$ROBOT_NAME_PREFIX([0-9]{1,3})$"
    [[ $CURRENT_HOSTNAME =~ $repattern ]]
    local retval=$?  # should be 1 if no match
    local suffix="${BASH_REMATCH[1]}"
    assert_nz "$suffix"  # should be non-empty, see $repattern
    suffix=$(strip_lead_zeros "$suffix")
    if [ "$retval" -eq 0 ]; then echo "$suffix"; fi  # return suffix if matched
    if [ "$suffix" -lt "0" -o "$suffix" -gt "$MAX_ROBOT_SUFFIX" ]; then
        return 2  # matched, but out of range
    fi
    return "$retval"  # 0 if match & valid, 1 if no match, 2 if match but invalid/out-of-range
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
    echo "Applying the following settings to connection $CONNECTION:"
    echo "IP ADDR: $NEW_IP_FULL (will be set as static)"
    echo "Gateway: $GATEWAY"
    echo "DNS srv: $NAMESERVER"
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
    # do_sudo nmcli connection up "$CONNECTION"
    echo "Done."
    echo
    echo "\
Some changes might only take effect after reboot.\n\
Make sure to use the new hostname when re-connecting!\n\
Hostname >>> $phostname$afterreboot <<<\n\
Connection: $CONNECTION\n\
IP ($mode): $(nmcli -g ipv4.addresses connection show "$CONNECTION")\n\
Gateway: $(nmcli -g ipv4.gateway connection show "$CONNECTION") \
Nameserver: $(nmcli -g ipv4.dns connection show "$CONNECTION")\n\
"
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
New persistent hostname: $new_name\n\
Connection to Modify: $CONNECTION\n\
IP: $NEW_IP_FULL\n\
Gateway: $GATEWAY  DNS Nameserver: $NAMESERVER\n\
" 12 60
    return $?
}

whiptail_reboot_reminder() {
    local phostname="$(cat /etc/hostname)"
    if [ "$phostname" != "$(hostname)" ]; then
        local afterreboot=' (takes effect after reboot)'
    fi
    local mode=$(nmcli -g ipv4.method connection show "$CONNECTION")
    whiptail --msgbox "\
Some changes might only take effect after reboot.\n\
Make sure to use the new hostname when re-connecting!\n\
Hostname >>> $phostname$afterreboot <<<\n\
Connection: $CONNECTION\n\
IP ($mode): $(nmcli -g ipv4.addresses connection show "$CONNECTION")\n\
Gateway: $(nmcli -g ipv4.gateway connection show "$CONNECTION") \
Nameserver: $(nmcli -g ipv4.dns connection show "$CONNECTION")\n\
" 12 60
}

whiptail_menu() {
    echo Entering interactive prompt
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
    do_rename_robot $suffix
    whiptail_reboot_reminder
    echo
}

main() {
    local hostname=$(cat /etc/hostname)
    echo "Checking if hostname $hostname is default or of parsable format..."
    if [ "${_ASRC_PROMPT_DEFAULT_NAME}" -eq "0" ] && ! is_default_hostname ; then
        echo "Current static/persistent hostname does not match any default hostnames."
        echo "Checking if there's a single wifi connection to modify..."
        local wifi_conn=$(try_get_single_wifi_connection)
        CONNECTION=${CONNECTION:-$wifi_conn}
        if [ -z "$CONNECTION" ]; then
            echo Could not determine a connection to modify, skipping.
            return 0
        fi
        local addresses="$(nmcli -g ipv4.addresses connection show "$CONNECTION")"
        local state=$(nmcli -g GENERAL.state connection show $CONNECTION)
        if [ -n "$addresses" ]; then
            echo "Connection $CONNECTION already has addresses set: <$addresses>"
            echo "Assuming no change needed. Please cd to your setup scripts dir and run"
            echo "bash ./set_name_ip.sh"
            echo "if you would like to change it later."
        # elif [[ $state =~ activ ]]; then
        #     echo "Connection $CONNECTION is active."
        #     echo "Refusing to modify active connection. Please cd to your setup scripts dir and run"
        #     echo "bash ./set_name_ip.sh"
        #     echo "if you would like to change it later."
        else
            local suffix=$(infer_suffix_from_hostname)
            local status=$?
            if [ $status -eq 0 ]; then
                echo "Inferring robot number is $suffix from hostname $hostname."
                do_rename_robot $suffix
            else
                echo "Hostname $hostname doesn't seem to match the format we expected."
                echo "Only hostnames starting with $ROBOT_NAME_PREFIX and ending"
                echo "with a number between 0 and $MAX_ROBOT_SUFFIX are eligible for static IP assignment during setup."
                echo "No changes were made to the networking."
            fi
        fi
        return 0
    else
        if [ "${_ASRC_PROMPT_DEFAULT_NAME}" -eq "1" ]; then
            echo "Hostname looks like a default value."
        fi
        echo "Let's give this robot a number."
        echo "Then, we'll change the hostname and set a static IP."
        whiptail_menu
        if [ $? -eq "0" ]; then
            interactive_rename
        fi
    fi
}


if [ ! "${_ASRC_nomain}" = "0" ]; then
    main
fi