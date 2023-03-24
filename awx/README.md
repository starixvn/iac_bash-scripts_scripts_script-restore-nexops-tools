# Setup AWX Tower

## Remember to mount gluster backups before start AWX
## Change directory to awx-repo-install

`cd awx-repo-install ` 

## Create directory memcached_socket && redis_socket
`mkdir memcached_socket redis_socket`

## Chmod Permission memcached_socker && redis_socket

`chmod 777 memcached_socket && chmod 777 redis_socket`


## Edit file credentials.py

> Edit file with info postgres db new

## Create Docker Network

`docker network create swarm_nexops`

## Run Docker-Compose file

`docker-compose up`

## Restore Database AWX 

> Get file backupdb  from /var/www/gluster/backups/nexprod/ansible -- with latest backup file

## Restore db postgres AWX

> To uncompressed backup file

`gunzip -k  ansibledb-20230208.tar.gz`

> Command to restore db to container run postgres

`docker exec -i <container_name> pg_restore -U awx -v -d ansibledb -c < ansibledb-20230208.tar`

