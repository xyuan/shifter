#!/bin/sh

##################
## Setup NERSC chroot for docker,chos images
##  Validates user selected chroot image
##  Bind mounts image to $nerscRootPath
##  Bind mounts needed filesystems into the image
##
## Authors:  Douglas Jacobsen, Shane Canon
## 2015/02/27
##################

export PATH="/usr/bin:/bin"
export LD_LIBRARY_PATH=""
export LD_PRELOAD=""

## read configuration
CONFIG_FILE=/global/syscom/sc/nsg/etc/nerscRoot.conf
if [ -e $CONFIG_FILE ]; then
    . $CONFIG_FILE
fi

## parse command line arguments
NERSC_ROOT_TYPE=$1
NERSC_ROOT_VALUE=$2
shift 2
VOLUMES=""
while getopts ":v:" opt; do
    case $opt in
        v)
            if [ -z $VOLUMES ]; then
                VOLUMES=$OPTARG
            else
                VOLUMES="$VOLUMES|$OPTARG"
            fi
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument" >&2
            exit 1
            ;;
    esac
done

#### TODO CHECK CONFIGURATION SETTINGS ####
#nerscMount=/var/nerscMount
#chosPath=/scratch/chos
#dockerPath=/scratch/scratchdirs/craydock/docker
#nerscRootPath=/global/syscom/sc/nsg/opt/nerscRoot
#mapPath=$nerscRootPath/fsMap.conf
#etcDir=$nerscRootPath/etc
#kmodDir=$nerscRootPath/kmod/$( uname -r )
#kmodCache=/tmp/nerscRootLoadedModules.txt
#globalFs="u1 u2 project syscom common scratch2" 
#lustreFs="scratch"

targetType=""
target=""

die () {
    echo $1
    exit 1
}

stripLeadingSlash() {
    local string
    string=$1
    while [ "x${string:0:1}" == "x/" ]; do
        string=${string:1}
    done
    echo $string
}

containsItem () {
    local tgt
    tgt=$1
    shift
    [[ $# -eq 0 ]] && return 1
    while true; do
        [[ $1 == $tgt ]] && return 0
        [[ $# -eq 0 ]] && break
        shift
    done
    return 1
}

containsItemStartsWith() {
    local tgt
    tgt=$1
    shift
    echo "tgt: $tgt"
    [[ $# -eq 0 ]] && return 1
    while true; do
        [[ $# -eq 0 ]] && break
        if [ -z $1 ]; then
            shift
            continue
        fi
        case $tgt in
            "$1"*) return 0 ;;
        esac
        shift
    done
    return 1
}

setupNerscVFSRoot () {
    local fs
    local dir
    local item
    local imageDir
    local volMap
    local src
    local dest
    local option
    local ok
    local REGIFS
    imageDir=$1

    ## create tmpfs/rootfs for our /
    ## this is to ensure there are writeable areas for manipulating the image
    mount -o nosuid,nodev -t rootfs none $nerscMount
    cd $nerscMount

    ## setup NERSC GPFS filesystems
    mkdir global
    for fs in $globalFs; do 
        mkdir global/$fs
        mount -o bind /global/$fs global/$fs
        mount -o bind,remount,nosuid,nodev $nerscMount/global/$fs
    done
    cd global
    ln -s u1 homes
    cd $nerscMount

    ## setup lustre mounts
    for fs in $lustreFs; do
        mkdir $fs
        mount -o bind /$fs $fs
        mount -o bind,remount,nodev,nosuid $nerscMount/$fs ### XXX lustre is weird about remounts
    done

    ## make some aspects of the local environment available
    mkdir -p local/etc
    mount -o bind /dsl/etc local/etc
    mount -o bind,remount,nodev,nosuid $nerscMount/local/etc
    mkdir -p .shared
    mount -o bind /dsl/.shared .shared

    ## reserve some directories in "/" that will be handled explicitly
    mkdir -p etc/nerscImage
    mkdir -p etc/site
    mkdir -p proc
    mkdir -p sys
    mkdir -p dev
    mkdir -p tmp
    mount -o bind /tmp tmp
    
    # mount the image into the new mount
    for dir in `ls $imageDir`; do
        # don't do anything to "reserved" paths
        if [ -e $dir ]; then
            continue
        fi
        # properly copy symlinks
        if [ -L $imageDir/$dir ]; then
            cp -P $imageDir/$dir $dir
            continue
        fi
        # copy files
        if [ -f $imageDir/$dir ]; then
            cp -p $imageDir/$dir $dir
            continue
        fi
        # bind mount directories
        if [ -d $imageDir/$dir ]; then
            mkdir $dir
            mount --bind $imageDir/$dir $nerscMount/$dir
            mount -o bind,remount,nodev,nosuid $nerscMount/$dir
        fi
    done

    ## merge image etc, site customizations, and local customizations into /etc
    if [ -e $imageDir/etc ]; then
        mount -o bind $imageDir/etc etc/nerscImage
        mount -o bind,remount,nodev,nosuid $nerscMount/etc/nerscImage
        cd etc
        for item in `ls nerscImage`; do
            ln -s nerscImage/$item .
        done
        for item in `ls $etcDir`; do
            cp -p $etcDir/$item $nerscMount/etc/site
            if [ -e $item ]; then
                rm $item
            fi
            ln -s site/$item $item
        done
        ## take care of passwd
        if [ -e passwd ]; then
            rm passwd
        fi
        ln -s site/nersc_passwd passwd
        if [ -e group ]; then
            rm group
        fi
        ln -s site/nersc_group group
    fi

    ## mount up linux needs
    mount -t proc none $nerscMount/proc
    mount -o bind /dev $nerscMount/dev
    mount -o bind /sys $nerscMount/sys

    ## perform any user-requested bind-mounts
    ##    any leading slashes are stripped to force the bind mount to *only*
    ##    occur within the chroot area
    cd $nerscMount
    REGIFS=$IFS
    IFS="|"
    for volMap in $VOLUMES; do
        IFS=":"
        set x $volMap
        src=$(stripLeadingSlash $2)
        dest=$(stripLeadingSlash $3)
        option=NONE
        shift 3
        if [ ! -z $1 ]; then
            option=$1
            shift
        fi
        IFS=$REGIFS
        if [ -e "$src" -a -e "$dest" ]; then
            mount -o bind "$src" "$dest"
            if [ "x$option" == "xro" ]; then
                mount -o bind,remount,ro "$dest"
#ok=0
#                containsItemStartsWith "$src" $lustreFs
#                ok=$?
#                if [ $ok -eq 0 ]; then
#                    echo "Fail: cannot mark lustre filesystems read-only"
#                else
#                fi
            fi
        fi
        IFS="|"
    done
    IFS=$REGIFS
}

## loadKernelModule - ensure specified kernel module is loaded
##   checks to see if kernel module is loaded.  if it isn't the module is loaded
##   and logged to the kmodCache for later removal
##
##   returns 0 if module is loaded
##   returns 1 if module failed to load
loadKernelModule() {
    local kmodName
    local kmodPath
    local loadModule
    kmodName=$1
    kmodPath=$2
    loadModule=0
    /sbin/lsmod | egrep "^$kmodName$" || loadModule=1
    if [ $loadModule -eq 1 -a -e $kmodPath ]; then
        /sbin/insmod $kmodPath || return 1
        echo $kmodName >> $kmodCache
    fi
    return 0
}

setupLoopbackMount() {
    local imageFile
    local kmodPath
    local fstype
    imageFile=$1
    kmodPath=$2
    fstype=$3

    [[ -n $loopMount ]] || die "Unknown location for loopMount"

    loadKernelModule "loop"    $kmodPath/drivers/block/loop.ko
    loadKernelModule "mbcache" $kmodPath/fs/mbcache.ko
    loadKernelModule "jbd2"    $kmodPath/fs/jbd2/jbd2.ko
    loadKernelModule "ext4"    $kmodPath/fs/ext4/ext4.ko
    loadKernelModule "cramfs"  $kmodPath/fs/cramfs/cramfs.ko

    mkdir -p $loopMount || die "Failed to create mount point $loopMount"
    mount -t $fstype -o loop,ro,nodev,nosuid $imageFile $loopMount || die "Failed to mount image file $imageFile"
    setupNerscVFSRoot $loopMount
}


if [ "x$CHOS" != "x" ]; then
    targetType="chos"
    target=$CHOS
fi

if [ "x$DOCKER" != "x" ]; then
    targetType="docker"
    target=$DOCKER
fi

if [ "x$NERSC_ROOT_TYPE" == "xCHOS" ]; then
    targetType="chos"
fi
if [ "x$NERSC_ROOT_TYPE" == "xDOCKER" ]; then
    targetType="docker"
fi
if [ "x$NERSC_ROOT_VALUE" != "x" ]; then
    target=$NERSC_ROOT_VALUE
fi

containsItem $targetType "chos" "docker" || die "Invalid image target type: $targetType"

## since $target is user provided, need to sanitize
target=${target//[^a-zA-Z0-9_:\.]/}

linePrefix="$targetType;$target;"
if [ "x$targetType" == "xdocker" ]; then
    imageType="ext4Image"
    image="$target.ext4"
else
    line=$( egrep "^$linePrefix" $mapPath ) || die "Cannot find $targetType image \"$target\". Failed."
    image=$( echo $line | awk -F ';' '{print $3}' ) || die "Cannot identify path for $targetType image \"$target\". Failed."
    imageType=$( echo $line | awk -F ';' '{print $4}' ) || die "Cannot identify imageType for $targetType image \"$target\". Failed."
fi

containsItem $imageType "vfs" "ext4Image" "cramfsImage" || die "Invalid imageType for $targetType image \"$target\". Failed."

## get base path for this target type
pathVar="${targetType}Path"
eval basePath=\$$pathVar
[[ "x$basePath" != "x" ]] || die "Invalid base path for $targetType"
[[ "x$basePath" != "x/" ]] || die "Base path cannot be /"

## get final path to image
fullPath="${basePath}/${image}"
[[ -e $fullPath ]] || die "Path to $targetType image \"$target\" does not exist: $fullPath"

## start doing bind mounts
mkdir -p $nerscMount
if [ "x$imageType" == "xvfs" ]; then
    setupNerscVFSRoot $fullPath
elif [ "x$imageType" == "xext4Image" ]; then
    setupLoopbackMount $fullPath $kmodDir "ext4"
elif [ "x$imageType" == "xcramfsImage" ]; then
    setupLoopbackMount $fullPath $kmodDir "cramfs"
else
    exit 1
fi
