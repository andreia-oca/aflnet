#!/bin/bash

timestamp=$(date +"%d-%m-%Y") 
mkdir output_$timestamp
mkdir coverage_information_$timestamp

# Start fuzzing campaing
afl-fuzz -d -i ./input -o ./output_$timestamp -N tcp://127.0.0.1/1883 -P MQTT -D 10000 -q 3 -s 3 -E -K -R -W 30 ./fuzzquitto/src/mosquitto

# Start script in background to collect code coverage information
# Pay attention to disk usage. One .json file can get up to 2 MB
# For a 24h fuzzing campaing with code coverage information dumoed every 10 minutes,
# we reach almost 300 MB of raw data.
./dump_coverage.sh &
