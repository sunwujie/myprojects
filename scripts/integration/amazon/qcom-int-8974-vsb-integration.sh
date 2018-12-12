#!/bin/bash

export VSB_PATH=/home/kevin/work/integration/qcom/vsb-8974
export VSB_VERSION=258
export LAST_VSB_VERSION=245
export WORK_ROOT=$PWD
export BRANCH=qcom-int-8974

###
### hardware/amznhals/qcom  vendor/widevine/qcom
###

export VSB_PROJECTS=$(cat <<EOL
external/opencv_arm
device/qcom/common
external/connectivity
external/mm-dash
external/protobuf-c
external/display-postproc
system/bluetooth
system/qcom
kernel/qcom/3.4
bootable/bootloader/lk
device/amazon/apollo
device/amazon/kodiak
device/amazon/thor
device/qcom/msm8974
external/compat-wireless
vendor/nxp/audio/tfa9887
hardware/amazon/audio/external-speaker-amps
external/bluetooth/bluedroid-ath
hardware/qcom_8974/audio
hardware/qcom_8974/bt
hardware/qcom_8974/camera
hardware/qcom_8974/camera-8074
hardware/qcom_8974/display
hardware/qcom_8974/gps
hardware/qcom_8974/keymaster
hardware/qcom_8974/media
hardware/qcom_8974/sensors
hardware/qcom_8974/wlan
vendor/qcom/opensource_8974/bluetooth
vendor/qcom/opensource_8974/fm
vendor/qcom/opensource_8974/kernel-tests
vendor/qcom/opensource_8974/location
vendor/qcom/opensource_8974/stm-log
vendor/qcom/opensource_8974/testframework
vendor/qcom/opensource_8974/time-services
vendor/qcom/opensource_8974/wlan/prima
vendor/qcom/proprietary_8974/QualcommSettings
vendor/qcom/proprietary_8974/aiv-play
vendor/qcom/proprietary_8974/bt/codec
vendor/qcom/proprietary_8974/bt/dun
vendor/qcom/proprietary_8974/bt/hci_qcomm_init
vendor/qcom/proprietary_8974/bt/sap
vendor/qcom/proprietary_8974/cne
vendor/qcom/proprietary_8974/common
vendor/qcom/proprietary_8974/data
vendor/qcom/proprietary_8974/diag
vendor/qcom/proprietary_8974/fastcv
vendor/qcom/proprietary_8974/fm
vendor/qcom/proprietary_8974/ftm
vendor/qcom/proprietary_8974/gps
vendor/qcom/proprietary_8974/graphics-daemons
vendor/qcom/proprietary_8974/grease/utilities
vendor/qcom/proprietary_8974/kernel-tests
vendor/qcom/proprietary_8974/ks
vendor/qcom/proprietary_8974/mdm-helper
vendor/qcom/proprietary_8974/mm-audio
vendor/qcom/proprietary_8974/mm-camera
vendor/qcom/proprietary_8974/mm-camera-8074
vendor/qcom/proprietary_8974/mm-color-conversion
vendor/qcom/proprietary_8974/mm-core
vendor/qcom/proprietary_8974/mm-http
vendor/qcom/proprietary_8974/mm-mux
vendor/qcom/proprietary_8974/mm-osal
vendor/qcom/proprietary_8974/mm-parser
vendor/qcom/proprietary_8974/mm-qsm
vendor/qcom/proprietary_8974/mm-ra
vendor/qcom/proprietary_8974/mm-rtp
vendor/qcom/proprietary_8974/mm-still
vendor/qcom/proprietary_8974/mm-still-8074
vendor/qcom/proprietary_8974/mm-video
vendor/qcom/proprietary_8974/mpdecision
vendor/qcom/proprietary_8974/oem-services
vendor/qcom/proprietary_8974/prebuilt_HY11
vendor/qcom/proprietary_8974/qcNvItems
vendor/qcom/proprietary_8974/qcom-system-daemon
vendor/qcom/proprietary_8974/qcril
vendor/qcom/proprietary_8974/qcrilOemHook
vendor/qcom/proprietary_8974/qmi
vendor/qcom/proprietary_8974/qmi-framework
vendor/qcom/proprietary_8974/remotefs
vendor/qcom/proprietary_8974/rfs_access
vendor/qcom/proprietary_8974/securemsm
vendor/qcom/proprietary_8974/sensors
vendor/qcom/proprietary_8974/ss-restart
vendor/qcom/proprietary_8974/telephony-apps
vendor/qcom/proprietary_8974/thermal-engine
vendor/qcom/proprietary_8974/time-services
vendor/qcom/proprietary_8974/ts_firmware
vendor/qcom/proprietary_8974/ultrasound
vendor/qcom/proprietary_8974/wfd
vendor/qcom/proprietary_8974/wfd-noship
vendor/qcom/proprietary_8974/wlan/ath6kl-utils
vendor/qcom/proprietary_8974/wlan/utils
vendor/qcom/proprietary_8974/xmllib
EOL
)


function init_vsb
{
    pushd $VSB_PATH >/dev/null
    pushd .repo/manifests >/dev/null
    if [ ! -e "manifest-build-$VSB_VERSION.xml" ]; then
        echo "Please copy static manifest 'manifest-build-$VSB_VERSION.xml' to here."
        $SHELL

        if [ ! -e "manifest-build-$VSB_VERSION.xml" ]; then
            echo "Still cannot found the manifest. Abort."
            popd >/dev/null
            popd >/dev/null
            return
        fi
        #manifest_rev=$(grep fireos/manifest manifest-$FROM_BRANCH-$FROM_BUILD_NUMBER.xml | sed 's/.*revision="\(\S*\)".*/\1/')
        #if [ -z "$manifest_rev" ]; then
        #    manifest_rev=$(grep "manifest revision:" manifest-$FROM_BRANCH-$FROM_BUILD_NUMBER.xml | awk '{print $4}')
        #fi
        #git branch -f $FROM_BRANCH-$FROM_BUILD_NUMBER $manifest_rev
    fi
    popd >/dev/null
    
    repo init -m manifest-build-$VSB_VERSION.xml
    repo sync -c -j4
    
    repo forall -c 'git branch -f vsb_$VSB_VERSION'
    repo list > $WORK_ROOT/vsblist_$VSB_VERSION
    
    repo forall -c '
        if [ -n $LAST_VSB_VERSION ];then
            if [ ! "$(git show --pretty=%H -s vsb_$VSB_VERSION)" = "$(git show --pretty=%H -s vsb_$LAST_VSB_VERSION)" ];then
                echo "===== $REPO_PATH ====="
			    git cherry vsb_$LAST_VSB_VERSION vsb_$VSB_VERSION -v
                echo "===== $REPO_PATH ====="
                echo
            fi 
        fi
    ' | tee $WORK_ROOT/delta_changes_from_${LAST_VSB_VERSION}_to_${VSB_VERSION}.list
    
    popd > /dev/null
}


function fetch_vsb
{
    repo forall -c '
        if echo $VSB_PROJECTS | sed "s/ /\n/g" | grep -q "^${REPO_PATH}$" ;then
            if [ $REPO_PATH == "hardware/amazon/audio/external-speaker-amps" ] ; then
                echo $REPO_PATH
                echo "=================================="
                git fetch -n $VSB_PATH/hardware/amazon/audio/external-speaker-amps vsb_$VSB_VERSION:vsb_$VSB_VERSION
                echo "=================================="
                exit
    
            elif [ $REPO_PATH == "external/bluetooth/bluedroid-ath" ] ; then
                echo $REPO_PATH
                echo "=================================="
                git fetch -n $VSB_PATH/external/bluetooth/bluedroid vsb_$VSB_VERSION:vsb_$VSB_VERSION
                echo "=================================="
                exit
                
            elif [ $REPO_PATH == "vendor/qcom/proprietary_8974/aiv-play" ] ; then
                echo $REPO_PATH
                echo "=================================="
                git fetch -n $VSB_PATH/vendor/qcom/proprietary/aiv-play-noship vsb_$VSB_VERSION:vsb_$VSB_VERSION
                echo "=================================="
                exit
            fi    
               
            if grep -q "${REPO_PROJECT/\-8974/}" $WORK_ROOT/vsblist_$VSB_VERSION ; then
                VSB_PROJECT_PATH=$(grep "${REPO_PROJECT/\-8974/}" $WORK_ROOT/vsblist_$VSB_VERSION | awk "{print \$1}" | head -n 1)
                if [ -n $VSB_PROJECT_PATH ] ;then
                    echo $REPO_PATH
                    echo "=================================="  
                    git fetch -n $VSB_PATH/$VSB_PROJECT_PATH vsb_$VSB_VERSION:vsb_$VSB_VERSION
                    echo "=================================="
                    echo
                fi
            else
                echo "**********************************"
                echo "Note:"
                echo "There is no project name found in vsb projects list"
                echo "Maybe the project name is changed in fireos"
                echo "So please specify the project name in vsb projects list, and fetch the branch by youself"
                echo
                echo "The projects are : $REPO_PROJECT"
                echo
                echo "The path of them : $REPO_PATH"
                echo "**********************************"
                echo
            fi
        fi
    '
}


function merge_prebuild
{

########
######## Merge prebuilt
########

    pushd $VSB_PATH/vendor/amazon/prebuilt > /dev/null
    if ! echo $PWD | grep 'vendor/amazon/prebuilt' -q; then
        echo "Not in vendor/amazon/prebuilt"
        popd > /dev/null
        exit 0
    fi

    if [ "$BRANCH" = "qcom-int-8084" ]; then
        projects="apq8084 loki loki-unsigned"
    elif [ "$BRANCH" = "qcom-int-8974" ]; then
        projects="thor thor-unsigned ursa"
    elif [ "$BRANCH" = "ship-410-int" ]; then
        projects="thor thor-unsigned ursa"
    fi
    
    PRE="pre-"
    head=$(git rev-parse --verify vsb_$VSB_VERSION)
    for i in $projects; do
        echo $i;
        git branch -f $PRE$i $head
        git filter-branch -f --subdirectory-filter $i $PRE$i
    done
    popd > /dev/null
    
    for i in $projects;do
    echo
    echo "Merge $i"
    echo "==================================="
    pushd $WORK_ROOT/vendor/amazon/prebuilt/$i > /dev/null
    git branch -D $PRE$i
    git fetch -n $VSB_PATH/vendor/amazon/prebuilt $PRE$i:$PRE$i
    if ! git merge --log -m "Merge from vendorsupport $VSB_VERSION" $PRE$i;then
        echo "Please fix the conflict"
        $SHELL
    fi
    popd > /dev/null
    echo
    done

########
######## Merge signed-kernel
########
    
    pushd $VSB_PATH/vendor/amazon/signed-kernel > /dev/null
    git branch -f pre-kernel vsb_$VSB_VERSION
    git filter-branch -f --subdirectory-filter ursa pre-kernel
    popd > /dev/null
    
    pushd $WORK_ROOT/vendor/amazon/prebuilt/ursa > /dev/null
    git branch -D pre-kernel
    git fetch -n $VSB_PATH/vendor/amazon/signed-kernel pre-kernel:pre-kernel
    echo
    echo "Merge pre-kernel"
    echo "==================================="
    if ! git merge --log -m "Merge from vendorsupport $VSB_VERSION" pre-kernel ;then
        echo "Please fix the conflict"
        $SHELL
    fi
    popd > /dev/null 
    
}

function merge_vsb
{
    merge_prebuild
    repo forall -c '
        if echo $VSB_PROJECTS | sed "s/ /\n/g" | grep -q "^${REPO_PATH}$" ; then
            if git branch | grep -q vsb_$VSB_VERSION; then
                echo "===== $REPO_PATH ====="
                if ! git merge --log -m "Merge from vendorsupport $VSB_VERSION" vsb_$VSB_VERSION; then
                    $SHELL
                fi
                echo "===== $REPO_PATH ====="
                echo
            fi
        fi
        git branch -f done_vsb_merge HEAD
    '
}

function cherry_fireos
{
    repo forall -c '
        if [ ! "$(git show --pretty=%H -s fos/fireos/$BRANCH/kitkat)" = "$(git show --pretty=%H -s HEAD)" ]; then
            echo "===== $REPO_PATH ====="
            git cherry -v fos/fireos/$BRANCH/kitkat
            echo "===== $REPO_PATH ====="
            echo
        fi
    '  | tee  $WORK_ROOT/changes_from_vsb_$VSB_VERSION.list
}

function push_to_fireos
{
    repo forall -c '
        if [ ! "$(git show --pretty=%H -s fos/fireos/$BRANCH/kitkat)" = "$(git show --pretty=%H -s HEAD)" ]; then
            echo "===== $REPO_PATH ====="
            git push fos HEAD:fireos/$BRANCH/kitkat
            echo "===== $REPO_PATH ====="
            echo
        fi
    ' 2>&1 | tee -a push_vsb_$VSB_VERSION.list
}

