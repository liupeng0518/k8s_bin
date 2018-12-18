#!/bin/bash
[ -n "$DEBUG" ] && set -x
export CUR_DIR version_file MY_REPO img_name max_per url_format

readonly CUR_DIR=$(cd $(dirname ${BASH_SOURCE:-$0}); pwd)
max_per=70
shell_dir='bash'
MY_REPO=liupeng0518
img_name=k8s_bin
url_format='https://dl.k8s.io/%s/kubernetes-server-linux-amd64.tar.gz'


git_init(){
    git config --global user.name "liupeng0518"
    git config --global user.email liupeng0518@qq.com
    git remote rm origin
    git remote add origin git@github.com:liupeng0518/k8s_bin.git
    git pull
    if git branch -a |grep 'origin/develop' &> /dev/null ;then
        git checkout develop
        git pull origin develop
        git branch --set-upstream-to=origin/develop develop
    else
        git checkout -b develop
        git pull origin develop
    fi
}

git_commit(){
     local COMMIT_FILES_COUNT=$(git status -s|wc -l)
     local TODAY=$(date +%F)
     if [ "$COMMIT_FILES_COUNT" -ne 0 ];then
        git add -A
        git commit -m "Synchronizing completion at $TODAY"
        git push -u origin develop
     fi
}

# tag
hub_tag_exist(){
    curl -s https://hub.docker.com/v2/repositories/${MY_REPO}/${img_name}/tags/$1/ | jq -r .name
}


main(){
    [ -z "$start_time" ] && start_time=$(date +%s)

    sudo cp -r bash /
    git_init
    mkdir -p temp tag
    sudo  rm -rf bash  README.md ;yes|sudo  cp -r /bash .
    wget https://raw.githubusercontent.com/liupeng0518/k8s_bin/master/README.md
    ls -l;ls -l temp
#     while true;do
#         curl -sX GET https://api.github.com/repos/liupeng0518/gcr.io/contents/gcr.io/google_containers/kube-apiserver-amd64?ref=develop |
#             jq -r '.[].name' | grep -P 'v[\d.]+$' | sort -t '.' -n -k 2 &> $version_file
#         [ "$(perl -nle 'END{print $.}'l $version_file)" -eq 10 ] && break
#     done

    while read shell_file;do
        source $shell_file
    done < <(find $shell_dir -type f -name '*.sh')
    rm -rf temp
    git_commit
}

main

