# Tutorial - Fuzzing an MQTT Broker

## Install and test AFLNET
Check AFLNET [guide](https://github.com/aflnet/aflnet#installation-tested-on-ubuntu-1804--1604-64-bit) to install and test it.

## Install and test Mosquitto locally (with no instrumentation)

Install dependencies:
```bash 
sudo apt install libcjson1 libcjson-dev libssl-dev docbook-xsl docbook xsltproc
```

Clone and compile `mosquitto`:\\
```bash
git clone https://github.com/eclipse/mosquitto
cd mosquitto
# For minimal installation, do not generate `man` pages
sed -i 's/WITH_DOCS:=yes/WITH_DOCS:=no' config.mk
make all
```

Run `mosquitto`:\\
```bash
cd ./mosquitto/src/
./mosquitto
# For custom configuration create a custom `mosquitto.conf` and run:
./mosquitto -c mosquitto.conf
```

Create clients to test the broker:\\
```bash
sudo apt install -y mosquitto-clients
mosquitto_sub -h localhost -t sensor/temperature 
mosquitto_pub -h localhost -t sensor/temperature 27
```

# Prepare target (Mosquitto) for fuzzing

1. The source code must be compiled with `gcov` binds to display code coverage.

Open `config.mk` and change these lines:

```
# Build with coverage options
WITH_COVERAGE:=yes
```

Or run the following command:
``` bash
sed -i 's/WITH_COVERAGE:=no/WITH_COVERAGE:=yes/g' config.mk
```

2. The source code must be compiled with AFL instrumentation.

```bash
CC=afl-gcc make clean all
```

3. Compile it with ASan:
```bash
export AFL_USE_ASAN=1

CC=afl-gcc CFLAGS="-g -O0 -fsanitize=address -fno-omit-frame-pointer" LDFLAGS="-g -O0 -fsanitize=address -fno-omit-frame-pointer" \
make clean all WITH_TLS=no WITH_STATIC_LIBRARIES=yes WITH_COVERAGE=yes
```

# Introduction to Fuzzquitto

Fuzzquitto is a forked version of Mosquitto that is more suitable to fuzzing:
 * is compiled with code coverage instrumentation by default
 * features a handler to extract code coverage information at runtime
 * compiled it with `afl-gcc`: `CC=afl-gcc make clean all` 

# Start a fuzzing campaign

## Create a seed corpus

1. Start mosquitto - the broker (with the default port - 1883) 

```bash
# Compiled from sources
cd aflnet/tutorials/mosquitto/mosquitto/src
./mosquitto
```

2. Start `wireshark` and capture on `loopback/localhost`.

3. Connect a publisher/subscriber to it.

```
# Subscriber
mosquitto_sub -h localhost -t test/temp
# Publisher
mosquitto_pub -h localhost -t test/temp -m 30
```

4. Filter MQTT messages, follow TCP Stream and select incoming traffic from the clients to the broker (i.e. random assigned port -> 1883).

5. Save captured packages as `.raw`.

6. Save all the interesting packages into an `input` directory.

## Our seed corpora

We have privded different seed corpora:
 - just for fuzzing in subscriber mode
 - just for fuzzing in publisher mode
 - the extended corpus imported from [mqtt-fuzz](https://github.com/F-Secure/mqtt_fuzz/tree/master/valid-cases).

## Start the fuzzing campaign on your local machine

Before starting a fuzzing campaing run the following commands to stop AFL from complaining:
```bash
sudo su
echo core >/proc/sys/kernel/core_pattern
cd /sys/devices/system/cpu
echo performance | tee cpu*/cpufreq/scaling_governor
```

To start the fuzzing campaign, you have to first start `mosquitto` and then run the fuzzer:
```bash
cd tutorial/mosquitto
afl-fuzz -d -i ./input -o ./output_tmp -N tcp://127.0.0.1/1883 -P MQTT -D 10000 -q 3 -s 3 -E -K -R -W 30 ./fuzzquitto/src/mosquitto 
```

For fuzzing with ASan on:
```bash
afl-fuzz -m none -d -i ./input -o ./output_tmp -N tcp://127.0.0.1/1883 -P MQTT -D 10000 -q 3 -s 3 -E -K -R -W 30 ./fuzzquitto/src/mosquitto 
```

Note: It is recommended to add the timestamp in name of the output directory - `output_dd_mm_yyyy_hh_mm` (e.g. `output_12_07_2022_17_30`)

## Start the fuzzing campaign remotely using `Docker`

Before starting a fuzzing campaing run the following commands on the **host system** to stop AFL from complaining:
```bash
sudo su
echo core > /proc/sys/kernel/core_pattern
cd /sys/devices/system/cpu
echo performance | tee cpu*/cpufreq/scaling_governor
```

Build the docker image and spin-up a docker container:
```bash
docker image build -f Dockerfile -t aflnet_mqtt_dev:latest . 
docker run -it --name aflnet_mqtt_test aflnet_mqtt_dev:latest /bin/bash
```

(Optional) To reattach to a docker container already created, run:
```bash
docker start aflnet_mqtt_test
docker exec -it aflnet_mqtt_test /bin/bash
```

# Code coverage

## How to check code coverage

Show code coverage percentage for lines and branches:

```bash
gcovr -r ./fuzzquitto/src -s | grep "[lb][a-z]*:"
```

Note:\\
Use `gcovr` to create coverage reports (for more details check the [documentation](https://gcovr.com/en/stable/getting-started.html):
```bash
# Examples
gcovr --json-summary-pretty --json-summary --exclude-unreachable-branches --exclude-throw-branches --root mosquitto/src/ --output coverage.json
```

Display code coverage information in an .html page:\\
```bash
gcovr -r ./fuzzquitto/src --html --html-details -o index.html
```

Clean `gcovr` temporary runtime files:\\
```bash
gcovr -r ./fuzzquitto/src -s -d > /dev/null 2>&1
``` 

## Replay testcases/crashes with `aflnet-replay` or `afl-replay`

For debugging purposes, one can use the replay features of AFLNET `aflnet-replay` and `afl-replay`.
 - `afl-replay` sends the whole testcase as a single package
 - `aflnet-replay` sends the packages structured. During the fuzzing campaign, AFLNET breaks the testcases into sequences that make sense for the protocol. This sequences can be found in `replayable-queue` dumped as tuples of (sequence_size, sequence). Furthermore, for debugging, one can check the `regions` folder to see the start byte and end byte of each sequence that was parsed by AFLNET from each testcase.

To replay a certain testcase, one has to open 2 terminals.

Terminal 1:\\
```bash
# Make sure that the MQTT broker will exit in a clean way (SIGINT is caught by Mosquitto design and exists gracefully)
timeout -k 0 -s SIGINT 3s .fuzzquitto/src/mosquitto 
```

Terminal 2:\\
```bash
aflnet-replay output/replayable-queueu/id:000004,src:000000,op:flip1,pos:0,+cov MQTT 1883 30
```

`aflnet-replay` is going to show some logs to stderr about the requests sent, the response and, also, the state machine constructed based on the interaction with the server.

Note: One can also send messages directly to the broker with `netcat`. To yield more results, make sure that mosquitto was compiled with ASan.
```bash
nc 127.0.0.1 1883 < output/replayable-queueu/id:000004,src:000000,op:flip1,pos:0,+cov
```

## Code coverage analysis in Jupyter notebook

To replay all the found paths and get the coverage information from each, one can use the script `coverage_analysis.sh` as follows:
```bash
# ./coverage_analysis.sh <aflnet_output_folder> <output_file> <step> <mode>
./coverage_analysis.sh output cov_over_time.csv 1 1
```

Next the raw code coverage information will be analyzes in Jupyter Notebooks using `pandas` and `matplotlib`.
