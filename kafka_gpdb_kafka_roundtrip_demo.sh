#!/bin/bash

psql='psql --echo-all'

cls () {
  echo
  read -p "Press Enter to continue"
  printf "\033c"
}

# GPDB Version?
echo "SELECT VERSION()" | $psql
cls

echo "Load some data into Kafka"
time zcat ./chicago_crimes_10k_rows.csv.gz | tail -n +2 | $HOME/producer_example localhost:9092 chicago_crimes
cls

echo "Create the heap table"
cat <<EndOfSQL | $psql
-- DDL for the Chicago crimes data set
-- Ref. https://data.cityofchicago.org/Public-Safety/Crimes-2001-to-present/ijzp-q8t2/data
DROP TABLE IF EXISTS crimes;
CREATE TABLE crimes
(
  id INT
  , case_number VARCHAR (20)
  , crime_date TIMESTAMP
  , block VARCHAR(50)
  , IUCR VARCHAR(10)
  , primary_type VARCHAR(50)
  , description VARCHAR(75)
  , location_desc VARCHAR (75)
  , arrest BOOLEAN
  , domestic BOOLEAN
  , beat VARCHAR(7)
  , district VARCHAR(7)
  , ward SMALLINT
  , community_area VARCHAR(10)
  , fbi_code VARCHAR(5)
  , x_coord FLOAT
  , y_coord FLOAT
  , crime_year SMALLINT
  , record_update_date TIMESTAMP
  , latitude FLOAT
  , longitude FLOAT
  , location VARCHAR (60)
)
distributed by (id);
EndOfSQL
cls

echo "Create the readable external web table for the Kafka => GPDB phase"
cat <<EndOfSQL | $psql
-- External table for loading a small subset of the Chicago crimes data
DROP EXTERNAL TABLE IF EXISTS crimes_kafka;
CREATE EXTERNAL WEB TABLE crimes_kafka
(LIKE crimes)
EXECUTE '$HOME/go-kafkacat  --broker=localhost:9092 consume --group=GPDB_Consumer_Group chicago_crimes --eof 2>>$HOME/`printf "kafka_consumer_%02d.log" $GP_SEGMENT_ID`'
ON ALL FORMAT 'CSV' (DELIMITER ',' NULL '')
LOG ERRORS SEGMENT REJECT LIMIT 1 PERCENT;
EndOfSQL
cls

echo "Create the writable external web table for the GPDB => Kafka phase"
cat <<EndOfSQL | $psql
-- External table for dumping a small subset of the Chicago crimes data
DROP EXTERNAL TABLE IF EXISTS crimes_offload;
CREATE WRITABLE EXTERNAL WEB TABLE crimes_offload
(LIKE crimes)
EXECUTE '$HOME/producer_example localhost:9092 chicago_crimes 2>/dev/null 2>>$HOME/`printf "kafka_producer_%02d.log" $GP_SEGMENT_ID`'
FORMAT 'CSV' (DELIMITER ',' NULL '');
EndOfSQL
cls

load() {
echo "Load the heap table from the external table pointing to the Kafka topic"
cat <<EndOfSQL | $psql
INSERT INTO crimes SELECT * from crimes_kafka;
EndOfSQL
cls
}
load

query() {
echo "Run a couple of SELECTs against the heap table, get the count (expectation is 10k rows)"
cat <<EndOfSQL | $psql
SELECT * FROM crimes ORDER BY id ASC LIMIT 5;
SELECT COUNT(*) FROM crimes;
EndOfSQL
cls
}
query

echo "Put the data back into Kafka"
cat <<EndOfSQL | $psql
INSERT INTO crimes_offload SELECT * FROM crimes;
EndOfSQL
cls

echo "Truncate the crimes table"
cat <<EndOfSQL | $psql
TRUNCATE TABLE crimes;
EndOfSQL
cls

echo "Repeat the load and query steps"
load
query

drain() {
echo "Drain Kafka topic by running a SELECT against it"
cat <<EndOfSQL | $psql
SELECT COUNT(*) FROM crimes_kafka;
EndOfSQL
cls
}

