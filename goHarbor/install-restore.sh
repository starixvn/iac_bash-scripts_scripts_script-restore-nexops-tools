#!/usr/bin/env bash


function getBackupZipfile () {
    harborType=$1
    checkConnection=$(nc -zv ftpd-backup.nexdev.net 2023 -w 1  > /dev/null 2>&1)
    
    if [[ $? -ne 0 ]]; then
        echo "Fail to connect FTP Server!!!"
        exit 1
    fi

    echo "############# Download latest backupfile from FTPD ##########"

    env="local"
    echo -n "User ftpd: "
    read ftpdUser
    echo -n "Password ftpd user $ftpdUser: "
    read -s ftpdPass
    echo
    echo -n "Which env get backupfile [local]: "
    read env
    env=${env:-"local"}
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


function restoreHarborConfig () {

    getZipHarborInstall

    getBackupZipfile "harbor-db"
    #command to list HarborConfig
    ls *harborConfig*zip 1> /dev/null 2>&1
    if  [[ $? != 0 ]] ; then
        echo "Cannot find any Zip file backup HarborConfig"
        exit 1
    else
        harborConfigZip=$(ls | grep -E "*harborConfig*")
    fi


    unzip -o $harborConfigZip
    ipServerRunHarbor=$(cat harbor.yml | grep hostname | sed -n 2p | cut -d " " -f2 | cut -d '"' -f2)
    pathInHarborfile=$(cat harbor.yml | grep -E "data_volume:" |  cut -d " " -f2)
    urlHarbor=$(cat harbor.yml | grep external_url | sed -n 2p | cut -d " " -f2 |cut -d '"' -f2)
    #sleep 3

    echo -n "IP Server Run goHarbor[$ipServerRunHarbor]: "
    read newIP
    newIP=${newIP:-$ipServerRunHarbor}
    sed -i "s|$ipServerRunHarbor|$newIP|g" harbor.yml


    echo -n "URL use goHarbor [$urlHarbor]: "
    read urlNew
    urlNew=${urlNew:-$urlHarbor}
    sed -i "s|$urlHarbor|$urlNew|g" harbor.yml


    echo -n "Full path data volume save registry[$pathInHarborfile]: "
    read pathNew
    pathNew=${pathNew:-$pathInHarborfile}
    echo $pathNew
    sed -i "s|$pathInHarborfile|$pathNew|g" harbor.yml




    if [[ ! -d $pathNew ]]; then
        echo "Path to save data you type not exist, Script will create ..."
        mkdir -p "$pathNew"
    fi

    chmod +x prepare
    bash install.sh --with-trivy

    sleep 5

    while ! healthCheckHarbor "$newIP"; do
        echo "Waiting harbor starting ...$state"
        sleep 1
    done

    # Restore config goHarbor Registry
    docker exec -i harbor-db pg_restore -U postgres -d registry -c < db/registry.tar
    docker exec -i harbor-db pg_restore -U postgres -d postgres -c < db/postgres.tar
    docker exec -i harbor-db pg_restore -U postgres -d notarysigner -c < db/notarysigner.tar
    docker exec -i harbor-db pg_restore -U postgres -d notaryserver -c < db/notaryserver.tar    

    # Restore Redis
    cp -r redis $pathNew/
    chown -R 999 $pathNew/redis

    # Restore Data Secret
    cp -r secret/* $pathNew/secret/

    echo "######### Done restoredb ###############"

    cleanup

    state=$(healthCheckHarbor "$newIP")

    while ! healthCheckHarbor "$newIP"; do
        echo "Waiting harbor starting ...$state"
        sleep 1
    done
    echo 
    echo "####### goHarbor start successfully !!! ############"
}


function restoreHarborRegistryImage () {

    commandCheckHaborRunning=$(docker ps | grep harbor)
    if [[ $? -ne 0 ]]; then
        echo "Harbor not running, Please start goHarbor first"
        exit 1
    fi



    ls *harborRegistry*zip 1> /dev/null 2>&1
    if  [[ $? != 0 ]] ; then
        #command to list HarborRegistry
        getBackupZipfile "harbor-registry"

    fi

    harborRegistryZip=$(ls | grep -E "*harborRegistry*")
    pathInHarborfile=$(cat harbor.yml | grep -E "data_volume:" |  cut -d " " -f2)

    echo "Script will restore registry data !!!"
    unzip -o $harborRegistryZip -d $pathInHarborfile

    echo "Done restore Registry"
    cleanup
}


function getZipHarborInstall () {

    echo -n "Fill Information to download HarborZip Images"
    checkConnection=$(nc -zv ftpd-backup.nexdev.net 2023 -w 1  > /dev/null 2>&1)  
    if [[ $? -ne 0 ]]; then
        echo "Fail to connect FTP Server!!!"
        exit 1
    fi

    ftpdUser="nexops"
    pathFile="/goHarbor/InstallZip"
    patternRegex="/envOfBackupFile/toolName"
    echo 
    echo -n "Password ftpd user $ftpdUser: "
    read -s ftpdPass
    echo

    cp getLatestbackupfile.py.ori getLatestbackupfile.py
    sed -i "s/ftpd-user/$ftpdUser/g" getLatestbackupfile.py
    sed -i "s/ftpd-password/$ftpdPass/g" getLatestbackupfile.py
    sed -i "s|$patternRegex|$pathFile|g" getLatestbackupfile.py

    echo -n "Waiting to download harborZip..."
    python3 getLatestbackupfile.py
    if [[ $? -ne 0 ]]; then
        echo "Failed to download file zip to install Harbor !!!"
        exit 1
    fi
    echo -n "Done download harborZip"
    echo
}

function healthCheckHarbor () {
    ipHarbor=$1
    state=$(curl -s http://$ipHarbor:5055/api/v2.0/health | jq -r ".status")
    if [[ ! $state == "healthy" ]]; then
        return 1
    else
        return 0
    fi
}


function cleanup () {

    rm -rf db secret redis 
    rm -rf *.gz
    rm -rf getLatestbackupfile.py
    rm -rf *.zip
    echo  "Done cleanup !!!"
}

apt install jq -y

clear

echo "Enter your choice to deploy goHarbor

1. Install Harbor with Harbor-Config backup data
2. Restore Harbor-Registry-Image backup data

"
echo -n "Your choice: "
read choice



case "$choice" in
    1) restoreHarborConfig
    ;;
    2) restoreHarborRegistryImage
    ;;
    *) echo "Wrong option"
    exit 1
    ;;
esac





