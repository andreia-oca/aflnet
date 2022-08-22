#!/bin/bash

# Common usage:
# ./coverage_collection.sh ./output cov_over_time.csv 1 1

folder=$1             # fuzzer result folder
covfile="$folder/$2"  # path to coverage file
step=$3               # step = 5 means we run gcovr after every 5 test cases
fmode=$4    # file mode -- structured or not
            # fmode = 0: the test case is a concatenated message sequence -- there is no message boundary - AFL
            # fmode = 1: the test case is a structured file keeping several request messages - AFLNET

WORKDIR="./fuzzquitto/src"

# Delete the existing coverage file
rm $covfile; touch $covfile

# Clear gcovr data
gcovr -r $WORKDIR/ -s -d > /dev/null 2>&1

# Output the header of the coverage file which is in the CSV format
# Time: timestamp, l_per/b_per and l_abs/b_abs: line/branch coverage in percentage and absolute number
echo "Time,l_per,l_abs,b_per,b_abs" >> $covfile

# Files stored in replayable-* folders are structured in such a way that messages are separated (AFLNET)
if [ $fmode -eq "1" ]; then
  testdir="replayable-queue"
  replayer="aflnet-replay"
else
  testdir="queue"
  replayer="afl-replay"
fi

# Process seed corpus first
for f in $(echo $folder/$testdir/*.raw); do 
  time=$(stat -c %Y $f)
    
  $replayer $f MQTT $pno 30 > /dev/null 2>&1 &
  timeout -k 0 -s SIGUSR1 3s ./fuzzquitto/src/mosquitto > /dev/null 2>&1
  
  wait
  cov_data=$(gcovr -r $WORKDIR/ -s | grep "[lb][a-z]*:")
  l_per=$(echo "$cov_data" | grep lines | cut -d" " -f2 | rev | cut -c2- | rev)
  l_abs=$(echo "$cov_data" | grep lines | cut -d" " -f3 | cut -c2-)
  b_per=$(echo "$cov_data" | grep branch | cut -d" " -f2 | rev | cut -c2- | rev)
  b_abs=$(echo "$cov_data" | grep branch | cut -d" " -f3 | cut -c2-)
  
  echo "$time,$l_per,$l_abs,$b_per,$b_abs" >> $covfile
done

# Process other testcases
count=0
for f in $(echo $folder/$testdir/id*); do 
  time=$(stat -c %Y $f)
  
  $replayer $f DTLS12 $pno 30 > /dev/null 2>&1 &
  timeout -k 0 -s SIGUSR1 3s ./fuzzquitto/src/mosquitto > /dev/null 2>&1

  wait
  count=$(expr $count + 1)
  rem=$(expr $count % $step)
  if [ "$rem" != "0" ]; then continue; fi
  cov_data=$(gcovr -r $WORKDIR/ -s | grep "[lb][a-z]*:")
  l_per=$(echo "$cov_data" | grep lines | cut -d" " -f2 | rev | cut -c2- | rev)
  l_abs=$(echo "$cov_data" | grep lines | cut -d" " -f3 | cut -c2-)
  b_per=$(echo "$cov_data" | grep branch | cut -d" " -f2 | rev | cut -c2- | rev)
  b_abs=$(echo "$cov_data" | grep branch | cut -d" " -f3 | cut -c2-)
  
  echo "$time,$l_per,$l_abs,$b_per,$b_abs" >> $covfile
done

# Last testcase(s) if step > 1
if [[ $step -gt 1 ]]
then
  time=$(stat -c %Y $f)
  cov_data=$(gcovr -r $WORKDIR/ -s | grep "[lb][a-z]*:")
  l_per=$(echo "$cov_data" | grep lines | cut -d" " -f2 | rev | cut -c2- | rev)
  l_abs=$(echo "$cov_data" | grep lines | cut -d" " -f3 | cut -c2-)
  b_per=$(echo "$cov_data" | grep branch | cut -d" " -f2 | rev | cut -c2- | rev)
  b_abs=$(echo "$cov_data" | grep branch | cut -d" " -f3 | cut -c2-)
  
  echo "$time,$l_per,$l_abs,$b_per,$b_abs" >> $covfile
fi
