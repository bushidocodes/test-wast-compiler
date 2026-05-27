# test-wast-compiler

An experiment in compiling a hand-written WebAssembly text (`.wat`) module
ahead-of-time into a sandboxed native binary, using
[**aWsm**](https://github.com/gwsystems/aWsm) — a Wasm → LLVM bitcode → native
compiler from the George Washington University Systems group.

The bundled example, [`armstrong.wat`](armstrong.wat), implements the
[Exercism "Armstrong numbers" exercise](https://exercism.org/tracks/wasm/exercises/armstrong-numbers)
in raw `.wat`. [`armstrong.c`](armstrong.c) drives it with a battery of
assertions and is linked into the same binary by the aWsm runtime.

## Pipeline

```
armstrong.wat  --wat2wasm-->  armstrong.wasm  --aWsm-->  armstrong.bc
                                                            |
                                                            +-- llvm-dis --> armstrong.ll  (optional, human-readable LLVM IR)
                                                            |
                                                            +-- clang + aWsm runtime --> armstrong.awsm  (sandboxed native ELF)
```

Each step is a separate Make target; `make run` walks the whole chain and
executes the binary.

## Quick start (Docker)

The fastest, most reliable path. The provided [`Dockerfile`](Dockerfile)
pins Ubuntu 20.04 with the exact LLVM 12 toolchain aWsm requires.

```sh
git clone --recurse-submodules <this repo>
cd test-wast-compiler

make docker-image     # one-time, ~3–5 min: builds Ubuntu 20.04 + LLVM 12 image
make docker-run       # build the example inside the container and run it
```

Expected output:

```
=> running ./armstrong.awsm
OK: armstrong.awsm passed all assertions
```

## Quick start (native Linux)

Possible if your distro still has LLVM 12 available (Ubuntu 20.04 focal,
Debian bullseye, etc.). On newer distros LLVM 12 isn't packaged anymore
— use the Docker path instead.

Install dependencies (Ubuntu 20.04):

```sh
sudo apt install build-essential cmake wabt binaryen \
                 libc++-11-dev libc++abi-11-dev libffi-dev \
                 clang-12 lld-12 llvm-12 llvm-12-dev llvm-12-tools
sudo update-alternatives --install /usr/bin/clang       clang       /usr/bin/clang-12       100
sudo update-alternatives --install /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-12 100
sudo update-alternatives --install /usr/bin/llvm-dis    llvm-dis    /usr/bin/llvm-dis-12    100
sudo update-alternatives --install /usr/bin/ld.lld      ld.lld      /usr/bin/lld-12         100
# plus Rust via rustup: https://rustup.rs
```

Then build and run:

```sh
git submodule update --init --recursive
make run
```

The exact same package list is what the [`Dockerfile`](Dockerfile) installs,
so reading it is also a fine way to learn what the toolchain needs.

## Make targets

| Target          | What it does                                                  |
| --------------- | ------------------------------------------------------------- |
| `make help`     | List all targets (the default).                               |
| `make build`    | Compile `armstrong.awsm`.                                     |
| `make run`      | `build` plus run the binary; assertions abort on failure.     |
| `make clean`    | Remove `*.wasm`, `*.bc`, `*.ll`, `*.awsm` from the workspace. |
| `make docker-*` | Run the same target inside the pinned build container.        |

The intermediate artefacts are also targets, in case you want to stop early:

```sh
make armstrong.wasm   # just run wat2wasm
make armstrong.bc     # also run aWsm
make armstrong.ll     # also disassemble the bitcode to readable IR
make armstrong.awsm   # also link with the runtime to produce a binary
```

To compile a different module — say `foo.wat` paired with `foo.c` — drop both
files into the project root and run:

```sh
make EXAMPLE=foo run
```

## Why is this stuck on LLVM 12?

aWsm depends on the `llvm-alt` Rust crate (from `gwsystems/llvm-rs`, branch
`sfbase`), which is hard-coded to the **LLVM 12 C API**. Newer LLVM releases
broke source compatibility — opaque pointers, removed C-API symbols, typed
GEP changes — so the crate will not compile against LLVM 14+ without
patching the FFI bindings.

`apt.llvm.org` only ships LLVM 12 for **focal (20.04)** and **bionic
(18.04)** at the time of writing. That's why this repo carries a Dockerfile
pinned to focal: it sidesteps the version mismatch entirely.

## Repository layout

```
.
├── Makefile           # wrapper around the aWsm pipeline + Docker helpers
├── Dockerfile         # Ubuntu 20.04 + LLVM 12 + Rust build environment
├── armstrong.wat      # the WebAssembly module (Armstrong-number check)
├── armstrong.c        # native driver with assertions, linked into .awsm
└── aWsm/              # submodule: github.com/gwsystems/aWsm
```

## Further reading

- aWsm paper: [*eWASM: Practical Software Fault Isolation for Reliable
  Embedded Devices*](https://www2.seas.gwu.edu/~gparmer/publications/emsoft20wasm.pdf)
- aWsm runtime sources: [`aWsm/runtime/`](aWsm/runtime)
- The Armstrong-numbers exercise:
  [exercism.org/tracks/wasm/exercises/armstrong-numbers](https://exercism.org/tracks/wasm/exercises/armstrong-numbers)
