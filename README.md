This container uses the TimescaleDB HA container since that one has the latest version of PostGIS. 
To get the DB running you'll have to insert the required scripts (sorted by schema/data source) into the "scripts to run" folder. On first build these scripts get run in alphabetical order. 

To build all tables:
> git pull 
> rm build/db/scripts_to_run/* 
> cp build/db/db_init_scripts/*/* build/db/scripts_to_run/. 
> docker-compose up --build integrated_db  
