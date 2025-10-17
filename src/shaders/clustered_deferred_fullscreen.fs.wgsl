// TODO-3: Implement the Clustered Deferred fullscreen fragment shader
// This shader reconstructs lighting from G-buffer textures,
// similar to Forward+, but uses stored per-pixel attributes
// instead of direct vertex inputs.

@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_GBUFFER}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_GBUFFER}) @binding(2) var<storage, read> clusterSet: ClusterSet;
@group(${bindGroup_GBUFFER}) @binding(3) var albedoTex: texture_2d<f32>;
@group(${bindGroup_GBUFFER}) @binding(4) var norTex: texture_2d<f32>;
@group(${bindGroup_GBUFFER}) @binding(5) var posTex: texture_2d<f32>;

struct FragmentInput {
    @builtin(position) fragPos: vec4f,
};

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
    // --- Cluster grid dimensions ---
    let clusX = f32(${clusterX}u);
    let clusY = f32(${clusterY}u);
    let clusZ = f32(${clusterZ}u);

    // --- Fetch G-buffer data ---
    let texCoord = vec2<u32>(in.fragPos.xy);
    let albedo   = textureLoad(albedoTex, texCoord, 0);
    let normal   = textureLoad(norTex, texCoord, 0).xyz * 2.0 - 1.0;
    let worldPos = textureLoad(posTex, texCoord, 0).xyz;

    // --- Compute cluster indices ---
    let clusterIdxX = u32(in.fragPos.x / camera.width  * clusX);
    let clusterIdxY = u32(in.fragPos.y / camera.height * clusY);

    let viewPos = camera.viewMat * vec4f(worldPos, 1.0);

    // Transform world position to view space for depth clustering
    let tileNear: f32 = camera.near + f32(0u) * (camera.far - camera.near) / f32(clusZ);
    let tileFar:  f32 = camera.near + f32(1u) * (camera.far - camera.near) / f32(clusZ);

    let clusterDepth: f32 = (camera.far - camera.near) / f32(clusZ);
    let clusterIdxZ: u32 = u32(clamp(
        (viewPos.z - camera.near) / clusterDepth,
        0.0,
        f32(clusZ - 1)
    ));


    let clusterIdx = clusterIdxX +
                     clusterIdxY * u32(clusX) +
                     clusterIdxZ * u32(clusX * clusY);

    // --- Accumulate light contributions ---
    var totalLight = vec3f(0.0, 0.0, 0.0);
    let numLights = u32(clusterSet.lightsPerCluster[clusterIdx].numLights);

    for (var i = 0u; i < numLights; i++) {
        let lightIdx = clusterSet.lightsPerCluster[clusterIdx].lights[i];
        let light = lightSet.lights[lightIdx];
        totalLight += calculateLightContrib(light, worldPos, normalize(normal));
    }

    // --- Final color ---
    let finalColor = albedo.rgb * totalLight;
    return vec4f(finalColor, 1.0);
}
