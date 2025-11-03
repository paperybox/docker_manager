#!/usr/bin/env bash
DEBIAN_FRONTEND=noninteractive 

echo "root:123" | chpasswd
addgroup --gid "$DOCKER_GRP_ID" "$DOCKER_GRP" --force-badname
adduser --disabled-password --force-badname --gecos '' "$DOCKER_USER" --uid "$DOCKER_USER_ID" --gid "$DOCKER_GRP_ID" 
echo "$DOCKER_USER:123" | chpasswd


Pwd=$( readlink -f "$( dirname $0 )" )
source $Pwd/docker.env

# install base tools

checkCmdWarn apt update
checkCmdWarn apt install -y sudo openssh-server openssh-client ssh vim make cmake gcc g++ curl git python3 wget unzip


usermod -aG sudo "$DOCKER_USER"
echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
cp -r /etc/skel/. /home/${DOCKER_USER}
chown ${DOCKER_USER}:${DOCKER_GRP} /home/${DOCKER_USER}
ls -ad /home/${DOCKER_USER}/.??* | xargs chown -R ${DOCKER_USER}:${DOCKER_GRP}

echo "
RSAAuthentication yes 
PubkeyAuthentication yes 
AuthorizedKeysFile .ssh/authorized_keys 
PermitRootLogin yes 
" >> /etc/ssh/sshd_config
service ssh restart

Pwd=$( readlink -f "$( dirname $0 )" )
bash $Pwd/install_config.sh



