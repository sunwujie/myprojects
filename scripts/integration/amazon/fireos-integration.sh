#!/bin/bash

export FROM_BRANCH=main
export FROM_BUILD_NUMBER=831
export TO_BRANCH=qcom-int-8974
export DRY_RUN=''
export PUSH_NEW='YES'

export ALL_DEVICES="saturn thor soho full_ariel apollo"

function init-to-branch
{
    repo init -m default.xml -b fireos/$TO_BRANCH/kitkat
    pushd .repo/manifests >/dev/null
    git reset --hard origin/fireos/$TO_BRANCH/kitkat
    popd >/dev/null
    repo sync -c -j4 $1

    repo list | awk '{print $3}' | sort > /tmp/projects_to.list
}

function init-from-branch
{
    if [ ! -e ".repo/nightlymanifest-$FROM_BRANCH" ]; then
        git clone ssh://gerrit6.labcollab.net:9418/fireos/nightlymanifest -b fireos/$FROM_BRANCH/kitkat .repo/nightlymanifest-$FROM_BRANCH
    fi

    pushd .repo/nightlymanifest-$FROM_BRANCH >/dev/null
    git pull
    popd >/dev/null

    pushd .repo/manifests >/dev/null
    if [ ! -e "manifest-$FROM_BRANCH-$FROM_BUILD_NUMBER.xml" ]; then
        if [ -e "../nightlymanifest-$FROM_BRANCH/manifest-$FROM_BRANCH-$FROM_BUILD_NUMBER.xml" ]; then
            cp ../nightlymanifest-$FROM_BRANCH/manifest-$FROM_BRANCH-$FROM_BUILD_NUMBER.xml .
        else
            echo "Please copy static manifest 'manifest-$FROM_BRANCH-$FROM_BUILD_NUMBER.xml' to here."
            $SHELL
        fi

        if [ ! -e "manifest-$FROM_BRANCH-$FROM_BUILD_NUMBER.xml" ]; then
            echo "Still cannot found the manifest. Abort."
            popd >/dev/null
            return
        fi
        manifest_rev=$(grep fireos/manifest manifest-$FROM_BRANCH-$FROM_BUILD_NUMBER.xml | sed 's/.*revision="\(\S*\)".*/\1/')
        if [ -z "$manifest_rev" ]; then
            manifest_rev=$(grep "manifest revision:" manifest-$FROM_BRANCH-$FROM_BUILD_NUMBER.xml | awk '{print $4}')
        fi
        git branch -f $FROM_BRANCH-$FROM_BUILD_NUMBER $manifest_rev
    fi
    popd >/dev/null

    repo init -m manifest-$FROM_BRANCH-$FROM_BUILD_NUMBER.xml
    repo sync -c -j4
    repo forall -c 'git branch -f $FROM_BRANCH-$FROM_BUILD_NUMBER'

    local projects_from=$(repo list | awk '{print $3}' | sort)

    local projects_new=
    for p in $projects_from; do
        if ! grep -q ^$p$ /tmp/projects_to.list; then
            projects_new="$projects_new $p"
        fi
    done
    echo "New projects: $projects_new "
    if [ -n "$projects_new" -a -n "$PUSH_NEW" ]; then
        repo forall $projects_new -c 'echo "Pushing [$REPO_I/$REPO_COUNT] $REPO_PROJECT"; git push $REPO_REMOTE $FROM_BRANCH-$FROM_BUILD_NUMBER:refs/heads/fireos/$TO_BRANCH/kitkat'
    fi
}

function merge-from-branch
{
    pushd .repo/manifests >/dev/null
    # Process manifest first
    head=$(git rev-parse --verify HEAD)
    if ! git merge --log -m "Merge $FROM_BRANCH #$FROM_BUILD_NUMBER into $TO_BRANCH" $FROM_BRANCH-$FROM_BUILD_NUMBER; then
        echo "Please fix conflict"
        $SHELL
    fi

    sed "/remote=\"fos\"/ s|fireos/$FROM_BRANCH/kitkat|fireos/$TO_BRANCH/kitkat|g" -i default.xml
    git commit -am "Change revision back to fireos/$TO_BRANCH/kitkat"

    if git diff --quiet $head HEAD; then
        git reset --hard $head
    fi
    git branch push -f
    push_head=$(git rev-parse --verify push)
    popd >/dev/null

    if [ ! "$head" = "$push_head" ]; then
        repo sync -c -j4
    fi

    repo forall -c '
    echo "Merging [$REPO_I/$REPO_COUNT] $REPO_PROJECT";
    if git branch | grep -Fq $FROM_BRANCH-$FROM_BUILD_NUMBER; then
        if ! git merge --log -m "Merge $FROM_BRANCH #$FROM_BUILD_NUMBER into $TO_BRANCH" $FROM_BRANCH-$FROM_BUILD_NUMBER; then
            $SHELL
        fi
    fi
    git branch push -f
    '
}

function merge-from-branch-single
{
    projects="$@"
    if echo $projects | grep manifest; then
        pushd .repo/manifests >/dev/null
        # Process manifest first
        head=$(git rev-parse --verify HEAD)
        if ! git merge --log -m "Merge $FROM_BRANCH #$FROM_BUILD_NUMBER into $TO_BRANCH" $FROM_BRANCH-$FROM_BUILD_NUMBER; then
            echo "Please fix conflict"
            $SHELL
        fi

        sed "/remote=\"fos\"/ s|fireos/$FROM_BRANCH/kitkat|fireos/$TO_BRANCH/kitkat|g" -i default.xml
        git commit -am "Change revision back to fireos/$TO_BRANCH/kitkat"

        if git diff --quiet $head HEAD; then
            git reset --hard $head
        fi
        git branch push -f
        push_head=$(git rev-parse --verify push)
        popd >/dev/null

        if [ ! "$head" = "$push_head" ]; then
            repo sync -c -j4
        fi
        projects=$(echo "$projects" | sed 's/manifest//g')
    fi

    repo sync $projects -c
    repo forall $projects -c '
    echo "Merging [$REPO_I/$REPO_COUNT] $REPO_PROJECT";
    if git branch | grep -Fq $FROM_BRANCH-$FROM_BUILD_NUMBER; then
        if ! git merge --log -m "Merge $FROM_BRANCH #$FROM_BUILD_NUMBER into $TO_BRANCH" $FROM_BRANCH-$FROM_BUILD_NUMBER; then
            $SHELL
        fi
    fi
    git branch push -f
    '
}

function cherry-integration
{
    pushd .repo/manifests >/dev/null
    origin=$(git rev-parse --verify origin/fireos/$TO_BRANCH/kitkat)
    new=$(git rev-parse --verify push)
    if [ ! "$new" = "$origin" ]; then
        echo manifest
        echo ==============================
        git cherry -v $origin
        echo ==============================
        echo
    fi | tee ../../cherry-$FROM_BRANCH-$FROM_BUILD_NUMBER-$TO_BRANCH.list
    popd >/dev/null

    repo forall -c '
    origin=$(git rev-parse --verify $REPO_LREV)
    new=$(git rev-parse --verify push)
    if [ ! "$new" = "$origin" ]; then
        echo [$REPO_I/$REPO_COUNT] $REPO_PATH
        echo ==============================
        git cherry -v $REPO_LREV
        echo ==============================
        echo
    fi
    ' | tee -a cherry-$FROM_BRANCH-$FROM_BUILD_NUMBER-$TO_BRANCH.list
}

function push-integration
{
    echo Pushing manifest
    pushd .repo/manifests >/dev/null
    origin=$(git rev-parse --verify origin/fireos/$TO_BRANCH/kitkat)
    new=$(git rev-parse --verify push)
    if [ ! "$new" = "$origin" ]; then
        git push $DRY_RUN origin push:fireos/$TO_BRANCH/kitkat
    fi 2>&1 | tee -a ../../push-$FROM_BRANCH-$FROM_BUILD_NUMBER-$TO_BRANCH.list
    popd >/dev/null

    echo Pushing projects
    repo forall -c '
    origin=$(git rev-parse --verify $REPO_LREV)
    new=$(git rev-parse --verify push)
    if [ ! "$new" = "$origin" ]; then
        echo "Pushing [$REPO_I/$REPO_COUNT] $REPO_PROJECT";
        git push $DRY_RUN $REPO_REMOTE push:$REPO_RREV
    fi
    ' 2>&1 | tee -a push-$FROM_BRANCH-$FROM_BUILD_NUMBER-$TO_BRANCH.list
}

function build-device
{
    devices=$@
    if [ -z "$devices" ]; then
        devices=$ALL_DEVICES
    fi

    source build/envsetup.sh
    bin-checkout

    for i in $devices; do
        echo $i
        export BUILD_NUMBER=$FROM_BRANCH-$FROM_BUILD_NUMBER-$TO_BRANCH
        m clean && lunch $i-userdebug && m -j8 droid target-files-package && m -j8 release
        if [ $? -eq 0 ]; then
            if [ -e "release-$i-userdebug-$FROM_BRANCH-$FROM_BUILD_NUMBER-$TO_BRANCH" ]; then
                rm -rf release-$i-userdebug-$FROM_BRANCH-$FROM_BUILD_NUMBER-$TO_BRANCH
            fi
            mv out/release-$i-userdebug release-$i-userdebug-$FROM_BRANCH-$FROM_BUILD_NUMBER-$TO_BRANCH
        else
            echo "Build failed for $i"
            return 1
        fi
    done
}

if [ ! "$0" = "bash" -a ! "$0" = "$SHELL" ]; then
    FROM_BRANCH=$1
    FROM_BUILD_NUMBER=$2
    TO_BRANCH=$3

    if [ -z "$FROM_BRANCH" -o -z "$FROM_BUILD_NUMBER" -o -z "$TO_BRANCH" ]; then
        echo "Usage: $(basename $0) FROM_BRANCH FROM_BUILD_NUMBER TO_BRANCH"
        exit 1
    fi

    init-to-branch
    init-from-branch
    init-to-branch -l
    merge-from-branch
    cherry-integration
fi

