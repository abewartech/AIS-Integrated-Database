#!/bin/bash

source .env

function select_tables {

    echo "Tables selected:"

    if [ "${ADMIN}" == 'TRUE' ]; then
            table=admin
            echo "--${table^^}"
            cp -R build/db/db_init_scripts/${table}/* build/db/scripts_to_run/
            sleep 2;
    fi

    if [ "${AIS}" == 'TRUE' ]; then
            table=ais
            echo "--${table^^}"
            cp -R build/db/db_init_scripts/${table}/* build/db/scripts_to_run/
            sleep 2;
    fi

    if [ "${ALERTING}" == 'TRUE' ]; then
            table=alerting
            echo "--${table^^}"
            cp -R build/db/db_init_scripts/${table}/* build/db/scripts_to_run/
            sleep 2;
    fi

    if [ "${API}" == 'TRUE' ]; then
            table=api
            echo "--${table^^}"
            cp -R build/db/db_init_scripts/${table}/* build/db/scripts_to_run/
            sleep 2;
    fi

    if [ "${GEO}" == 'TRUE' ]; then
            table=geo
            echo "--${table^^}"
            cp -R build/db/db_init_scripts/${table}/* build/db/scripts_to_run/
            sleep 2;
    fi

    if [ "${PAN}" == 'TRUE' ]; then
            table=pan
            echo "--${table^^}"
            cp -R build/db/db_init_scripts/${table}/* build/db/scripts_to_run/
            sleep 2;
    fi

    if [ "${SAR}" == 'TRUE' ]; then
            table=sar
            echo "--${table^^}"
            cp -R build/db/db_init_scripts/${table}/* build/db/scripts_to_run/
            sleep 2;
    fi

    if [ "${TESTING}" == 'TRUE' ]; then
            table=testing
            echo "--${table^^}"
            cp -R build/db/db_init_scripts/${table}/* build/db/scripts_to_run/
            sleep 2;
    fi

    if [ "${VMS}" == 'TRUE' ]; then
            table=vms
            echo "--${table^^}"
            cp -R build/db/db_init_scripts/${table}/* build/db/scripts_to_run/
            sleep 2;
    fi

}


# stop running container(s)
docker-compose down

#Clear old scripts
rm -R build/db/scripts_to_run/*

#Table selection
if [ "${ALL}" == 'TRUE' ];
    then
        echo "ALL tables selected."
        cp -R build/db/db_init_scripts/*/* build/db/scripts_to_run/.
        sleep 2;
else
    select_tables
fi

# rebuild and restart the container(s)
docker-compose up -d --build
docker-compose ps
docker-compose logs
