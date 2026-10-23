_old_dir="$(pwd)"
cd "$(dirname "$0")"


source ./turbopy.sh
source ./goodies.sh
source_if_exists ./continue.sh


cd "${_old_dir}"