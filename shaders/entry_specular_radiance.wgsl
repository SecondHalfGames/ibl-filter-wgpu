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
    @location(1) roughness: f32,
    @location(2) mip_level: u32,
}

// Normal Distribution function
fn D_GGX(n_dot_h: f32, roughness: f32) -> f32 {
    let alpha = roughness * roughness;
    let alpha2 = alpha * alpha;
    let denom = n_dot_h * n_dot_h * (alpha2 - 1.0) + 1.0;
    return alpha2 / (PI * denom*denom);
}

fn integrate(R: vec3<f32>, roughness: f32, num_samples: u32) -> vec3<f32> {
    let N = R;
    let V = R;
    var color = vec3(0.0);
    var total_weight = 0.0;
    let env_map_size = f32(textureDimensions(environment, 0).x);

    let referential = createReferential(N);

    for (var i = 0u; i < num_samples; i++) {
        let Xi = hammersley2d(i, num_samples);
        let H = importanceSample_GGX(Xi, roughness, N, referential);
        let L = 2.0 * dot(V, H) * H - V;
        let n_dot_l = saturate(dot(N, L));

        if n_dot_l > 0.0 {
            // Filtering based on
            // https://placeholderart.wordpress.com/2015/07/28/implementation-notes-runtime-environment-map-filtering-for-image-based-lighting/

            let n_dot_h = saturate(dot(N, H));
            let v_dot_h = saturate(dot(V, H));

            // Probability Distribution Function
            let pdf = D_GGX(n_dot_h, roughness) * n_dot_h / (4.0 * v_dot_h) + 0.0001;
            // Slid angle of current smple
            let omegaS = 1.0 / (f32(num_samples) * pdf);
            // Solid angle of 1 pixel across all cube faces
            let omegaP = 4.0 * PI / (6.0 * env_map_size * env_map_size);
            // Biased (+1.0) mip level for better result
            let mip_level = select(max(0.5 * log2(omegaS / omegaP) + 1.0, 0.0), 0.0, roughness == 0.0);
            color += textureSampleLevel(environment, cube_sampler, L, mip_level).rgb * n_dot_l;
            total_weight += n_dot_l;
        }
    }

    return color / total_weight;
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
    let roughness = push.roughness;
    let mip_level = push.mip_level;

    // TODO: Explain why we have to flip Y in view_pos but not elsewhere.
    let clip_space = vec4(pos, 1.0, 1.0);
    let view_pos = push.projection_inv * (clip_space * vec4(1.0, -1.0, 1.0, 1.0));

    var world_dir = view_inv * (view_pos.xyz / view_pos.w);
    world_dir = normalize(world_dir);

    var output: VertexOutput;
    output.position = clip_space;
    output.direction = world_dir;
    output.roughness = roughness;
    output.mip_level = mip_level;
    return output;
}

@fragment
fn fs_main(input: VertexOutput) -> FragOutput {
    let N = normalize(input.direction);

    var sample_count = array<u32, 6>(1u, 8u, 32u, 64u, 128u, 128u);
    let num_samples = sample_count[input.mip_level];

    let filtered = integrate(N, input.roughness, num_samples);

    var output: FragOutput;
    output.color = vec4(filtered, 1.0);
    return output;
}
