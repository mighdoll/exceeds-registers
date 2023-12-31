struct Input { 
    histogram: array<u32, 256>,  // inputStruct
}

struct Output { 
    histogram: array<u32, 256>,  // outputStruct
}

struct Uniforms {
    sourceOffset: u32,        // offset in Input elements to start reading in the source
    resultOffset: u32,        // offset in Output elements to start writing in the results
}

@group(0) @binding(0) var<uniform> u: Uniforms;                     // uniforms
@group(0) @binding(1) var<storage, read> src: array<Input>; 
@group(0) @binding(2) var<storage, read_write> out: array<Output>;  
@group(0) @binding(11) var<storage, read_write> debug: array<f32>; // buffer to hold debug values


const workgroupThreads= 16; // workgroupThreads

var <workgroup> work:array<Output, workgroupThreads>; 

// 
// reduce a buffer of values to a single value, returned as the last element of the out array
// 
// each dispatch does two reductions:
//    . each invocation reduces from a src buffer to the workgroup buffer
//    . one invocation per workgroup reduces from the workgroup buffer to the out buffer
// the driver issues multiple dispatches until the output is 1 element long
//    (subsequent passes uses the output of the previous pass as the src)
// the same output buffer can be used as input and output in subsequent passes
//    . start and end indices in the uniforms indicate input and output positions in the buffer
// 

@compute
@workgroup_size(workgroupThreads, 1, 1) 
fn reduceFromBuffer(
    @builtin(global_invocation_id) grid: vec3<u32>,    // coords in the global compute grid
    @builtin(local_invocation_id) localId: vec3<u32>, // coords inside the this workgroup
    @builtin(num_workgroups) numWorkgroups: vec3<u32>, // number of workgroups in this dispatch
    @builtin(workgroup_id) workgroupId: vec3<u32>      // workgroup id in the dispatch
) {
    reduceBufferToWork(grid.xy, localId.x);
    let outDex = workgroupId.x + u.resultOffset;
    reduceWorkgroupToOut(outDex, localId.x);
}

fn reduceBufferToWork(grid: vec2<u32>, localId: u32) {
    var values = fetchSrcBuffer(grid.x);
    var v = reduceBlock(values);
    work[localId] = v;
}

// LATER benchmark striping/striding could reduce memory bank conflict
// might be useful on other hardware.
//
// Current benchmarks are near the practical limit on memory bandwidth on my m1max 
// theoretical limit is 400gb/sec, practical reports of 330 gb/sec for native apps,
// and we're at 320 gb/sec.
fn fetchSrcBuffer(gridX: u32) -> array<Output, 4> {  // blockArea
    let start = u.sourceOffset + (gridX * 4u); // blockArea
    let end = arrayLength(&src);
    var a = array<Output,4>(); // blockArea
    for (var i = 0u; i < 4u; i = i + 1u) { // blockArea
        var idx = i + start;
        if idx < end {
            a[i] = loadOp(src[idx]);
        } else {
            a[i] = identityOp();
        }
    }

    return a;
}

// Reduce workgroup stored values to a single value in parallel
// using the pattern:
//   iter 1  0 = 0 + 1 
//           2 = 2 + 3
//             ...
//   iter 2  0 = 0 + 2
//             ...
fn reduceWorkgroupToOut(outDex: u32, localId: u32) {
    let workDex = localId << 1u;
    for (var step = 1u; step < 16u; step <<= 1u) { // workgroupThreads
        workgroupBarrier();
        if localId % step == 0u {
            work[workDex] = binaryOp(work[workDex], work[workDex + step]);
        }
    }
    if localId == 0u {
        out[outDex] = work[0];
    }
}
// The above pattern doesn't bunch together used threads in the workgroup
// compared to a reduction that uses the pattern:
//   iter 1  0 = 0 + 2
//           1 = 1 + 3
//             ...
//   iter 2  0 = 0 + 1
//             ...
// If the gpu can schedule a partial workgroup, there will
// be partial workgroups available in this second pattern. 
// but the second pattern requires commutavity of the binary op,
// and I'm not sure the partial workgroup scheduling is a thing in
// practice in WebGPU..

fn reduceBlock(a: array<Output, 4>) -> Output { // blockArea
    var v = a[0];
    for (var i = 1u; i < 4u; i = i + 1u) { // blockArea
        v = binaryOp(v, a[i]);
    }
    return v;
}

fn binaryOp(a: Output, b: Output) -> Output {
    
        var result: array<u32,256>; 
        for (var i = 0u; i < 256u; i = i + 1u) { 
            result[i] = a.histogram[i] + b.histogram[i];
        }
        return Output(result);
      // binaryOp
}

fn loadOp(a: Input) -> Output {
    
        return Output(a.histogram);
      // loadOp
}

fn identityOp() -> Output {
    
        return Output(array<u32,256>()); 
     // identityOp
}