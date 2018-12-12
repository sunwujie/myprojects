#!/bin/bash

function push_to_fireos
{
    repo forall -pc '
        if git branch -a | grep -q "fos/fireos/qcom-int-8084/kitkat" ; then
            if [ ! "$(git show --pretty=%H -s fos/fireos/qcom-int-8084/kitkat)" = "$(git show --pretty=%H -s HEAD)" ]; then
                echo "===== $REPO_PATH ====="
                git push -n fos HEAD:refs/heads/fireos/qcom-int-8084/kitkat
                echo
            fi
        else
            echo "++++++++ $REPO_PATH +++++++++"
            git push -n  fos HEAD:refs/heads/fireos/qcom-int-8084/kitkat
            echo
        fi
    '
}
push_to_fireos
