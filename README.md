---
# Hugo Key Value pairs 
title: Integrated Database
comments: false
weight: 10
---

The databased used by the OpenAIS system is a Postgres system with [PostGIS](https://postgis.net/) and [TimeScaleDB](https://www.timescale.com/) extensions enabled. This makes use of the [TimescaleDB HA docker image](https://hub.docker.com/r/timescale/timescaledb-ha/tags), since it has the newer version of PostGIS , while extending it with custom scripts to automatically setup the database schema and initialise it with some extra datasets.

The initialising scripts are held in the [./build/db_init_scripts](https://gitlab.com/openais/processing/integrated-database/-/tree/master/build/db_init_scripts) directory while extra data files, mostly AIS protocol definitions are held in [./build/db_init_data](https://gitlab.com/openais/processing/integrated-database/-/tree/master/build/db_init_data). These folders are mounted into a location where a [new DB will run them upon first boot](https://github.com/docker-library/docs/blob/master/postgres/README.md#initialization-scripts). This allows for the quick deployment of new databases for development purposes. 

The database image is built, using a Gitlab Pipeline, and stored [here](https://gitlab.com/openais/processing/integrated-database/container_registry/6055643). Check which tags are available and pull the desired one. 

## Schema
  - AIS: Contains AIS position and voyage reports as well as AIS derived data
  - Geo: Contains geographical tables representing maritime objects like ocean boundaries, port locations, grids to use in areas of interest
  - TimescaleDB: There are multiple internal schemas generated by the TimescaleDB plugin. It’s best to leave these alone…
  - PostgisFTW: This is the default schema that exposes functions and collections to the web, via a rest API managed by Pg_Featureserv.

# Deployment
The deployment of the AIS database, along with tools to support it, is described [here](https://gitlab.com/openais/deployment/data-services) or [here](https://open-ais.org/quick-start/3/). It is not expected to deploy from this repository for production purposes but it might be useful for local development

## Running this locally without all the extra bits
Test it out via the following steps.

* Clone project and switch to the directory:
        `git clone https://gitlab.com/eosit/integrated-database` and `cd integrated-database`
* Move (and/or edit) the example config file `./config/dev.env` to the project base dir:
        `cp ./config/sample2.env .env`
* Start-up:
        `docker-compose build`
        `docker-compose up -d`
* When complete, open "localhost:8080" in a browser to see the API in action. 

# API
The API used in the Docker-Compose file
What API endpoints exist?

# Upgrading Existing Databases
How is this done? 

# Backups
How is this done? 
I know PostGres docker images generally have a backup tool. 
