#!/usr/bin/env bash
ROOT_DIR=$( readlink -f $(dirname $0)/../ )
echo "workspace: $ROOT_DIR"
#IMG=nvcr.io/nvidia/tensorrt:23.12-py3
IMG=nvcr.io/nvidia/pytorch:24.12-py3-igpu
DEFAULT_NAME="docker_${USER}"
name=""
update_flag=false
USE_GPU=""
CONTAINER_PORT="--network host"
HTTPS_PROT=""

echo_error(){
    echo -e "\e[91m[ERROR]$@\e[0m"
}
echo_info(){
    echo -e "\e[92m[INFO]$@\e[0m"
}


function usage() {
    echo "Usage: $0 [-n <container name>] [-p <port num>] [-f] [-g]" 1>&2
    echo " -n <container name>: set container name when create more than one"
    echo " -f: force update docker daemon.json for setting insecure registry"
    echo " -g: use nvidia gpu, need install nvidia-docker2"
    echo " -p <port num>: use set port to container ssh"
}

while getopts ":i:n:p:v:fhg" opt
do
    case "${opt}" in
    n)
        name=${OPTARG}
        ;;
    f)
        update_flag=true
        ;;
    g)
        USE_GPU="--runtime=nvidia"
        echo "Use GPU"
        ;;
    p)
        CONTAINER_PORT="-p $OPTARG:22"
        echo "Port rmap Host:Container = $OPTARG:22"
        ;;
    v)
        HTTPS_PROT="-e https_proxy=$OPTARG \
                    -e http_proxy=$OPTARG "
        echo "Use https proxy: $OPTARG"
        ;;
    i)
        IMG=$OPTARG
        echo "Use image: $IMG"
        ;;        
    h)
        usage
        exit 0
        ;;
    *)
        update_flag=false
        name=""
        ;;
    esac
done

function main(){
    CONTAINER_DEV=${DEFAULT_NAME}${name}
    docker ps -a --format "{{.Names}}" | grep "$CONTAINER_DEV" 1>/dev/null
    if [ $? == 0 ]; then
        docker stop $CONTAINER_DEV 1>/dev/null
        docker rm -v -f $CONTAINER_DEV 1>/dev/null
    fi

    local display=""
    if [[ -z ${DISPLAY} ]];then
        display=":0"
    else
        display="${DISPLAY}"
    fi

    USER_ID=$(id -u)
    GRP=$(id -g -n)
    GRP_ID=$(id -g)
    LOCAL_HOST=`hostname`
    DOCKER_HOST="docker_${LOCAL_HOST}"

    docker run -it \
        -d \
        ${USE_GPU} \
        --privileged \
        --name $CONTAINER_DEV \
        -e NVIDIA_DRIVER_CAPABILITIES=all \
        -e DISPLAY=$display \
        -e DOCKER_USER=docker_$USER \
        -e USER=docker_$USER \
        -e DOCKER_USER_ID=$USER_ID \
        -e DOCKER_GRP="$GRP" \
        -e DOCKER_GRP_ID=$GRP_ID \
        -e DOCKER_IMG=$IMG \
        --cap-add SYS_ADMIN \
        -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
        -v /etc/localtime:/etc/localtime:ro \
        -v /lib/modules:/lib/modules:ro \
        -v /usr/lib/linux-tools:/usr/lib/linux-tools:ro \
        -v /dev:/dev \
        -v /media:/media \
        -v $ROOT_DIR:/workspace \
        -w /workspace \
	    $CONTAINER_PORT \
        $HTTPS_PROT \
        --add-host ${LOCAL_HOST}:127.0.0.1 \
        --add-host ${DOCKER_HOST}:127.0.0.1 \
        --hostname $DOCKER_HOST \
        --shm-size 2G \
        -v /dev/null:/dev/raw1394 \
        $IMG \
        /bin/bash

    #add user
    if [ $? -ne 0 ];then
        echo_error "Failed to start container "
        exit 1
    fi
    if [ "${USER}" != "root"  ];then
        docker  exec $CONTAINER_DEV bash -c '/workspace/docker_manager/docker_adduser.sh'
        if [ $? -ne 0 ];then
            echo_error "init container env failed"
            exit 1
        fi
    fi
    echo_info "Finished setting up docker environment: $CONTAINER_DEV. "
    echo_info "Enjoy!"
}

main 
