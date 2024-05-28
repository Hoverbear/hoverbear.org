+++
title = "Hacking on Rust"
description = "Developing Rust itself"
sort_by = "weight"
template =  "blog/list.html"

[extra]
in_menu = true

[extra.image]
path = "cover.jpg"
colocated = true
photographer = "Kvistholt Photography"
source = "https://unsplash.com/photos/photo-of-computer-cables-oZPwn40zCK4"
+++

## Building the CI docker images

If you're in `src/ci/docker` and building images:

```bash
./src/ci/docker/run.sh ${IMAGE_NAME}
```

You may bump into an error like:

```
cargo:warning=In file included from llvm-wrapper/PassWrapper.cpp:8:
cargo:warning=llvm-wrapper/LLVMWrapper.h:3:10: fatal error: llvm-c/BitReader.h: No such file or directory
cargo:warning= #include "llvm-c/BitReader.h"
cargo:warning=          ^~~~~~~~~~~~~~~~~~~~
cargo:warning=compilation terminated.

--- stderr


error occurred: Command "sccache" "riscv64-unknown-linux-gnu-g++" "-O3" "-ffunction-sections" "-fdata-sections" "-fPIC" "-march=rv64gc" "-mabi=lp64d" "-ffunction-sections" "-fdata-sections" "-fPIC" "-march=rv64gc" "-mabi=lp64d" "-I/checkout/obj/build/riscv64gc-unknown-linux-gnu/ci-llvm/include" "-std=c++17" "-fno-exceptions" "-funwind-tables" "-fno-rtti" "-D_GNU_SOURCE" "-D_DEBUG" "-D_GLIBCXX_ASSERTIONS" "-D__STDC_CONSTANT_MACROS" "-D__STDC_FORMAT_MACROS" "-D__STDC_LIMIT_MACROS" "-DLLVM_COMPONENT_AARCH64" "-DLLVM_COMPONENT_ARM" "-DLLVM_COMPONENT_ASMPARSER" "-DLLVM_COMPONENT_AVR" "-DLLVM_COMPONENT_BITREADER" "-DLLVM_COMPONENT_BITWRITER" "-DLLVM_COMPONENT_BPF" "-DLLVM_COMPONENT_COVERAGE" "-DLLVM_COMPONENT_CSKY" "-DLLVM_COMPONENT_HEXAGON" "-DLLVM_COMPONENT_INSTRUMENTATION" "-DLLVM_COMPONENT_IPO" "-DLLVM_COMPONENT_LINKER" "-DLLVM_COMPONENT_LOONGARCH" "-DLLVM_COMPONENT_LTO" "-DLLVM_COMPONENT_M68K" "-DLLVM_COMPONENT_MIPS" "-DLLVM_COMPONENT_MSP430" "-DLLVM_COMPONENT_NVPTX" "-DLLVM_COMPONENT_POWERPC" "-DLLVM_COMPONENT_RISCV" "-DLLVM_COMPONENT_SPARC" "-DLLVM_COMPONENT_SYSTEMZ" "-DLLVM_COMPONENT_WEBASSEMBLY" "-DLLVM_COMPONENT_X86" "-DLLVM_RUSTLLVM" "-DNDEBUG" "-o" "/checkout/obj/build/x86_64-unknown-linux-gnu/stage1-rustc/riscv64gc-unknown-linux-gnu/release/build/rustc_llvm-cdebff3535cb1234/out/7372e21ddc8be4fd-PassWrapper.o" "-c" "llvm-wrapper/PassWrapper.cpp" with args riscv64-unknown-linux-gnu-g++ did not execute successfully (status code exit status: 1).
```

This was reported in [#85424](https://github.com/rust-lang/rust/issues/85424) as well as [#56650](https://github.com/rust-lang/rust/issues/56650). It seems to be caused by an issue with the built LLVM. In the CI images a [cached build is fetched from cache](https://github.com/rust-lang/rust/blob/a59072ec4fb6824213df5e9de8cae4812fd4fe97/src/ci/docker/run.sh#L107), you can disable that.

The fix is setting `DEPLOY=1`, eg:

```bash
DEPLOY=1 ./src/ci/docker/run.sh dist-riscv64-linux
```