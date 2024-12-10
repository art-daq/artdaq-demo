#! /bin/bash
# quick-mrb-start.sh - Eric Flumerfelt, May 20, 2016
# Downloads, installs, and runs the artdaq_demo as an MRB-controlled repository

git_status=`git status 2>/dev/null`
git_sts=$?
if [ $git_sts -eq 0 ];then
    echo "This script is designed to be run in a fresh install directory!"
    exit 1
fi

starttime=`date`
Base=$PWD
test -d qms-log || mkdir qms-log

env_opts_var=`basename $0 | sed 's/\.sh$//' | tr 'a-z-' 'A-Z_'`_OPTS
USAGE="\
   usage: `basename $0` [options] [demo_root]
examples: `basename $0` .
          `basename $0` -s 132
If the \"demo_root\" optional parameter is not supplied, the user will be
prompted for this location.
--spackdir    Install Spack in this directory (or use existing installation)
-s            Use specific qualifiers when building ARTDAQ
-v            Be more verbose
-x            set -x this script
--upstream    Use <dir> as a Spack upstream (repeatable)
--no-view     Do not create Spack environment views
--padding     Pad paths to 255 characters for relocatability
--arch        Architecture for build (e.g. linux-almalinux9-x86_64_v3)
"

# Process script arguments and options
eval env_opts=\${$env_opts_var-} # can be args too
spackdir="${ARTDAQDEMO_SPACK_DIR:-$Base/spack}"
arch=""
upstreams=()
installStatus=0
eval "set -- $env_opts \"\$@\""
op1chr='rest=`expr "$op" : "[^-]\(.*\)"`   && set -- "-$rest" "$@"'
op1arg='rest=`expr "$op" : "[^-]\(.*\)"`   && set --  "$rest" "$@"'
reqarg="$op1arg;"'test -z "${1+1}" &&echo opt -$op requires arg. &&echo "$USAGE" &&exit'
args= do_help= opt_v=0; opt_w=0; opt_develop=0; opt_padding=0; opt_pcp=0; opt_no_kmod=0; opt_no_view=0
while [ -n "${1-}" ];do
    if expr "x${1-}" : 'x-' >/dev/null;then
        op=`expr "x$1" : 'x-\(.*\)'`; shift   # done with $1
        leq=`expr "x$op" : 'x-[^=]*\(=\)'` lev=`expr "x$op" : 'x-[^=]*=\(.*\)'`
        test -n "$leq"&&eval "set -- \"\$lev\" \"\$@\""&&op=`expr "x$op" : 'x\([^=]*\)'`
        case "$op" in
            \?*|h*)     eval $op1chr; do_help=1;;
            v*)         eval $op1chr; opt_v=`expr $opt_v + 1`;;
            x*)         eval $op1chr; set -x;;
            s*)         eval $op1arg; squalifier=$1; shift;;
            w*)         eval $op1chr; opt_w=`expr $opt_w + 1`;;
            -spackdir)  eval $op1arg; spackdir=$1; shift;;
            -arch)      eval $op1arg; arch=$1; shift;;
            -upstream)  eval $op1arg; upstreams+=($1); shift;;
            -padding)   opt_padding=1;;
            -no-view)   opt_no_view=1;;
            *)          echo "Unknown option -$op"; do_help=1;;
        esac
    else
        aa=`echo "$1" | sed -e"s/'/'\"'\"'/g"` args="$args '$aa'"; shift
    fi
done
eval "set -- $args \"\$@\""; unset args aa

test -n "${do_help-}" -o $# -ge 2 && echo "$USAGE" && exit


# JCF, 1/16/15
# Save all output from this script (stdout + stderr) in a file with a
# name that looks like "quick-start.sh_Fri_Jan_16_13:58:27.script" as
# well as all stderr in a file with a name that looks like
# "quick-start.sh_Fri_Jan_16_13:58:27_stderr.script"
alloutput_file=$( date | awk -v "SCRIPTNAME=$(basename $0)" '{print SCRIPTNAME"_"$1"_"$2"_"$3"_"$4".script"}' )
stderr_file=$( date | awk -v "SCRIPTNAME=$(basename $0)" '{print SCRIPTNAME"_"$1"_"$2"_"$3"_"$4"_stderr.script"}' )
exec  > >(tee "$Base/qms-log/$alloutput_file")
exec 2> >(tee "$Base/qms-log/$stderr_file")


defaultS="s132"

if [ -n "${squalifier-}" ]; then
    squalifier="${squalifier}"
else
    squalifier="${defaultS#s}"
fi

arch_opt=""
if [ "x$arch" != "x" ]; then
   arch_opt="arch=$arch"
fi

view_opt=""
if [ $opt_no_view -eq 1 ];then
    view_opt="--without-view"
fi

if ! [ -d $spackdir ];then
    $(
    cd ${spackdir%/spack}
    git clone https://github.com/FNALssi/spack.git -b fnal-develop
        )
else
    cd $spackdir && git pull && cd $Base
fi

cat >setup-env.sh <<-EOF
export SPACK_DISABLE_LOCAL_CONFIG=true
source $spackdir/share/spack/setup-env.sh
EOF
source setup-env.sh

if ! [ -d fermi-spack-tools ]; then
    git clone https://github.com/FNALssi/fermi-spack-tools.git
else
    cd fermi-spack-tools && git pull && cd ..
fi

if ! [ -d spack-mpd ]; then
    git clone https://github.com/FNALssi/spack-mpd.git
else
    cd spack-mpd && git pull && cd ..
fi

sed -i '/perl/d' fermi-spack-tools/templates/packagelist
if [ -f $spackdir/etc/spack/`uname -s | tr [A-Z] [a-z]`/almalinux9/packages.yaml ];then
    echo "Skipping ./fermi-spack-tools/bin/make_packages_yaml $spackdir almalinux9"
    echo "... $spackdir/etc/spack/`uname -s | tr [A-Z] [a-z]`/almalinux9/packages.yaml already exists"
else
    echo "executing ./fermi-spack-tools/bin/make_packages_yaml $spackdir almalinux9"
    echo "... to produce $spackdir/etc/spack/`uname -s | tr [A-Z] [a-z]`/almalinux9/packages.yaml"
    ./fermi-spack-tools/bin/make_packages_yaml $spackdir almalinux9
fi

repo_found=`spack repo list|grep -c fnal_art`
if [ $repo_found -eq 0 ]; then
    echo "Adding repos: fnal_art scd_recipes artdaq-spack"
    mkdir spack-repos && cd spack-repos
    git clone https://github.com/FNALssi/fnal_art.git
    spack repo add ./fnal_art
    git clone https://github.com/marcmengel/scd_recipes.git
    spack repo add ./scd_recipes
    git clone https://github.com/art-daq/artdaq-spack.git
    spack repo add ./artdaq-spack
    cd $Base
else
    echo "Repo's previously added -- pull any updates"
    for dir in `spack repo list|awk '{print $2}'`;do
        cd $dir
        git pull
    done
    cd $Base
fi


#spack config --scope=site update  --yes-to-all config
#spack config --scope=site add config:flags:keep_werror:all # Not needed when using spack-mpd
spack config --scope=site add "config:extensions:- $Base/spack-mpd"

if [ $opt_padding -eq 1 ];then
  spack config --scope=site add config:install_tree:padded_length:255
fi

#spack mirror add --scope site scisoft-binaries  https://scisoft.fnal.gov/scisoft/spack-mirror/spack-binary-cache-plain
#spack buildcache update-index -k scisoft-binaries
#spack mirror add --scope site scisoft-compilers https://scisoft.fnal.gov/scisoft/spack-mirror/spack-compiler-cache-plain
#spack buildcache update-index -k scisoft-compilers
#spack -k buildcache keys --install --trust --force
#spack reindex

for upstream in ${upstreams[@]}; do
    for upstreamdir in `find $upstream -type f -wholename */.spack-db/index.json 2>/dev/null`; do
    
        upstreamdir=`dirname $upstreamdir`
        upstreamdir=`dirname $upstreamdir`
        upstreamname=`echo $upstreamdir|sed 's|/__spack[^/]*||g;s|/spack/opt/spack||g'`
    
        if ! [ -d $upstreamdir/.spack-db ]; then
            echo "No Spack instance found at $upstream!"
            continue
        fi

        if ! [ -f $spackdir/etc/spack/upstreams.yaml ]; then
            echo "upstreams:" > $spackdir/etc/spack/upstreams.yaml
        fi
    
        if [ `grep -c $upstreamdir $spackdir/etc/spack/upstreams.yaml` -eq 0 ]; then
            # Only add upstream if not already present
            echo "  upstream${upstreamname//\//-}:" >>$spackdir/etc/spack/upstreams.yaml
            echo "    install_tree: $upstreamdir" >>$spackdir/etc/spack/upstreams.yaml
        fi
    done

done

spack reindex

cd $Base

BUILD_J=$((`cat /proc/cpuinfo|grep processor|tail -1|awk '{print $3}'` + 1))
spack load --first gcc@13.1.0 >/dev/null 2>&1
if [ $? -ne 0 ];then
  spack install -j $BUILD_J gcc@13.1.0 $arch_opt +binutils
  installStatus=$?
  spack load gcc@13.1.0
fi
spack compiler find

spack env create ${view_opt} art-s${squalifier}
spack env activate art-s${squalifier}

ln -s ${spackdir}/var/spack/environments/art-s${squalifier}

spack add art-suite@s${squalifier} +root $arch_opt %gcc@13.1.0
env_to_activate="art-s${squalifier}"

spack concretize --force && spack install -j $BUILD_J
installStatus=$?

endtime=`date`

echo "Build start time: $starttime"
echo "Build end time:   $endtime"

exit $installStatus
