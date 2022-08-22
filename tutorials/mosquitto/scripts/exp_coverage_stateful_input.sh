#!/bin/bash

# Coverage script for stateless fuzzing with AFLNET
# This is only done for the seed corpus to create a comparative graph between 
# code coverage using only the initial test cases and during the actual fuzzing campaign 

# There are 2 possible initial datasets of input:
# - a small custom one 
# - the one used by mqtt_fuzz which has more recorded MQTT messagges 

# Change the input folder accordingly
# input="input"
input="input_mqtt_fuzz"

folder="output_baseline"
mkdir $folder

# Use the stateless
output="output_29-07-2022"
testdir="replayable-queue"
replayer="../../aflnet-replay"

covfile="$folder/cov_over_time_stateful_$input.csv"

rm $covfile; touch $covfile

echo "Time,l_per,l_abs,b_per,b_abs" >> $covfile

gcovr -r ./fuzzquitto/src/ -s -d > /dev/null 2>&1

for f in $(echo $output/$testdir/*.raw); do 
  time=$(stat -c %Y $f)
    
  $replayer $f MQTT 1883 30 > /dev/null 2>&1 &
  timeout -k 0 -s SIGINT 3s ./fuzzquitto/src/mosquitto > /dev/null 2>&1
  
  wait
  cov_data=$(gcovr -r ./fuzzquitto/src -s | grep "[lb][a-z]*:")
  l_per=$(echo "$cov_data" | grep lines | cut -d" " -f2 | rev | cut -c2- | rev)
  l_abs=$(echo "$cov_data" | grep lines | cut -d" " -f3 | cut -c2-)
  b_per=$(echo "$cov_data" | grep branch | cut -d" " -f2 | rev | cut -c2- | rev)
  b_abs=$(echo "$cov_data" | grep branch | cut -d" " -f3 | cut -c2-)
  
  echo "$time,$l_per,$l_abs,$b_per,$b_abs" >> $covfile
done
