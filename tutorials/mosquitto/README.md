# Tutorial - Fuzzing an MQTT Broker

# Misc

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

```
CC=afl-gcc make clean all
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
./mosquitto/src/mosquitto &
afl-fuzz -d -i ./input -o ./output_tmp -N tcp://127.0.0.1/1883 -P MQTT -D 10000 -q 3 -s 3 -E -K -R -W 30 ./mosquitto/src/mosquitto 
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

Start the fuzzing campaign using the following command:
```bash
afl-fuzz -d -i ./input -o ./output_tmp -N tcp://127.0.0.1/1883 -P MQTT -D 10000 -q 3 -s 3 -E -K -R -W 30 ./mosquitto/src/mosquitto
```

# Code coverage

## How to check code coverage

Show code coverage percentage:\\
```bash
cd mosquitto/src
# For a specific file
gcov mosquitto.c
# For all the source code files
gcov *.c
```

Use `gcovr` to create coverage reports (for more details check the [documentation](https://gcovr.com/en/stable/getting-started.html):
```bash
# Examples
gcovr --json-summary-pretty --json-summary --exclude-unreachable-branches --exclude-throw-branches --root mosquitto/src/
```

Display code coverage information in an .html page:\\
```bash
# [Optional] Run baseline for lcov 
lcov --no-external --capture --initial --directory ./mosquitto/src --output-file ./coverage_baseline.info

# Run lcov
lcov --no-external --capture --directory ./mosquitto/src --output-file ./coverage.info

# [Optional] If baseline was created
lcov --add-tracefile ./coverage_baseline.info --add-tracefile ./coverage_test.info --output-file ./coverage.info

# Generate .html files
genhtml --legend --title "Fuzzing MQTT" --output-drectory=coverage ./coverage.info
```

Clean `gcov` temporary runtime files:\\
```bash
cd mosquitto/src
rm -rf *.gcda
``` 

## Code coverage scripts

TODO

# Crashes triage

## Replay crashes with `afl-replay`

TODO
