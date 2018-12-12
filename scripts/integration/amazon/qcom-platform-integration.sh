#!/bin/bash

export WORK_ROOT=$PWD
export FIREOS_PATH=$WORK_ROOT/fireos
export VSB_PATH=$WORK_ROOT/vsb

export FROM_PLATFORM_NAME="msm8974"
export TO_BRANCH=qcom-int-8974
export PLATFOMR_POSTFIX="_8974"

export VSB_BUILD_NUMBER=275
export LAST_VSB_BUILD_NUMBER=258

export OUTPUT=$WORK_ROOT/output_${FROM_PLATFORM_NAME}_${VSB_BUILD_NUMBER}

export mirror=/srv/gerrit-mirror/qcom


function init_fireos
{

## ********************************************
## Init integration branch and sync code
## ********************************************

    pushd $FIREOS_PATH >/dev/null
   # if ! repo init -u ssh://gerrit6.labcollab.net:9418/fireos/manifest -b fireos/${TO_BRANCH}/kitkat ;then
   #     echo "Error: repo init platform error"
   #     popd > /dev/null
   #     return 1
   # fi

   # repo sync -c -j4

    pushd $FIREOS_PATH/.repo/manifests/ >/dev/null
    if [ "$TO_BRANCH" = "qcom-int-8084" ];then
        export PLATFORM_PROJECTS=$(cat qcom-common.xml qcom-8084.xml qcom-8084-proprietary.xml | awk '/<project/ { print $3 }' | cut -d '"' -f 2)
    elif [ "$TO_BRANCH" = "qcom-int-8974" ];then
        export PLATFORM_PROJECTS=$(cat qcom-common.xml qcom-8974.xml | awk '/<project/ { print $3 }' | cut -d '"' -f 2)
    fi
    popd > /dev/null
    popd > /dev/null 
}

function init_vsb
{

## ********************************************
## Init vsb branch and sync code
## ********************************************

    pushd $VSB_PATH >/dev/null
    
    if [ ! -e $VSB_PATH/.repo ] ;then
        if ! repo init -u ssh://gerrit4.labcollab.net:9418/vendorsupport/qcom/manifest -b platform/${FROM_PLATFORM_NAME}/kitkat ;then
            echo "Error: repo init platform error"
            popd > /dev/null
            return 1
        fi
    else
        repo init -m default.xml -b platform/${FROM_PLATFORM_NAME}/kitkat
    fi

    if [ ! -e ".repo/nightlymanifest-${FROM_PLATFORM_NAME}" ]; then
        git clone ssh://gerrit4.labcollab.net:9418/vendorsupport/qcom/nb_manifest -b platform/${FROM_PLATFORM_NAME}/kitkat .repo/nightlymanifest-${FROM_PLATFORM_NAME}
    fi

    pushd .repo/nightlymanifest-${FROM_PLATFORM_NAME} >/dev/null
    git pull
    popd >/dev/null

    BUILD_NUMBER=$1

    pushd .repo/manifests >/dev/null
    if [ ! -e "manifest-kitkat-${BUILD_NUMBER}.xml" ]; then
        if [ -e "../nightlymanifest-${FROM_PLATFORM_NAME}/manifest-kitkat-${BUILD_NUMBER}.xml" ]; then
            cp ../nightlymanifest-${FROM_PLATFORM_NAME}/manifest-kitkat-${BUILD_NUMBER}.xml .
        else
            echo "ERROR: Can't get the static manifest 'manifest-kitkat-${BUILD_NUMBER}.xml'"
        fi

        if [ ! -e "manifest-kitkat-${BUILD_NUMBER}.xml" ]; then
            echo "Still cannot found the manifest. Abort."
            popd >/dev/null
            popd >/dev/null
            return
        fi
    fi
    popd >/dev/null

    repo init -m manifest-kitkat-${BUILD_NUMBER}.xml
    repo sync -c -j4

    repo forall -c git branch -f vsb_${BUILD_NUMBER}
    repo list | awk '{print $1}' > ${OUTPUT}/vsblist_$BUILD_NUMBER
    repo list | awk '{print $3}' | sort > /tmp/projects_names_of_${BUILD_NUMBER}.list

    popd > /dev/null
}


function get_delta_changes_and_new_projects
{

## ********************************************
## Get the new projects added in this vsb build
## ********************************************

    if [ -n "$LAST_VSB_BUILD_NUMBER" -a -n "$VSB_BUILD_NUMBER" ] ;then
        init_vsb $LAST_VSB_BUILD_NUMBER
        init_vsb $VSB_BUILD_NUMBER

        local projects_new=
        while read line;do
            if ! grep -q ^$line$ /tmp/projects_names_of_${LAST_VSB_BUILD_NUMBER}.list; then
                projects_new="$projects_new $p"
            fi
        done < /tmp/projects_names_of_${VSB_BUILD_NUMBER}.list
        
        echo "New projects: $projects_new " > ${OUTPUT}/New_projects.list

## ********************************************
## Get the delta changes between two builds
## ********************************************

        pushd $VSB_PATH >/dev/null
        repo forall -c '
            if git branch | grep -q vsb_$LAST_VSB_BUILD_NUMBER ;then
                if [ ! "$(git show --pretty=%H -s vsb_$VSB_BUILD_NUMBER)" = "$(git show --pretty=%H -s vsb_$LAST_VSB_BUILD_NUMBER)" ];then
                    echo "===== $REPO_PATH ====="
                    git cherry vsb_$LAST_VSB_BUILD_NUMBER vsb_$VSB_BUILD_NUMBER -v
                    echo "===== $REPO_PATH ====="
                    echo
                fi
            fi
        ' | tee ${OUTPUT}/delta_changes_from_${LAST_VSB_BUILD_NUMBER}_to_${VSB_BUILD_NUMBER}.list
        popd > /dev/null
    fi
}

function fetch_vsb
{

## ********************************************
## Fetch vsb branch into fireos before merge
## ********************************************

    if [ "$TO_BRANCH" = "qcom-int-8084" ];then
export SPECIAL_PROJECTS_MAP=$(cat <<EOL
vendor/qcom/proprietary_8084/aiv-play:vendor/qcom/proprietary/aiv-play-noship
vendor/qcom/opensource_8084/fm:vendor/qcom/proprietary/fm
kernel/qcom/3.10:kernel
EOL
)
    elif [ "$TO_BRANCH" = "qcom-int-8974" ];then
export SPECIAL_PROJECTS_MAP=$(cat <<EOL
hardware/amazon/audio/external-speaker-amps:hardware/amazon/audio/external-speaker-amps
external/bluetooth/bluedroid-ath:external/bluetooth/bluedroid
vendor/qcom/proprietary_8974/aiv-play:vendor/qcom/proprietary/aiv-play-noship
kernel/qcom/3.4:kernel
EOL
)
    fi

    pushd $FIREOS_PATH >/dev/null
    repo forall -c '
        if echo $PLATFORM_PROJECTS | sed "s/ /\n/g" | grep -q "^${REPO_PATH}$" ;then
            VSB_PROJECT_PATH=""
            while read line;do
                if [ "$line" = "${REPO_PATH/${PLATFOMR_POSTFIX}/}" ];then
                    VSB_PROJECT_PATH=$line
                    break
                fi
            done < ${OUTPUT}/vsblist_$VSB_BUILD_NUMBER

            if [ -z "$VSB_PROJECT_PATH" ] ;then
                for i in $SPECIAL_PROJECTS_MAP; do
                    if [ "$REPO_PATH" = "$(echo $i | cut -d : -f 1)" ];then
                        VSB_PROJECT_PATH=$(echo $i | cut -d : -f 2)
                        break
                    fi
                done
            fi

            if [ -n "$VSB_PROJECT_PATH" ] ;then
                echo $REPO_PATH
                echo "=================================="  
                git fetch -n $VSB_PATH/${VSB_PROJECT_PATH} vsb_$VSB_BUILD_NUMBER:vsb_$VSB_BUILD_NUMBER
                echo "=================================="
                echo
            else
                echo $REPO_PATH >> ${OUTPUT}/projects_not_found_in_vsb.list
            fi

        fi
    '
    popd >/dev/null
}


function merge_special_projects
{

## ********************************************
## Handle some special vsb projects
## ********************************************

    if [ "$FROM_PLATFORM_NAME" = "apq80x4" ]; then
      #  projects="apq8084 loki loki-unsigned"
        projects="loki loki-unsigned"
    elif [ "$FROM_PLATFORM_NAME" = "msm8974" ]; then
        projects="thor thor-unsigned ursa"
    fi

    pushd $VSB_PATH/vendor/amazon/prebuilt > /dev/null
    if ! echo $PWD | grep 'vendor/amazon/prebuilt' -q; then
        echo "Not in vendor/amazon/prebuilt"
        popd > /dev/null
        return 1
    fi
    
    PRE="pre-"
    head=$(git rev-parse --verify vsb_$VSB_BUILD_NUMBER)
    for i in $projects; do
        echo $i;
        git branch -f ${PRE}$i $head
        git filter-branch -f --subdirectory-filter $i ${PRE}$i
    done
    popd > /dev/null
    
    for i in $projects;do
    echo
    echo "Merge $i"
    echo "==================================="
    pushd $FIREOS_PATH/vendor/amazon/prebuilt/$i > /dev/null
    git branch -D ${PRE}$i > /dev/null
    git fetch -n $VSB_PATH/vendor/amazon/prebuilt ${PRE}$i:${PRE}$i

    if ! git merge --log -m "Merge from vendorsupport $VSB_BUILD_NUMBER" $PRE$i ;then
        echo $REPO_PATH >> ${OUTPUT}/conflict_projects.list
        echo "Please fix the conflicts"
        $SHELL
    fi

    popd > /dev/null
    done

    if [ "$FROM_PLATFORM_NAME" = "msm8974" ]; then
        pushd ${VSB_PATH}/hardware/amazon/media > /dev/null
        head=$(git rev-parse --verify vsb_$VSB_BUILD_NUMBER)
        git branch -f vsb_camera $head
        git filter-branch -f --subdirectory-filter vsb_camera camera
        popd >/dev/null

        pushd ${FIREOS_PATH}/hardware/amazon/media/camera_8974 > /dev/null
        git fetch -n ${VSB_PATH}/hardware/amazon/media vsb_camera:vsb_camera

        if git branch | grep -q vsb_camera;then
            if ! git merge --log -m "Merge from vendorsupport $VSB_BUILD_NUMBER" vsb_camera ;then
                echo $REPO_PATH >> ${OUTPUT}/conflict_projects.list
                echo "Please fix the conflicts"
                $SHELL
            fi
        fi
        popd >/dev/null
    fi
}

function merge_vsb
{

## ********************************************
## Merge vsb branch
## ********************************************

    merge_special_projects
    pushd $FIREOS_PATH >/dev/null
    repo forall -c '
        if echo $PLATFORM_PROJECTS | sed "s/ /\n/g" | grep -q "^${REPO_PATH}$";then
            if git branch | grep -q vsb_$VSB_BUILD_NUMBER; then
                echo "===== $REPO_PATH ====="
                if ! git merge --log -m "Merge from vendorsupport $VSB_BUILD_NUMBER" vsb_$VSB_BUILD_NUMBER; then
                    echo $REPO_PATH >> ${OUTPUT}/conflict_projects.list
                    echo "Please fix the conflicts"
                    $SHELL
                fi
                echo "===== $REPO_PATH ====="
                echo
            fi
        fi
        git branch -f done_vsb_merge HEAD
    '
    popd >/dev/null
}

function cherry_fireos
{

## ********************************************
## Get the changes list in this integration
## ********************************************

    pushd $FIREOS_PATH >/dev/null
    repo forall -c '
        if [ ! "$(git show --pretty=%H -s fos/fireos/${TO_BRANCH}/kitkat)" = "$(git show --pretty=%H -s HEAD)" ]; then
            echo "===== $REPO_PATH ====="
            git cherry -v fos/fireos/${TO_BRANCH}/kitkat
            echo "===== $REPO_PATH ====="
            echo
        fi
    '  | tee ${OUTPUT}/changes_from_vsb_$VSB_BUILD_NUMBER.list
    popd >/dev/null
}


function push_platform_changes
{

## ********************************************
## Push vsb code to integration branch
## ********************************************

    pushd $FIREOS_PATH >/dev/null
    repo forall -c '
        if [ ! "$(git show --pretty=%H -s fos/fireos/$TO_BRANCH/kitkat)" = "$(git show --pretty=%H -s HEAD)" ]; then
            echo "===== $REPO_PATH ====="
            git push fos HEAD:refs/heads/fireos/${TO_BRANCH}/kitkat -n
            echo "===== $REPO_PATH ====="
            echo
        fi
    '  2>&1 | tee -a ${OUTPUT}/push-vsb-${VSB_BUILD_NUMBER}-${TO_BRANCH}.list
    popd >/dev/null
}


if [ ! "$0" = "bash" -a ! "$0" = "$SHELL" ]; then
    export FROM_PLATFORM_NAME=$1
    export VSB_BUILD_NUMBER=$2
    export LAST_VSB_BUILD_NUMBER=$3

    export WORK_ROOT=$PWD
    export FIREOS_PATH=$WORK_ROOT/fireos
    export VSB_PATH=$WORK_ROOT/vsb
    export mirror=/srv/gerrit-mirror/qcom
    export OUTPUT=$WORK_ROOT/output_${FROM_PLATFORM_NAME}_${VSB_BUILD_NUMBER}
    
    if [ ! -e $FIREOS_PATH ];then
        mkdir $FIREOS_PATH
    fi
    
    if [ ! -e $VSB_PATH ];then
        mkdir $VSB_PATH
    fi

    if [ ! -e $OUTPUT ];then
        mkdir $OUTPUT
    fi

    if [ -z "$FROM_PLATFORM_NAME" -o -z "$VSB_BUILD_NUMBER" -o -z "$LAST_VSB_BUILD_NUMBER" ]; then
        echo "Usage: $(basename $0) FROM_PLATFORM_NAME VSB_BUILD_NUMBER LAST_VSB_BUILD_NUMBER"
        echo "Usage: For example"
        echo "$(basename $0) apq80x4 268 258"
        exit 1
    fi

    case $FROM_PLATFORM_NAME in
        apq80x4)
            export TO_BRANCH=qcom-int-8084
            export PLATFOMR_POSTFIX="_8084"
            echo "The platform you are integarting is: apq80x4."
            echo ;;
        msm8974)
            export TO_BRANCH=qcom-int-8974
            export PLATFOMR_POSTFIX="_8974"
            echo "The platform you are integarting is: msm8974."
            echo ;;
        *)
            echo "The platform you input $1 is not supported."
            echo "Please input the right platform name, thanks."
            exit ;;
    esac 
   
    init_fireos

    if [ -n "$LAST_VSB_BUILD_NUMBER" -a -n "$VSB_BUILD_NUMBER" ];then
        get_delta_changes_and_new_projects
    elif [ -n "$VSB_BUILD_NUMBER" ];then
        init_vsb $VSB_BUILD_NUMBER
    fi

    fetch_vsb
    merge_vsb
    cherry_fireos
fi


