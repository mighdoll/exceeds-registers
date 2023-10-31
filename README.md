shader compilation error example.

run with:

```sh
pnpm install
pnpm vite dev
```


this error appears in the console on my machine at least:

```
localhost/:1 Error creating pipeline state Compute function exceeds available temporary registers
    at Initialize (../../third_party/dawn/src/dawn/native/metal/ComputePipelineMTL.mm:79)
    at CreateComputePipeline (../../third_party/dawn/src/dawn/native/Device.cpp:1664)

```