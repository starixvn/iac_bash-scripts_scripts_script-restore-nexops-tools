#!/usr/bin/env bash


function installNewHarbor () {
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
    cp harbor-ori.yml harbor.yml

    sed -i "s/goHarborHost/$ip/g" harbor.yml
    sed -i "s/goHarborPort/$port/g" harbor.yml
    sed -i "s|goHarborVolumePath|$path|g" harbor.yml
    sed -i "s/harborDomain/$domain/g" harbor.yml


    
    if [[ ! -d $path ]]; then
        echo "Path to save data you type not exist, Script will create ..."
        mkdir -p "$path"
    fi

    echo "Install Harbor Registry..."
    bash install.sh --with-trivy
}

function restoreHarbor () {

    #command to list HarborConfig
    ls *harborConfig*zip 1> /dev/null 2>&1
    if  [[ $? != 0 ]] ; then
        echo "Cannot find any Zip file backup HarborConfig"
        exit 1
    else
        harborConfigZip=$(ls | grep -E "*harborConfig*")
    fi



    #command to list HarborRegistry
    ls *harborRegistry*zip 1> /dev/null 2>&1
    if  [[ $? != 0 ]] ; then
        echo "Cannot find any Zip file backup HarborRegistry"
        exit 1
    else
        harborRegistryZip=$(ls | grep -E "*harborRegistry*")
    fi


    unzip -o $harborConfigZip
    pathInHarborfile=$(cat harbor.yml | grep -E "data_volume:" |  cut -d " " -f2)
    #sleep 3
    echo -n "Full path data volume save registry[$pathInHarborfile]: "
    read pathNew
    pathNew=${pathNew:-$pathInHarborfile}
    echo $pathNew
    sed -i "s|$pathInHarborfile|$pathNew|g" harbor.yml

    if [[ ! -d $pathNew ]]; then
        echo "Path to save data you type not exist, Script will create ..."
        mkdir -p "$pathNew"
    fi

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

    echo "Scirpt will restore registry data !!!"
    sleep 10
    unzip -o $harborRegistryZip -d $pathNew

    echo "Done restore Registry"

}

echo "Enter your choice to deploy goHarbor

1. Install New Harbor
2. Restore Harbor-Config & Harbor-Registry with backup data
"
echo -n "Your choice: "
read choice


case "$choice" in
    1) installNewHarbor
    ;;
    2) restoreHarbor
    ;;
    *) echo "Wrong option"
    exit 1
    ;;
esac