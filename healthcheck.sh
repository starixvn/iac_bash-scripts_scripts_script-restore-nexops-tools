#!/usr/bin/env bash



function connectionToRegistry () {
    #apt update && apt install jq -y
    url="https://hub.nexdev.net/api/v2.0/health"
    state=$(curl -s $url | jq -r ".status")
    clear
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



connectionToRegistry
connectionToFTPD
