#!/usr/bin/env bash


function installDocker () {
    dockerVersion=$1
    apt-get remove docker docker-engine docker.io containerd runc

    apt-get update
    apt-get install \
    ca-certificates \
    curl \
    gnupg -y

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
        "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update


    apt-get install docker-ce=$dockerVersion \
            docker-ce-cli=$dockerVersion \
            containerd.io docker-buildx-plugin docker-compose-plugin -y

    systemctl enable --now docker.service

}


function installDockerCompose () {
    curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
}


dockerVersion="5:20.10.7~3-0~ubuntu-focal"

installDocker $dockerVersion
installDockerCompose






