source ./turbopy.sh
source ./goodies.sh
# clear and reset prompt
double_deactivate
activate_user_venv
source_if_exists ./continue.sh

echo "-------------------------"
echo "All done!"
echo

if ! [ "$_ASRC_ALIASES_ALREADY_INSTALLED" = "0" ]; then
    echo "Note: For aliases like 'batt' and 'stop' to work, you may need to"
    echo "restart your shell or re-login to the device."
    echo "Or, you can run:"
    echo "    source ~/.bashrc"

fi