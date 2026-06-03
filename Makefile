# Wrapper Makefile around aWsm — compiles a .wat WebAssembly module into a
# native, sandboxed binary by linking it against the aWsm C runtime.
#
# Pipeline (each step is a separate target so you can stop after any of them):
#
#     foo.wat  --wat2wasm-->  foo.wasm  --aWsm-->  foo.bc  --clang-->  foo.awsm
#                                                   |
#                                                   +-llvm-dis-> foo.ll (optional)
#
# Quick start:
#     make help          # list targets
#     make run           # build + run the bundled `armstrong` example
#     make docker-run    # same, but inside the pinned Ubuntu 20.04 / LLVM 12 container

# ---------------------------------------------------------------------------
# Toolchain — every variable is overridable on the command line, e.g.
#     make CC=clang-12 LLVM_DIS=llvm-dis-12 build
# ---------------------------------------------------------------------------
AWSMCC      ?= aWsm/target/release/awsm
# `:=` (not `?=`) on `CC` so we override Make's built-in `CC = cc`. Command-line
# `make CC=...` still wins over `:=`, so callers can swap in a different clang.
CC          := clang
LLVM_DIS    ?= llvm-dis
WAT2WASM    ?= wat2wasm

# `-flto` is what makes clang accept aWsm's .bc bitcode at link time;
# `-fuse-ld=lld` swaps in LLD because GNU ld doesn't understand bitcode.
CFLAGS      := -O3 -flto
LDFLAGS     := -flto -fuse-ld=lld

# Default target triple for the bitcode aWsm produces. Without an explicit
# --target the bitcode omits both the triple and the data layout, and LLD
# then refuses to link it ("input module has no datalayout").
AWSM_TARGET ?= x86_64-pc-linux-gnu

# `--inline-constant-globals`: fold module-level constant globals into uses.
AWSMFLAGS   ?= --inline-constant-globals --target=$(AWSM_TARGET)

RUNTIME_PATH     := aWsm/runtime
RUNTIME_INCLUDES := -I$(RUNTIME_PATH)/libc/wasi/include -I$(RUNTIME_PATH)/thirdparty/dist/include -I$(RUNTIME_PATH)
RUNTIME_SOURCES  := $(RUNTIME_PATH)/runtime.c $(RUNTIME_PATH)/memory/64bit_nix.c

# The bundled example. Override to try another module:  make EXAMPLE=foo run
EXAMPLE     ?= armstrong

DOCKER_IMAGE ?= awsm-build:latest

# ---------------------------------------------------------------------------
# Top-level targets
# ---------------------------------------------------------------------------
.PHONY: help all build run clean docker-image docker-shell docker-build docker-run docker-clean
.DEFAULT_GOAL := help

help:  ## Show this help
	@awk 'BEGIN {FS = ":.*?## "; printf "Usage: make <target>\n\nTargets:\n"} \
		/^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' \
		$(MAKEFILE_LIST)

all: build  ## Alias for `build`

build: $(EXAMPLE).awsm  ## Compile the example into a sandboxed native binary

run: build  ## Build then execute the example (assertions abort on failure)
	@echo "=> running ./$(EXAMPLE).awsm"
	@./$(EXAMPLE).awsm && echo "OK: $(EXAMPLE).awsm passed all assertions"

clean:  ## Remove all generated artefacts (*.wasm *.bc *.ll *.awsm)
	rm -f *.wasm *.bc *.ll *.awsm

# ---------------------------------------------------------------------------
# Build the aWsm compiler itself (Rust → release binary)
# ---------------------------------------------------------------------------
$(AWSMCC):
	cd aWsm && cargo build --release

# ---------------------------------------------------------------------------
# Pattern rules — `make foo.awsm` from a checked-in `foo.wat` + `foo.c`
# ---------------------------------------------------------------------------
%.wasm: %.wat
	$(WAT2WASM) $< -o $@

%.bc: %.wasm $(AWSMCC)
	$(AWSMCC) $(AWSMFLAGS) $< -o $@

%.ll: %.bc
	$(LLVM_DIS) $< -o $@

%.awsm: %.bc %.c $(RUNTIME_SOURCES)
	$(CC) $(CFLAGS) $(RUNTIME_INCLUDES) $(LDFLAGS) -lm $^ -o $@

# ---------------------------------------------------------------------------
# Docker — pinned Ubuntu 20.04 + LLVM 12 build environment.
# aWsm's `llvm-alt` Rust crate is hard-coded to the LLVM 12 C API, which
# apt.llvm.org has dropped for jammy/noble — so we reach for a container.
# ---------------------------------------------------------------------------
docker-image:  ## Build the pinned Ubuntu 20.04 + LLVM 12 container
	docker build -t $(DOCKER_IMAGE) .

docker-shell:  ## Open an interactive shell inside the container
	docker run --rm -it -v "$(CURDIR):/workspace" $(DOCKER_IMAGE) bash

docker-build:  ## `make build` inside the container
	docker run --rm -v "$(CURDIR):/workspace" $(DOCKER_IMAGE) make build

docker-run:    ## `make run` inside the container
	docker run --rm -v "$(CURDIR):/workspace" $(DOCKER_IMAGE) make run

docker-clean:  ## `make clean` inside the container
	docker run --rm -v "$(CURDIR):/workspace" $(DOCKER_IMAGE) make clean
