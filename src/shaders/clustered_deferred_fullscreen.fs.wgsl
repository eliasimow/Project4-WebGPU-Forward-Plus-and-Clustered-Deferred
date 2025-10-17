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

    // Transform world position to view space for depth clustering
    let viewZ = (camera.viewMat * vec4f(worldPos, 1.0)).z;

    let clusterIdxZ = u32(clamp(
        (log(-viewZ) - log(camera.near)) / (log(camera.far) - log(camera.near)) * clusZ,
        0.0,
        clusZ - 1.0
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
