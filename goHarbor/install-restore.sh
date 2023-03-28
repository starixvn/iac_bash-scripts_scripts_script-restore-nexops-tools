#!/usr/bin/env bash


function installNewHarbor () {
    getZipHarborInstall
    echo "First setup to install goHarbor Registry !!!"
    echo -n "IP Server run Harbor: "
    read ip
    echo -n "Port run Harbor: "
    read port
    echo -n "External domain HabroRegistry: "
    read domain
    echo -n "Full path save data registry Harbor: "
    read path

    #backup harbor.yml
    cp harbor.yml.ori harbor.yml

    sed -i "s/goHarborHost/$ip/g" harbor.yml
    sed -i "s/goHarborPort/$port/g" harbor.yml
    sed -i "s|goHarborVolumePath|$path|g" harbor.yml
    sed -i "s/harborDomain/$domain/g" harbor.yml


    
    if [[ ! -d $path ]]; then
        echo "Path to save data you type not exist, Script will create ..."
        mkdir -p "$path"
    fi

    echo "Install Harbor Registry..."
    chmod +x prepare
    bash install.sh --with-trivy

    state=$(healthCheckHarbor "$ip")

    while [ $state ]; do
        echo "Waiting harbor starting ..."
        sleep 1
    done
}


function getBackupZipfile () {
    harborType=$1
    checkConnection=$(nc -zv ftpd-backup.nexdev.net 2023 -w 1  > /dev/null 2>&1)
    
    if [[ $? -ne 0 ]]; then
        echo "Fail to connect FTP Server!!!"
        exit 1
    fi

    echo "############# Download latest backupfile from FTPD ##########"

    ftpdUser="starix"
    env="local"
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

    echo "Waiting goHarbor start succesfully !!!"
    sleep 120
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

    echo "Done restoredb"
    cleanup

    state=$(healthCheckHarbor "$newIP")

    while [ $state ]; do
        echo "Waiting harbor starting ..."
        sleep 1
    done
}


function restoreHarborRegistryImage () {

    getZipHarborInstall

    #command to list HarborRegistry
    getBackupZipfile "harbor-registry"

    commandCheckHaborRunning=$(docker ps | grep harbor)

    if [[ $? -ne 0 ]]; then
        exit 1
    fi


    ls *harborRegistry*zip 1> /dev/null 2>&1
    if  [[ $? != 0 ]] ; then
        echo "Cannot find any Zip file backup HarborRegistry"
    else
        harborRegistryZip=$(ls | grep -E "*harborRegistry*")
    fi


    pathInHarborfile=$(cat harbor.yml | grep -E "data_volume:" |  cut -d " " -f2)
    echo -n "Full path data volume save registry[$pathInHarborfile]: "
    read pathNew
    pathNew=${pathNew:-$pathInHarborfile}

    
    echo "Script will restore registry data !!!"
    sleep 10
    unzip -o $harborRegistryZip -d $pathNew

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
        echo false
    else
        echo true
    fi
}


function cleanup () {
    echo -n "Cleanup after install"
    echo
    rm -rf db secret redis 
    rm -rf *.gz
    rm -rf getLatestbackupfile.py
    rm -rf *.zip
    echo -n "Done cleanup !!!"
    echo
}

echo "Enter your choice to deploy goHarbor

1. Install New Harbor
2. Install Harbor with Harbor-Config backup data
3. Restore Harbor-Registry-Image backup data
"
echo -n "Your choice: "
read choice



case "$choice" in
    1) installNewHarbor
    ;;
    2) restoreHarborConfig
    ;;
    3) restoreHarborRegistryImage
    ;;
    *) echo "Wrong option"
    exit 1
    ;;
esac





