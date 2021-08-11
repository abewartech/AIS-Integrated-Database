# Integrated DB

This container uses the TimescaleDB HA container since that one has the latest version of PostGIS.
To get the DB running you'll have to insert the required scripts (sorted by schema/data source) into the "scripts to run" folder. On first build these scripts get run in alphabetical order.

To build all tables:

> git pull
> rm build/db/scripts_to_run/*
> cp build/db/db_init_scripts/*/* build/db/scripts_to_run/.
> docker-compose up --build integrated_db

Examples here [http://146.64.19.189:12001/foreign_flag_fishing](http://pta-smg3.csir.co.za:32224/?dmVyPTEuMDAxJiY3MDdmMWQ2OGU4ZTI3ZTc0Nj02MTEzOTIyOF85MjM4OF8yMjU2XzEmJjQxNWE3NGUwYjY4M2ZiNz0xMzMzJiZ1cmw9aHR0cCUzQSUyRiUyRjE0NiUyRTY0JTJFMTklMkUxODklM0ExMjAwMSUyRmZvcmVpZ24lNUZmbGFnJTVGZmlzaGluZw==).

build the DB, build the API, and run some dummy queries to get going.

Check it out:

* Clone project from [https://gitlab.com/eosit/integrated-database](http://pta-smg3.csir.co.za:32224/?dmVyPTEuMDAxJiYzMTIzMGEzNGJkYTAyNTMwNz02MTEzOTIyOF85MjM4OF8yMjU2XzEmJmI0ZGU2NWMwMTdkMjhiZj0xMzMzJiZ1cmw9aHR0cHMlM0ElMkYlMkZnaXRsYWIlMkVjb20lMkZlb3NpdCUyRmludGVncmF0ZWQtZGF0YWJhc2U=)
* Move (and/or edit) the example config file ./config/sampl2.env to the project base dir: "> mv /config/sample2.env ./.env"
* Move the files for the schema's you want to build. I've commented out the BIG one (2_2_loaf_shapes.sh) that downloads and pulls all the shapefiles but feel free to uncomment it again if you want.
* > mv ./build/db/db_init_scripts/*/* ./build/db/scripts_to_run/.
  >
* > docker-compose up
  >
* wait for the build to finish.
* go to "your_machine:12001" to see the API in action. Some nice ones are "tasks" that show the tasks/alerts/reports that need to be generated for each user and "foreign_flag_fishing" that pulls a dummy table for daily fishing reports
