// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights

// ------------------------------------
// Shading process:
// ------------------------------------
// Determine which cluster contains the current fragment.
// Retrieve the number of lights that affect the current fragment from the cluster’s data.
// Initialize a variable to accumulate the total light contribution for the fragment.
// For each light in the cluster:
//     Access the light's properties using its index.
//     Calculate the contribution of the light based on its position, the fragment’s position, and the surface normal.
//     Add the calculated contribution to the total light accumulation.
// Multiply the fragment’s diffuse color by the accumulated light contribution.
// Return the final color, ensuring that the alpha component is set appropriately (typically to 1).
fn screen2View(screen: vec4<f32>) -> vec4<f32> {
    // Convert to NDC
    let dimensions: vec2<f32> = vec2<f32>(camera.width, camera.height);
    let texCoord: vec2<f32> = screen.xy / dimensions;

    // Convert to clip space (flip Y)
    let clipX: f32 = texCoord.x * 2.0 - 1.0;
    let clipY: f32 = (1.0 - texCoord.y) * 2.0 - 1.0;
    let clip: vec4<f32> = vec4<f32>(clipX, clipY, screen.z, screen.w);

    var view: vec4<f32> = camera.inverseProjection * clip;

    view = view / view.w;

    return view;
}

@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;


@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f,
    @builtin(position) fragPos: vec4f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let clusX: f32 = f32(${clusterX}u);
    let clusY: f32 = f32(${clusterY}u);
    let clusZ: f32 = f32(${clusterZ}u);

    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    let viewPos = camera.viewMat * vec4f(in.pos, 1.0);    
    let clusterIdxX = u32(in.fragPos.x / camera.width * clusX);
    let clusterIdxY = u32(in.fragPos.y / camera.height * clusY);

let clusterIdxZ = u32(clamp(
    (log(-viewPos.z) - log(camera.near)) / (log(camera.far) - log(camera.near)) * f32(clusZ),
    0.0,
    f32(clusZ - 1)
));

// if((log(-viewPos.z) - log(camera.near)) / (log(camera.far) - log(camera.near)) * f32(clusZ) < 1.0){
//     return vec4f(1.0,0.0,0.0,1.0);

// }

    let clusterIdx = clusterIdxX + clusterIdxY * u32(clusX) + clusterIdxZ * u32(clusX * clusY);

    var totalLightContrib = vec3f(0, 0, 0);
    let clustNumLights = u32(clusterSet.lightsPerCluster[clusterIdx].numLights);

    for (var i = 0u; i < clustNumLights; i++) {
        let lightIndex = clusterSet.lightsPerCluster[clusterIdx].lights[i];
        let light = lightSet.lights[lightIndex];
        totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
    }

    var finalColor = diffuseColor.rgb * totalLightContrib;
    let clusterColor = vec3f(f32(clusterIdxX)/clusX,f32(clusterIdxY)/clusY, f32(clusterIdxZ)/clusZ);
 //   return vec4f(clusterColor, 1.0);    
    return vec4f(finalColor, 1.0);
}
