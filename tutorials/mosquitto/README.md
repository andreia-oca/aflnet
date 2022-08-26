# Tutorial - Fuzzing an MQTT Broker

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [Build AFLNET](#build-aflnet)
- [Targets](#targets)
  - [Mosquitto](#mosquitto)
    - [Build Mosquitto Locally](#build-mosquitto-locally)
    - [Build Mosquitto for Fuzzing](#build-mosquitto-for-fuzzing)
  - [Fuzzquitto](#fuzzquitto)
  - [NanoMQ](#nanomq)
- [Start a Fuzzing Campaign](#start-a-fuzzing-campaign)
  - [Create a Seed Corpus](#create-a-seed-corpus)
  - [Start a Fuzzing Campaign Locally](#start-a-fuzzing-campaign-locally)
  - [Start a Fuzzing Campaign Remotely](#start-a-fuzzing-campaign-remotely)
- [Code Coverage](#code-coverage)
  - [Code Coverage Analysis](#code-coverage-analysis)
  - [Code Coverage Analysis in Jupyter Notebooks](#code-coverage-analysis-in-jupyter-notebooks)
- [Crashes](#crashes)
  - [Replay Testcases with `aflnet-replay`](#replay-testcases-with-aflnet-replay)
  - [Injected Vulnerabilities](#injected-vulnerabilities)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Build AFLNET

Check AFLNET [guide](https://github.com/aflnet/aflnet#installation-tested-on-ubuntu-1804--1604-64-bit) to install and test it.

## Targets

### Mosquitto

Eclipse Mosquitto - an open source MQTT broker written in C ([repository](https://github.com/eclipse/mosquitto) | [documentation](https://mosquitto.org/)).

#### Build Mosquitto Locally

This section describer how to test the broker features locally before any fuzzing campaign.

The most important configs are:
 - `config.mk` that exposes different configuration for compiling Mosquitto
 - `mosquitto.conf` that is a configuration file used during runtime

Install dependencies:
```bash 
sudo apt install libcjson1 libcjson-dev libssl-dev docbook-xsl docbook xsltproc
```

Clone and compile `mosquitto`:
```bash
git clone https://github.com/eclipse/mosquitto
cd mosquitto
# For minimal installation, do not generate `man` pages
make all WITH_DOCS=no
```

Run `mosquitto`:
```bash
cd ./mosquitto/src/
./mosquitto
# For custom configuration create a custom `mosquitto.conf` and run:
./mosquitto -c mosquitto.conf
```

Create clients to test the broker:
```bash
sudo apt install -y mosquitto-clients
mosquitto_sub -h localhost -t sensor/temperature 
mosquitto_pub -h localhost -t sensor/temperature 27
```

#### Build Mosquitto for Fuzzing

1. The source code must be compiled with `gcov` binds to display code coverage.

For a persistent configuration, open `config.mk` and change these lines:

```
# Build with coverage options
WITH_COVERAGE:=yes
```

Or run the following command:
``` bash
sed -i 's/WITH_COVERAGE:=no/WITH_COVERAGE:=yes/g' config.mk
```

2. The source code must be compiled with AFL instrumentation - the compiler `afl-gcc` will take care of that.

```bash
CC=afl-gcc make clean all WITH_TLS=no WITH_STATIC_LIBRARIES=yes WITH_COVERAGE=yes WITH_DOCS=no
```

3. To yield more discrete crashes or errors (suchs as memory leaks) during the fuzzing, compile your target with ASan. Pay attention that ASan will slow down the execution per seconds.

```bash
export AFL_USE_ASAN=1

CC=afl-gcc CFLAGS="-g -O0 -fsanitize=address -fno-omit-frame-pointer" LDFLAGS="-g -O0 -fsanitize=address -fno-omit-frame-pointer" \
make clean all WITH_TLS=no WITH_STATIC_LIBRARIES=yes WITH_COVERAGE=yes WITH_DOCS=no
```

### Fuzzquitto

Fuzzquitto is a forked version of Mosquitto that is more suitable to fuzzing ([repository](https://github.com/andreia-oca/fuzzquitto)):
 * is compiled with code coverage instrumentation by default
 * features a handler to extract code coverage information at runtime (via signals)
 * compiled it with `afl-gcc`: `CC=afl-gcc make clean all` for instrumentation 

### NanoMQ

An ultra-lightweight and blazing-fast MQTT broker for IoT edge ([repository](https://github.com/emqx/nanomq) | [documentation](https://nanomq.io/)).

Not tested yet.

## Start a Fuzzing Campaign

### Create a Seed Corpus

The workflow below is also described on [AFLNET README](https://github.com/aflnet/aflnet#step-1-prepare-message-sequences-as-seed-inputs).

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

***Note:*** We already provide different raw MQTT messages that can be used as a seed corpus:
 - just for fuzzing in subscriber mode (see `tutorials/mosquitto/input_subscriber`)
 - just for fuzzing in publisher mode (see `tutorials/mosquitto/input_publisher`)
 - an extended corpus imported from [mqtt-fuzz](https://github.com/F-Secure/mqtt_fuzz/tree/master/valid-cases) (see `tutorials/mosquitto/input_mqtt_fuzz`).

### Start a Fuzzing Campaign Locally

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
# To fuzz Fuzzquitto
afl-fuzz -d -i ./input -o ./output_tmp -N tcp://127.0.0.1/1883 -P MQTT -D 10000 -q 3 -s 3 -E -K -R -W 30 ./fuzzquitto/src/mosquitto 
# To fuzz Mosquitto
afl-fuzz -d -i ./input -o ./output -N tcp://127.0.0.1/1883 -P MQTT -D 10000 -q 3 -s 3 -E -K -R -W 30 ./mosquitto/src/mosquitto 
```

For fuzzing with ASan on:
```bash
# To fuzz Fuzzquitto
afl-fuzz -m none -d -i ./input -o ./output_tmp -N tcp://127.0.0.1/1883 -P MQTT -D 10000 -q 3 -s 3 -E -K -R -W 30 ./fuzzquitto/src/mosquitto 
# To fuzz Mosquitto
afl-fuzz -m none -d -i ./input -o ./output_tmp -N tcp://127.0.0.1/1883 -P MQTT -D 10000 -q 3 -s 3 -E -K -R -W 30 ./mosquitto/src/mosquitto 
```

Note: It is recommended to add the timestamp in the name of the output directory - `output_dd_mm_yyyy_hh_mm` (e.g. `output_12_07_2022_17_30`) for analysing data further along the road.

### Start a Fuzzing Campaign Remotely

Before starting a fuzzing campaing run the following commands on the **host system** to stop AFL from complaining:
```bash
sudo su
echo core > /proc/sys/kernel/core_pattern
cd /sys/devices/system/cpu
echo performance | tee cpu*/cpufreq/scaling_governor
```

Build the docker image and spin-up a docker container:
```bash
docker image build -f Dockerfile -t aflnet_mqtt:latest . 
docker run -it --name aflnet_mqtt_test aflnet_mqtt:latest /bin/bash
```

(Optional) To reattach to a docker container already created, run:
```bash
docker start aflnet_mqtt_test
docker exec -it aflnet_mqtt_test /bin/bash
```

## Code Coverage

### Code Coverage Analysis

Show a code coverage summary (on lines or branches):

```bash
gcovr -r ./fuzzquitto/src -s | grep "[lb][a-z]*:"
```

Note:\\
Use `gcovr` to create JSON coverage reports (for more details check the [documentation](https://gcovr.com/en/stable/getting-started.html):
```bash
# Examples
gcovr --json-summary-pretty --json-summary --exclude-unreachable-branches --exclude-throw-branches --root mosquitto/src/ --output coverage.json
```

Display code coverage information in an HTML page:\\
```bash
gcovr -r ./fuzzquitto/src --html --html-details -o index.html
```

Clean `gcovr` temporary runtime files:\\
```bash
gcovr -r ./fuzzquitto/src -s -d > /dev/null 2>&1
``` 

`coverage_analysis.sh` is a tool that will replay every interesting path that AFLNET found and saved in `replayable-queue` or `queue`.

The script will generate a `.csv` file with coverage information expressed as number of lines of branches executed per target.

The scripts gets the following arguments:
- the output directory name that was creating during the last fuzzing campaign
- a name for the resulting `.csv` file 
- a step counter, i.e., for a step = 5 `gcovr` will collect coverage information every 5 testcases
- the file mode, i.e. for fmode = 0 the testcase is a concatenated message sequence - AFL mode; for fmode = 1 the test case is a structured file keeping several request messages - AFLNET mode

An example to run the script:
```bash
./coverage_analysis.sh ./output cov_over_time.csv 1 1
```

### Code Coverage Analysis in Jupyter Notebooks

To replay all the found paths and get the coverage information from each, one can use the script `coverage_analysis.sh` as follows:
```bash
# ./coverage_analysis.sh <aflnet_output_folder> <output_file> <step> <mode>
./coverage_analysis.sh output cov_over_time.csv 1 1
```

Next the raw code coverage information will be analyzes in Jupyter Notebooks using `pandas` and `matplotlib` in `notebooks/`.

## Crashes

### Replay Testcases with `aflnet-replay`

For debugging purposes, one can use the replay features of AFLNET `aflnet-replay` and `afl-replay`.
 - `afl-replay` sends the whole testcase as a single data package
 - `aflnet-replay` sends the data packages structured. During the fuzzing campaign, AFLNET breaks the testcases into sequences that make sense for the protocol. This sequences can be found in `replayable-queue` dumped as tuples of (sequence_size, sequence). Furthermore, for debugging, one can check the `regions` folder to see the start byte and end byte of each sequence that was parsed by AFLNET from each testcase.

To replay a certain testcase, one has to open 2 terminals.

Terminal 1:\\
```bash
# Make sure that the MQTT broker will exit in a clean way (SIGINT is caught by Mosquitto and exists gracefully)
timeout -k 0 -s SIGINT 3s ./fuzzquitto/src/mosquitto 
```

Terminal 2:\\
```bash
aflnet-replay output/replayable-queueu/id:000004,src:000000,op:flip1,pos:0,+cov MQTT 1883 30
```

`aflnet-replay` is going to show some logs to stderr about the requests sent, the response and, also, the state machine constructed based on the interaction with the server.

Below, one can see an output example from `aflnet-replay`

```
Size of the current packet 1 is  2
request::0x10 0x23 0xf0 

Size of the current packet 2 is  37
request::0x00 0x04 0x4d 0x51 0x54 0x54 0x04 0x02 0x00 0x3c 0x00 0x17 0x6d 0x6f 0x73 0x71 0x2d 0x43 0x5a 0x4a 0x75 0x6e 0x39 0x61 0x32 0x38 0x77 0x39 0x66 0x56 0x33 0x52 0x64 0x4f 0x47 0x82 0x0e 0xf0 

Size of the current packet 3 is  16
request::0x00 0x01 0x00 0x09 0x74 0x65 0x73 0x74 0x2f 0x74 0x65 0x6d 0x70 0x00 0xc0 0x00 0xf0 

Size of the current packet 4 is  2
request::0xc0 0x00 0xf0 

Size of the current packet 5 is  2
request::0xc0 0x00 0xf0 

--------------------------------
Responses from server:0x00-0x20-0x90-0xd0-0xd0-
++++++++++++++++++++++++++++++++
Responses in details:
Size of reponse buf 15
response_buf::0x20 0x02 0x00 0x00 0x90 0x03 0x00 0x01 0x00 0xd0 0x00 0xd0 0x00 0xd0 0x00 0x00 

-------------------------------
```

Note: One can also send messages directly to the broker with `netcat`. To yield more results, make sure that mosquitto was compiled with ASan.
```bash
nc 127.0.0.1 1883 < output/replayable-queueu/id:000004,src:000000,op:flip1,pos:0,+cov | xxd
```

### Injected Vulnerabilities

We injected a null pointer derefence into a frequently exercised path of Mosquitto. This approach yields almost instant crashes with AFLNET.

To test yourself, execute the following commands:
```bash
cd tutorials/mosquitto
cp inject_bug.patch ./mosquitto/ && cd ./mosquitto

git apply inject_bug.patch

# Re-compile Mosquitto with ASan on, CODE_COVERAGE on, no DOCS
CC=afl-gcc CFLAGS="-g -O0 -fsanitize=address -fno-omit-frame-pointer" LDFLAGS="-g -O0 -fsanitize=address -fno-omit-frame-pointer" \
make clean all WITH_TLS=no WITH_STATIC_LIBRARIES=yes WITH_COVERAGE=yes WITH_DOCS=no

cd ../

# Start a fuzzing campaign
afl-fuzz -m none -d -i ./input -o ./output_tmp -N tcp://127.0.0.1/1883 -P MQTT -D 10000 -q 3 -s 3 -E -K -R -W 30 ./mosquitto/src/mosquitto 
```
