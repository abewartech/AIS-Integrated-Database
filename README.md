# Integrated DB

This container uses the TimescaleDB HA container since that one has the latest version of PostGIS.

To get the DB running you'll have to insert the required scripts (sorted by schema/data source) into the "scripts to run" folder. On first build these scripts get run in alphabetical order.

To build all tables:

        git pull
        rm build/db/scripts_to_run/*
        cp build/db/db_init_scripts/*/* build/db/scripts_to_run/.
        docker-compose up --build integrated_db

Examples here [http://146.64.19.189:12001/foreign_flag_fishing](http://146.64.19.189:12001/foreign_flag_fishing).

build the DB, build the API, and run some dummy queries to get going.

Test it out via the following steps.

* Clone project and switch to the directory:

        git clone https://gitlab.com/eosit/integrated-database
        cd integrated-database
* Move (and/or edit) the example config file ./config/sampl2.env to the project base dir:

        cp ./config/sample2.env ./.env
* Move the files for the schema's you want to build. I've commented out the BIG one (2_2_loaf_shapes.sh) that downloads and pulls all the shapefiles but feel free to uncomment it again if you want:

        cp ./build/db/db_init_scripts/*/* ./build/db/scripts_to_run/.
* Start-up:

        docker-compose build
        docker-compose up -d
* When complete, open "your_machine:12001" in a browser to see the API in action. 
 

  Current API endpoints are:

* /tasks - Returns a lists of users and the reports that they require
* /report_fff - Returns a list of foreign flag fishing vessels in RSA waters over the last 24h
* /alert_data_sources - Returns the datasources that have had no new inputs within 2h
