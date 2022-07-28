#!/bin/bash

# Dump coverage information forcefully. 
# This is not necessary during a fuzzing campaign because AFL is killing the server very often.
# kill -SIGUSR2 $(pidof ./mosquitto)

timestamp=$(date +"%d-%m-%Y")

while true
do
    gcovr --json --root fuzzquitto/src --output coverage_information_$timestamp/raw_coverage_$(date +"%d-%m-%Y-%H-%M-%S").json
sleep 10m
done

# gcovr --exclude-unreachable-branches --exclude-throw-branches \
#     --exclude-function-lines --json --root fuzzquitto/src --output coverage_information/raw_coverage_$(date +"%d-%m-%Y-%H-%M-%S").json
