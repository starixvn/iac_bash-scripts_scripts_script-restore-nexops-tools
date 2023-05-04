#!/usr/bin/env bash



function connectionToRegistry () {
    url="https://hub.nexdev.net/api/v2.0/health"
    state=$(curl -s $url | jq -r ".status")
    if [[ ! $state == "healthy" ]]; then
        echo "Connection to hub.nexdev.net             [FAILED]"
    else
        echo "Connection to hub.nexdev.net             [SUCCESSED]"
    fi
}


function connectionToFTPD () {

    checkConnection=$(nc -zv ftpd-backup.nexdev.net 2023 -w 1  > /dev/null 2>&1)
    
    if [[ $? -ne 0 ]]; then
        echo "Connection to ftpd.backup.nexdev.net     [FAILED]"
    else
        echo "Connection to ftpd.backup.nexdev.net     [SUCCESSED]"
    fi
}

function checkDockerInstalled () {
    commandCheck=$(docker version > /dev/null 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "Check DockerEngine installed  ... [no]"
    else
        version=$(docker version --format '{{.Server.Version}}' )
        echo "Check DockerEngine installed  ... [yes] - version $version"
    fi
    
}

function checkDockerComposeInstalled () {
    commandCheck=$(docker-compose --version > /dev/null 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "Check DockerCompose installed ... [no]"
    else
        version=$(docker-compose --version | awk '{print $3}' | sed  "s/,//g")
        echo "Check DockerCompose installed ... [yes] - version $version"
    fi
}


apt update && apt install jq -y
clear
echo "######################### Check connection ########################"
connectionToRegistry
connectionToFTPD
echo
echo "############ Check Docker & DockerCompose Installed ################"
checkDockerInstalled
checkDockerComposeInstalled

