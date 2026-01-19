#!/bin/bash -e

#
# Variables
#
mydir="$(cd $(dirname ${BASH_SOURCE[0]}); pwd)"
# Import constants/variables from conf.sh:
#   DK
#   RK
#   DVK
#   BASE_PATH
#   KCONF_PATHS
source "$mydir/conf.sh"
make_opts=''
merge_opts='-m'

#
# Functions
#
function usage() {
    cat << EO_USAGE
Usage: $(basename $0) [-r] [-P] [MERGE_BRANCH [OVERLAY_VARIANT]]
       $(basename $0) [-r] [-M] [-p KSRC_PATH] [-O OUT_PATH] [MERGE_BRANCH [OVERLAY_VARIANT]]
  Options:
    -r           (Optional) Flag for merging the rt kernel config.
    -M           (Optional) Flag for running 'make olddefconfig' at the end.
    -P           (Optional) Only print the key-value pairs of KCONF_PATHS.
    -p KSRC_PATH (Optional) Specify the kernel source path, default is CWD.
    -O OUT_PATH  (Optional) Specify the dir for the generated output files.
    -h           Print usage messages.
  Parameters:
    MERGE_BRANCH    (Optional) The merge branch of kernel staging repo.
    OVERLAY_VARIANT (Optional) The overlay variant name: deb, rpm, emt.
EO_USAGE
}

function print_kconf_paths() {
    for k in $(printf '%s\n' "${!KCONF_PATHS[@]}" | sort); do
        name="$(echo $k | cut -d, -f3)"
        echo "$name=${KCONF_PATHS[$k]}"
    done
}

#
# Main
#

# parse the arguments
arg_is_rt=1
arg_make_odc=1
# flag for only printing the path infomation
arg_ppo=1
arg_ksrc_path=''
arg_out_path=''
while getopts "rMp:O:Ph" opt; do
    case "$opt" in
      r)
        arg_is_rt=0
        ;;
      M)
        arg_make_odc=0
        ;;
      p)
        arg_ksrc_path="$OPTARG"
        ;;
      O)
        arg_out_path="$OPTARG"
        if [ ! -d "$arg_out_path" ]; then
            echo "ERROR: dir $arg_out_path doesn't exist"
            exit 1
        fi
        # change to the absolute path
        [ "${arg_out_path:0:1}" != '/' ] && arg_out_path="$(cd $arg_out_path; pwd)"
        make_opts="O=$arg_out_path $make_opts"
        merge_opts="-O $arg_out_path $merge_opts"
        ;;
      P)
        arg_ppo=0
        ;;
      h)
        usage
        exit 0
        ;;
      *)
        usage
        exit 1
        ;;
    esac
done
shift $((OPTIND - 1))
# argument mergebranch
arg_mb="${1:-$DK}"
# argument overlay variant
arg_ov="${2:-$DVK}"

if [ $arg_is_rt -eq 0 ]; then
    base="${BASE_PATH[$arg_mb,$arg_ov,$RK]:-${BASE_PATH[$DK,$arg_ov,$RK]}}"
fi
if [ -z "$base" ]; then
    base="${BASE_PATH[$arg_mb,$arg_ov]:-${BASE_PATH[$DK,$arg_ov]}}"
fi
if [ -z "$base" ]; then
    echo "Unrecognized the mergebranch/variant: $1 $2"
    exit 1
fi
if [ $arg_ppo -eq 0 ]; then
    echo "base=$base"
    print_kconf_paths
    exit 0
fi

base_path="$mydir/$base"
kconf_config="${arg_out_path:-.}/.config"
cfglist="$base_path"
echo "Using $base_path as base"

[ -n "$arg_ksrc_path" ] && cd "$arg_ksrc_path"
for k in $(printf '%s\n' "${!KCONF_PATHS[@]}" | sort); do
    path="$mydir/${KCONF_PATHS[$k]}"
    type="$(echo $k | cut -d, -f2)"
    case "$type" in
      dir)
        for cfg in "$path"/*.cfg; do
            if [[ "$cfg" != *rt.cfg || $arg_is_rt -eq 0 ]]; then
                echo "Add $cfg to the merge list"
                cfglist="$cfglist $cfg"
            fi
        done
        ;;
      cfg)
        echo "Add $path to the merge list"
        cfglist="$cfglist $path"
        ;;
      $RK)
        if [ $arg_is_rt -eq 0 ]; then
            echo "Add $path to the merge list"
            cfglist="$cfglist $path"
        fi
        ;;
    esac
done
KCONFIG_CONFIG="$kconf_config" ./scripts/kconfig/merge_config.sh $merge_opts $cfglist
if [ $arg_make_odc -eq 0 ]; then
    make $make_opts olddefconfig
    make $make_opts listnewconfig
fi
