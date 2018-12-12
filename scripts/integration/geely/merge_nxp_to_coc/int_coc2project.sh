#!/bin/bash

export BASE=`pwd`
export REMOTE_NAME=aosp
export NXP_BETA2=imx-android-oreo
export LOCAL_NXP_BETA2=local_$NXP_BETA2
export PROJECT_BRANCH=c3alfus_2
export LOCAL_PROJECT_BRANCH=local_$PROJECT_BRANCH
export TMP_BRANCH=tmp
export PATCH_LIST=patch_list.txt
export PUSH_LIST=push_list.txt
export MERGE_LIST=coc_merge.list
export REBASE_LIST=rebase_projects.list
export DRY_RUN=-n
export PUSH_BRANCH=merge_test

function create_local_nxp_beta2_branch
{
  echo "==============================="
  echo "create_local_nxp_beta2_branch"
  echo "==============================="
  repo forall -c 'git branch $LOCAL_NXP_BETA2 $REMOTE_NAME/$NXP_BETA2;echo $REPO_PATH'
  echo "==============================="
  echo "finish create_local_nxp_beta2_branch"
  echo "==============================="

}


function create_local_c3_2_branch
{
  echo "==============================="
  echo "create_local_c3_2_branch"
  echo "==============================="
  repo forall -c 'git branch $LOCAL_PROJECT_BRANCH $REMOTE_NAME/$PROJECT_BRANCH'
  echo "==============================="
  echo "finish create_local_c3_2_branch"
  echo "==============================="

}

function integrate_coc_to_project
{
  echo "==============================="
  echo "integrate_coc_to_project"
  echo "==============================="
  repo forall -c '
    if grep -q $REPO_PROJECT $BASE/$REBASE_LIST; then
      #if [ -n "$(git cherry $LOCAL_NXP_BETA2 $LOCAL_PROJECT_BRANCH)" ]; then
        echo "++++++++++ Rebase $REPO_PATH ++++++++++"
        git checkout -b $TMP_BRANCH $LOCAL_PROJECT_BRANCH
        if ! git rebase $LOCAL_NXP_BETA2 -i; then
          echo "Use \`git add xxx\` and \`git rebase --continue\` to resolve conflict"
          echo "Ask each team leader if not able to resolve the conflicts."
          echo "If abandon all patches, use \`git reset --hard $LOCAL_PROJECT_BRANCH\` before exit"
          $SHELL
        fi
        git checkout $LOCAL_PROJECT_BRANCH
        #git merge $TMP_BRANCH
        git reset --hard $TMP_BRANCH
        git branch -d $TMP_BRANCH
        echo
      #fi
    else
      #if [ -n "$(git cherry $LOCAL_PROJECT_BRANCH $LOCAL_NXP_BETA2)" ]; then
        echo "++++++++++ Merge $REPO_PATH ++++++++++"
        git checkout $LOCAL_PROJECT_BRANCH
        git reset --hard $LOCAL_NXP_BETA2  
       # if ! git merge $LOCAL_NXP_BETA2; then
       #   echo "!!!!!This project should not have conflict. Becasue project should not modify code!!!!!"
       #   echo "Use \`git add xxx\` and \`git commit\` to resolve conflict"
       #   echo "If abandon all patches, use \`git reset --hard $LOCAL_PROJECT_BRANCH\` before exit"
       #   $SHELL
       # fi
        echo
      #fi
    fi
  '
  echo "==============================="
  echo "finish integrate_coc_to_project"
  echo "==============================="
}

function patch_list
{
  echo "==============================="
  echo "patch list"
  echo "==============================="
  repo forall -c '
    if [ -n "$(git cherry $REMOTE_NAME/$PROJECT_BRANCH $LOCAL_PROJECT_BRANCH)" ]; then
      echo "------------------------------" 
      echo "$REPO_PATH"
      echo "------------------------------" 
      git cherry $REMOTE_NAME/$PROJECT_BRANCH $LOCAL_PROJECT_BRANCH -v
      echo
    fi
  ' 2>&1 | tee $PATCH_LIST
  echo "==============================="
  echo "finish patch list"
  echo "==============================="
}


function fake_push
{
  echo "==============================="
  echo "fake push"
  echo "==============================="
  repo forall -c '
    if [ -n "$(git cherry $REMOTE_NAME/$PROJECT_BRANCH $LOCAL_PROJECT_BRANCH)" ]; then
      echo "------------------------------" 
      echo "fake push $REPO_PATH"
      echo "------------------------------" 
      git push $REMOTE_NAME $LOCAL_PROJECT_BRANCH:refs/heads/$PUSH_BRANCH -n
      echo
    fi
  '
  echo "==============================="
  echo "finish fake push"
  echo "==============================="

}


function push2main
{
  echo "==============================="
  echo "push to main"
  echo "==============================="
  repo forall -c '
    if [ -n "$(git cherry $REMOTE_NAME/$PROJECT_BRANCH $LOCAL_PROJECT_BRANCH)" ]; then
      echo "------------------------------" 
      echo "push $REPO_PATH"
      echo "------------------------------" 
      git push $REMOTE_NAME $LOCAL_PROJECT_BRANCH:refs/heads/$PUSH_BRANCH -n
      echo
    fi
  ' 2>&1 | tee $PUSH_LIST
  echo "==============================="
  echo "finish push to main"
  echo "==============================="

}


function cleanup
{
  echo "==============================="
  echo "clean up"
  echo "==============================="
  repo forall -c 'git clean -xdf; git reset --hard -q;rm -rf .git/rr-cache;rm -rf .git/rebase-merge'
  repo abandon $LOCAL_NXP_BETA2 2>/dev/null
  repo abandon $LOCAL_PROJECT_BRANCH 2>/dev/null
  repo abandon $TMP_BRANCH 2>/dev/null
  echo "==============================="
  echo "finish clean up"
  echo "==============================="
}

function usage
{
    cat<<EOU

    $(basename $0) [OPTIONS]

    OPTIONS:

    -h      print this help
    -c      clean up work directory
    -o      create nxp beta2 branch
    -b      create local c3 project branch
    -i      integrate local nxp branch to local c3 project branch
    -l      generate patch list
    -n      fake push to main branch
    -p      really push to main branch

EOU
    exit
}


while getopts "hcobilnp" opt; do
    case $opt in
        h) usage;;
        c) CLEANUP=1;;
        o) DO_CREATE_COC_BRANCH=1;;
        b) DO_CREATE_PROJECT_BRANCH=1;;
        i) DO_INTEGRATION=1;;
        l) DO_PATCH_LIST=1;;
        n) DO_FAKE_PUSH=1;;
        p) DO_PUSH=1;;
        *) usage;;
    esac
done

shift $((OPTIND-1))

if [ "$CLEANUP" = "1" ]; then
  cleanup
fi

if [ "$DO_CREATE_COC_BRANCH" = "1" ]; then
  create_local_nxp_beta2_branch
fi

if [ "$DO_CREATE_PROJECT_BRANCH" = "1" ]; then
  create_local_c3_2_branch
fi

if [ "$DO_INTEGRATION" = "1" ]; then
  integrate_coc_to_project 
fi

if [ "$DO_PATCH_LIST" = "1" ]; then
  patch_list
fi

if [ "$DO_FAKE_PUSH" = "1" ]; then
  fake_push
fi

if [ "$DO_PUSH" = "1" ]; then
  push2main
fi
