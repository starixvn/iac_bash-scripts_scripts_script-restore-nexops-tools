#!/bin/bash



function setupStartNewAnsible () {

    mkdir memcached_socket redis_socket && \
    chmod 777 memcached_socket && chmod 777 redis_socket
    echo -n "Server IP run postgres AWX: "
    read ipAWX
    sed -i "s/ansible-run-postgres/$ipAWX/g" credentials.py
    docker network create swarm_nexops
    docker-compose up -d
    echo "===========Done Install AWX===================="
}

function getBackupZipfile () {
    echo -n "Which env get backupfile [nexprod]: "
    read env
    env=${env:-"nexprod"}
    echo $env
    cp getfile-ori.py getLatestbackupfile.py
    sed -i "s/envOfBackupFile/$env/g" getLatestbackupfile.py
    python3 getLatestbackupfile.py
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
}


function installNewAnsible () {
    setupStartNewAnsible
}

function restoreAnsible() {
    getBackupZipfile
    zipFileBackupAnsible=$(ls | grep -E "*.gz")
    if [ ! -f "$zipFileBackupAnsible" ]; then 
        exit 1
    fi

    checkAWXrunning=$(docker ps | grep awx)
    if [[ ! $checkAWXrunning ]]; then
        setupStartNewAnsible
    fi
    
    echo "Waiting 300s AWX Setup Database ..."
    sleep 300


    #Get container ID
    containerAWXPostgres=$(docker ps | grep postgres | awk '{print $1}')

    #Extract zip backup Ansible
    gunzip -kf $zipFileBackupAnsible

    #Get filename backup Ansible after unzip
    sqlFile=$(ls | grep $zipFileBackupAnsible | cut -d "." -f1-2)

    docker exec -i $containerAWXPostgres pg_restore -U awx -v -d ansibledb -c < $sqlFile
    if [[ $? -eq 0 ]]; then
        echo "===================Restore DB AWX Successfuly====================="
    fi
}



echo  "Enter your choice to deploy Ansible

1. Install New Ansible
2. Install New Ansible and Restore Ansible with backup zip file
"
echo -n "Your choice: "
read choice


case "$choice" in
    1) installNewAnsible
    ;;
    2) restoreAnsible
    ;;
    *) echo "Wrong option"
    exit 1
    ;;
esac








