AWSMCC=aWsm/target/release/awsm
CC=clang

# Used by aWsm when compiling the *.wasm to *.bc
AWSMFLAGS= --inline-constant-globals

RUNTIME_PATH=aWsm/runtime
RUNTIME_INCLUDES=-I${RUNTIME_PATH}/libc/wasi/include -I${RUNTIME_PATH}/thirdparty/dist/include -I${RUNTIME_PATH}

aWsm/target/release/awsm:
	cd aWsm && cargo build --release

.PHONY: clean
clean:
	rm -f *.wasm *.bc *.ll *.awsm

%.wasm: %.wat
	wat2wasm $^ -o $@

%.bc: %.wasm
	${AWSMCC} ${AWSMFLAGS} $< -o $@

%.ll: %.bc
	llvm-dis-12 $< -o $@

%.awsm: %.bc %.c ${RUNTIME_PATH}/runtime.c ${RUNTIME_PATH}/memory/64bit_nix.c
	${CC} ${RUNTIME_INCLUDES} -lm -O3 -flto $^ -o $@
