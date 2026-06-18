# Reproducible build environment for aWsm and the example pipeline.
#
# aWsm is pinned to the LLVM 12 C API (via the gwsystems/llvm-rs `sfbase` fork),
# and LLVM 12 has been dropped from apt.llvm.org for jammy/noble — so we build
# on Ubuntu 20.04 (focal) where LLVM 12 is a first-class apt package.
FROM ubuntu:26.04

ARG LLVM_VERSION=12
ARG RUST_VERSION=1.87.0
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
        build-essential cmake ca-certificates curl wget git pkg-config \
        gnupg lsb-release software-properties-common \
        wabt binaryen libuv1-dev libffi-dev \
        libc++-11-dev libc++abi-11-dev \
        clang-${LLVM_VERSION} \
        lld-${LLVM_VERSION} \
        llvm-${LLVM_VERSION} \
        llvm-${LLVM_VERSION}-dev \
        llvm-${LLVM_VERSION}-tools \
    && rm -rf /var/lib/apt/lists/*

# Point the default LLVM/clang names at the v12 binaries. The `llvm-alt` Rust
# crate calls `llvm-config` (unsuffixed) directly, so an unversioned name on
# PATH is required.
RUN update-alternatives --install /usr/bin/clang        clang        /usr/bin/clang-${LLVM_VERSION}        100 \
 && update-alternatives --install /usr/bin/clang++      clang++      /usr/bin/clang++-${LLVM_VERSION}      100 \
 && update-alternatives --install /usr/bin/llvm-config  llvm-config  /usr/bin/llvm-config-${LLVM_VERSION}  100 \
 && update-alternatives --install /usr/bin/llvm-dis     llvm-dis     /usr/bin/llvm-dis-${LLVM_VERSION}     100 \
 && update-alternatives --install /usr/bin/ld.lld       ld.lld       /usr/bin/lld-${LLVM_VERSION}          100 \
 && update-alternatives --install /usr/bin/lld          lld          /usr/bin/lld-${LLVM_VERSION}          100

# Install Rust via rustup (the Ubuntu 20.04 packaged rustc is too old).
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain ${RUST_VERSION} --profile minimal
ENV PATH=/root/.cargo/bin:${PATH}

WORKDIR /workspace
