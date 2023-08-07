#include "lighting/importance_sample"
#include "lighting/hammersley"

@group(0) @binding(0) var environment: texture_cube<f32>;
@group(0) @binding(1) var cube_sampler: sampler;

struct PushConstants {
    projection_inv: mat4x4<f32>,
    view_inv_x: vec3<f32>,
    roughness: f32,
    view_inv_y: vec3<f32>,
    mip_level: u32,
    view_inv_z: vec3<f32>,
    _pad0: f32,
}

var<push_constant> push: PushConstants;

struct FragOutput {
    @location(0) color: vec4<f32>,
}

struct VertexInput {
    @builtin(vertex_index) index: u32,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) direction: vec3<f32>,
}

fn unimportantSample(u: vec2<f32>, N: vec3<f32>, referential: Referential) -> vec3<f32> {
    let u1 = u.x;
    let u2 = u.y;
    let r = sqrt(u1);
    let phi = u2 * PI * 2.0;

    var L = vec3(r*cos(phi), r*sin(phi), sqrt(max(0.0, 1.0 - u1)));
    L = normalize(referential.tangent_x * L.y + referential.tangent_y * L .x + N * L.z);

    return L;
}

// This method is similar to the sampling from the 2013 frostbite paper, but we
// sample from a lower mip level to make up for using fewer samples.
fn integrate_lpg(N: vec3<f32>) -> vec4<f32> {
    var acc = vec3(0.0);
    let sampleCount = 32u;

    let mip_count = textureNumLevels(environment);
    let mip_level = floor(f32(mip_count) * 0.75);
    let referential = createReferential(N);

    for (var i = 0u; i < sampleCount; i++) {
        let u = hammersley2d(i, sampleCount);
        let L = unimportantSample(u, N, referential);
        let NdotL = saturate(dot(N, L));
        let value = textureSampleLevel(environment, cube_sampler, L, mip_level).rgb;

        if (NdotL > 0.0) {
            acc += value;
        }
    }

    return vec4(acc / f32(sampleCount), 1.0);
}

@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
    var rectangle = array<vec2<f32>, 6>(
        vec2(-1.0, -1.0),
        vec2(-1.0,  1.0),
        vec2( 1.0,  1.0),

        vec2( 1.0, -1.0),
        vec2(-1.0, -1.0),
        vec2( 1.0,  1.0)
    );

    let pos = rectangle[input.index];
    var view_inv = mat3x3(push.view_inv_x, push.view_inv_y, push.view_inv_z);

    let clip_space = vec4(pos, 1.0, 1.0);
    let view_pos = push.projection_inv * (clip_space * vec4(1.0, -1.0, 1.0, 1.0));

    var world_dir = view_inv * (view_pos.xyz / view_pos.w);
    world_dir = normalize(world_dir);

    var output: VertexOutput;
    output.position = clip_space;
    output.direction = world_dir;
    return output;
}

@fragment
fn fs_main(input: VertexOutput) -> FragOutput {
    let N = normalize(input.direction);

    var output: FragOutput;
    output.color = integrate_lpg(N);
    return output;
}
