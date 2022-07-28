FROM ubuntu:20.04

ENV DEBIAN_FRONTEND="noninteractive"

# Install common dependencies
RUN apt-get -y update && \
	apt-get -y upgrade && \
    apt-get install -y apt-utils && \
    apt-get install -y tzdata && \
    echo 'tzdata tzdata/Areas select Europe' | debconf-set-selections && \
    echo 'tzdata tzdata/Zones/Europe select Paris' | debconf-set-selections

# Packages installed for minimal installation of AFLNET and Mosquitto
RUN apt-get -y install build-essential clang graphviz-dev git cmake llvm \
    libcjson1 libcjson-dev libssl-dev mosquitto-clients

# Packages installed for a full installation of Mosquitto (including `man` pages)
# If you want to generate `man` pages, uncomment the line below
# RUN apt-get -y install docbook-xsl docbook xsltproc

# Packages used for debugging (thiese are optional in a prod env)
# If you are using this container for debugging uncomment the line below
# RUN apt-get -y install curl wget vim tmux net-tools host

# Packages used for code coverage reports
RUN apt-get -y install python3-pip
RUN python3 -m pip install gcovr

# Switch to non-privileged user
# `mosquitto` is the default user in the `mosquitto.conf` file
ENV UID=1000
ENV GID=1000
ENV USER=mosquitto
ENV PASSWD=mosquitto

RUN useradd -m ${USER} --uid=${UID} && echo "${USER}:${PASSWD}" | chpasswd

USER mosquitto
WORKDIR /home/${USER}

ENV LLVM_CONFIG="llvm-config-10"

# Download and compile AFLNET
RUN git clone https://github.com/andreia-oca/aflnet-mqtt-support --recursive ./aflnet

RUN cd aflnet && \
    make clean all && \
    cd llvm_mode && make

# Set up environment variables for AFLNET
ENV AFLNET="/home/${USER}/aflnet"
ENV WORKDIR="/home/${USER}"
ENV PATH="${PATH}:${AFLNET}"
ENV AFL_PATH="${AFLNET}"

# Clone and compile (minimal) Fuzzquitto
RUN cd aflnet && \
    git submodule update --init --recursive && \
    cd tutorials/mosquitto/fuzzquitto && \
    CC=afl-gcc make clean all

# Clone and compile (minimal) Mosquitto
# If you want to generate `man` pages, remove the line that sets WITH_DOCS:=no
# RUN cd aflnet && \
#     git submodule update --init --recursive && \
#     cd tutorials/mosquitto/mosquitto && \
#     sed -i 's/WITH_COVERAGE:=no/WITH_COVERAGE:=yes/g' config.mk && \
#     sed -i 's/WITH_DOCS:=yes/WITH_DOCS:=no/g' config.mk && \
#     CC=afl-gcc make clean all
