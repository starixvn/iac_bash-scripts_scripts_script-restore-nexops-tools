#!/bin/bash



function setupStartNewAnsible () {

    mkdir memcached_socket redis_socket && \
    chmod 777 memcached_socket && chmod 777 redis_socket
    cp credentials.py.ori credentials.py
    echo -n "Server IP run postgres AWX: "
    read ipAWX
    sed -i "s/ansible-run-postgres/$ipAWX/g" credentials.py
    docker network create swarm_nexops
    docker-compose up -d
    echo "===========Done Install AWX===================="
}

function getBackupZipfile () {
    harborType=$1

    checkConnection=$(nc -zv ftpd-backup.nexdev.net 2023 -w 1  > /dev/null 2>&1)
    
    if [[ $? -ne 0 ]]; then
        echo "Fail to connect FTP Server!!!"
        exit 1
    fi

    echo "############# Download latest backupfile from FTPD##########"

    

    ftpdUser="starix"
    echo -n "Password ftpd user $ftpdUser: "
    read -s ftpdPass
    echo
    echo -n "Which env get backupfile [nexprod]: "
    read env
    env=${env:-"nexprod"}
    cp getLatestbackupfile.py.ori getLatestbackupfile.py
    sed -i "s/ftpd-user/$ftpdUser/g" getLatestbackupfile.py
    sed -i "s/ftpd-password/$ftpdPass/g" getLatestbackupfile.py
    sed -i "s/envOfBackupFile/$env/g" getLatestbackupfile.py
    sed -i "s/toolName/$harborType/g" getLatestbackupfile.py

    python3 getLatestbackupfile.py
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
}


function installNewAnsible () {
    setupStartNewAnsible
    while ! healthcheckAWX "$ipAWX" ; do
        echo "Still waiting ... Code respone now $responeCode"
        sleep 5
    done
    echo "Ansible Start Successfully !!!"
    echo "#####################################################" 
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
    
    until [[ $(docker ps | grep awx_postgres) ]]; do
        sleep 1
    done

    echo "Wating Ansible AWX starting ..."
    
    while ! healthcheckAWX "$ipAWX" ; do
        echo "Still waiting ... Code respone now $responeCode"
        sleep 5
    done

    echo "Ansible Start Successfully !!! Script will restore db"
    echo "#####################################################"
    sleep 2

    #Get container ID
    containerAWXPostgres=$(docker ps | grep awx_postgres | awk '{print $1}')

    #Extract zip backup Ansible
    gunzip -kf $zipFileBackupAnsible

    #Get filename backup Ansible after unzip
    sqlFile=$(ls | grep $zipFileBackupAnsible | cut -d "." -f1-2)

    docker exec -i $containerAWXPostgres pg_restore -U awx -v -d ansibledb -c < $sqlFile
    if [[ $? -eq 0 ]]; then
        echo "===================Restore DB AWX Successfuly====================="
    fi

    cleanupAfterRestore
}


function cleanupAfterRestore () {
    # clean up backup file
    rm -rf *.tar *.gz

    # cleanup file get latest bk file
    rm -rf getLatestbackupfile.py

    echo "Done cleanup !!!"
}



function healthcheckAWX () {
    ipAWX=$1
    responeCode=$(curl -s -o /dev/null -w "%{http_code}" -k http://$ipAWX:8882/api/v2/ping/ )

    if [[ $responeCode -ne "200" ]]; then
        return 1
    else
        return 0
    fi
}



echo  "Enter your choice to deploy Ansible

1. Install New Ansible
2. Install Ansible with backup data zip file
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
#testing








