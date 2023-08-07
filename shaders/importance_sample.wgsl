const PI: f32 = 3.141592653589793;

struct Referential {
    up: vec3<f32>,
    tangent_x: vec3<f32>,
    tangent_y: vec3<f32>,
}

fn createReferential(N: vec3<f32>) -> Referential {
    var result: Referential;
    result.up = select(vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0), abs(N.z) < 0.999);
    result.tangent_x = normalize(cross(result.up, N));
    result.tangent_y = cross(N, result.tangent_x);
    return result;
}

// Based on http://byteblacksmith.com/improvements-to-the-canonical-one-liner-glsl-rand-for-opengl-es-2-0/
fn random(co: vec2<f32>) -> f32 {
    let a = 12.9898;
    let b = 78.233;
    let c = 43758.5453;
    let dt = dot(co.xy, vec2(a, b));
    let sn = dt % 3.14;
    return fract(sin(sn) * c);
}

struct ImportanceSampleCosDir {
    L: vec3<f32>,
    NdotL: f32,
    pdf: f32,
}

fn importanceSampleCosDir(u: vec2<f32>, N: vec3<f32>) -> ImportanceSampleCosDir {
    let referential = createReferential(N);

    let u1 = u.x;
    let u2 = u.y;
    let r = sqrt(u1);
    let phi = u2 * PI * 2.0;

    var L = vec3(r*cos(phi), r*sin(phi), sqrt(max(0.0, 1.0 - u1)));
    L = normalize(referential.tangent_x * L.y + referential.tangent_y * L .x + N * L.z);
    var NdotL = dot(L, N);
    var pdf = NdotL / PI;

    var output: ImportanceSampleCosDir;
    output.L = L;
    output.NdotL = NdotL;
    output.pdf = pdf;
    return output;
}

struct ImportanceSampleGGX {
    H: vec3<f32>,
    L: vec3<f32>,
    n_dot_h: vec3<f32>,
    l_dot_h: vec3<f32>,
    G: vec3<f32>,
}

// Based on http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_slides.pdf
//
// QUESTION: Is this just the G term?
fn importanceSample_GGX(
    u: vec2<f32>,
    roughness: f32,
    N: vec3<f32>,
    referential: Referential,
) -> vec3<f32> {
    // Maps a 2D point to a hemisphere with spread based on roughness and some
    // random jitter added to reduce noise.
    let alpha = roughness * roughness;
    let alpha2 = alpha * alpha;
    let jitter = random(N.xz) * 0.1;
    let phi = 2.0 * PI * u.x + jitter;
    let cos_theta = sqrt((1.0 - u.y) / (1.0 + (alpha2 - 1.0) * u.y));
    let sin_theta = sqrt(1.0 - cos_theta * cos_theta);
    var H = vec3(sin_theta * cos(phi), sin_theta * sin(phi), cos_theta);

    // Convert H to world space
    return normalize(referential.tangent_x * H.x + referential.tangent_y * H.y + N * H.z);
}
