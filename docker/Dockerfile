FROM ubuntu:18.04

WORKDIR /root/

# Install common dependencies
RUN apt-get -y update && \
    apt-get -y install apt-utils build-essential openssl \
    clang graphviz-dev git curl wget cmake llvm

# Download and compile AFLNet
ENV LLVM_CONFIG="llvm-config-6.0"

RUN git clone https://github.com/aflnet/aflnet && \
    cd aflnet && \
    make clean all && \
    cd llvm_mode make && make

# Set up environment variables for AFLNet
ENV AFLNET="/root/aflnet"
ENV WORKDIR="/root"
ENV PATH="${PATH}:${AFLNET}"
ENV AFL_PATH="${AFLNET}"

# Add commands to fuzz your target below
