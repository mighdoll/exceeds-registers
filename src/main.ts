import code from "./reduce.wgsl?raw";

main();

async function main(): Promise<void> {
  const adapter = await navigator.gpu.requestAdapter();
  const device = await adapter!.requestDevice();
  const pipeline = createPipeline(device);

  const bindGroup = device.createBindGroup({
    layout: pipeline.getBindGroupLayout(0),
    entries: [],
  });

  const commandEncoder = device.createCommandEncoder();

  const passEncoder = commandEncoder.beginComputePass();
  passEncoder.setPipeline(pipeline);
  passEncoder.setBindGroup(0, bindGroup);
  passEncoder.dispatchWorkgroups(1);
  passEncoder.end();

  device.queue.submit([commandEncoder.finish()]);
}

function createPipeline(device: GPUDevice): GPUComputePipeline {
  const module = device.createShaderModule({ code });

  const bindGroupLayout = device.createBindGroupLayout({
    label: "reduceBuffer",
    entries: [
      {
        binding: 0, // uniforms
        visibility: GPUShaderStage.COMPUTE,
        buffer: { type: "uniform" },
      },
      {
        binding: 1, // reduced values input
        visibility: GPUShaderStage.COMPUTE,
        buffer: { type: "read-only-storage" },
      },
      {
        binding: 2, // reduced values output
        visibility: GPUShaderStage.COMPUTE,
        buffer: { type: "storage" },
      },
      {
        binding: 11, // debug buffer
        visibility: GPUShaderStage.COMPUTE,
        buffer: { type: "storage" },
      },
    ],
  });
  const pipeline = device.createComputePipeline({
    label: "reduceBuffer",
    compute: {
      module,
      entryPoint: "reduceFromBuffer",
    },
    layout: device.createPipelineLayout({
      bindGroupLayouts: [bindGroupLayout],
    }),
  });

  return pipeline;
}
