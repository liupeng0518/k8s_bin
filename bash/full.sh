#!/bin/bash

# need to run,don't change the sort
sync_class_list=(
    full
    single
    kube
    base
    )

# version
full::sync(){
    local tag=$1-full
    [ "$( hub_tag_exist $tag )" == null ] && {
        sudo cp /$save_name .
        cat>Dockerfile<<-EOF
        FROM liupeng0518/alpine
        COPY $save_name /
EOF
        docker build -t liupeng0518/$img_name:$tag .
        docker push liupeng0518/$img_name:$tag
        echo liupeng0518/$img_name:$1-full > $CUR_DIR/tag/$tag
        rm -f $save_name
    } || :
}

# version
single::sync(){
    du -shx *
    files=(
        $(sudo tar ztf /$save_name | grep -Po 'kubernetes/server/bin/\K[^.]+$')
    )
    for file in ${files[@]};do
        [ "$( hub_tag_exist $1-$file )" == null ] && {
            sudo tar -zxvf /$save_name  --strip-components=3  kubernetes/server/bin/$file
            cat>Dockerfile<<-EOF
            FROM liupeng0518/alpine
            COPY $file /
EOF
            sudo docker build -t liupeng0518/$img_name:$1-$file .
            docker push liupeng0518/$img_name:$1-$file
            echo liupeng0518/$img_name:$1-$file > $CUR_DIR/tag/$1-$file
            rm -f $file
        } || :
    done
}

# version
kube::sync(){
    local tag=$1-kube local_kube_file=()
    files=(
        kube-apiserver
        kube-controller-manager
        kube-proxy
        kube-scheduler
        kubectl
        kubelet
        hyperkube
        kubeadm
        )
    [ "$( hub_tag_exist $tag )" == null ] && {
        
        sudo tar -zxvf /$save_name  --strip-components=3  kubernetes/server/bin/
        for file in ${files[@]};do
            [ -f $file ] && local_kube_file+=($file)
        done
        sudo tar zcvf $save_name "${local_kube_file[@]}"
        rm -f $(ls -1I $save_name)
        cat>Dockerfile<<-EOF
        FROM liupeng0518/alpine
        COPY $save_name /
EOF
        docker build -t liupeng0518/$img_name:$tag .
        docker push liupeng0518/$img_name:$tag
        echo liupeng0518/$img_name:$tag > $CUR_DIR/tag/$tag
        rm -f $save_name 
    } || :
}

base::sync(){
    local tag=$1-base
    files=(
        kube-apiserver
        kube-controller-manager
        kube-proxy
        kube-scheduler
        kubectl
        kubelet
        )
    [ "$( hub_tag_exist $tag )" == null ] && {
        sudo tar -zxvf /$save_name  --strip-components=3  $( sed 's#^#kubernetes/server/bin/#' <(xargs -n1<<<"${files[@]}") )
        sudo tar zcvf $save_name "${files[@]}"
        rm -f ${files[@]}
        cat>Dockerfile<<-EOF
        FROM liupeng0518/alpine
        COPY $save_name /
EOF
        docker build -t liupeng0518/$img_name:$tag .
        docker push liupeng0518/$img_name:$tag
        echo liupeng0518/$img_name:$tag > $CUR_DIR/tag/$tag
        rm -f $save_name
    } || :
}

stable_tag(){
    curl -ks -XGET https://gcr.io/v2/${@#*/}/tags/list | jq -r .tags[] | grep -P 'v[\d.]+$' | sort -t '.' -n -k 2
}

main(){
    : ${save_name:=kubernetes-server-linux-amd64.tar.gz}

    cd $CUR_DIR/temp
    while read version;do
        grep -qP '\Q'"$version"'\E' $CUR_DIR/synced && continue
        printf -v version_url_download "$url_format" $version
        save_name=${version_url_download##*/}
        sudo wget $version_url_download -O /$save_name &>/dev/null
        
        for run in ${sync_class_list[@]};do
            $run::sync $version
            [[ $(df -h| awk  '$NF=="/"{print +$5}') -ge "$max_per" ]] && docker image prune -f || :
            [ $(( (`date +%s` - start_time)/60 )) -gt 47 ] && git_commit
        done
        echo $version >> $CUR_DIR/synced

        sudo rm -rf $save_name /$save_name kubernetes/ 
        [ $(( (`date +%s` - start_time)/60 )) -gt 47 ] && git_commit

    done < <(stable_tag gcr.io/google_containers/kube-apiserver-amd64)
    
    cd $CUR_DIR
    rm -rf temp/*
}

main
