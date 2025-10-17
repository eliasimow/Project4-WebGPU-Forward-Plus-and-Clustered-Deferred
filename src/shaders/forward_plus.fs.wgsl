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
    let clusX: u32 = ${clusterX}u;
    let clusY: u32 = ${clusterY}u;
    let clusZ: u32 = ${clusterZ}u;

    let viewSpacePos = screen2View(in.fragPos);

    let clusterWidth: f32 = camera.width / f32(clusX);
    let clusterHeight: f32 = camera.height / f32(clusY);

    let x: u32 = u32(in.fragPos.x / clusterWidth);
    let y: u32 = u32(in.fragPos.y / clusterHeight);
    let z = u32(clamp(log(in.fragPos.z / in.fragPos.w) * ${clusterZ} / log(camera.far / camera.near) - ${clusterZ} * log(camera.near) / log(camera.far/camera.near), 0, f32(clusZ-1u)));


    // Convert NDC [-1,1] to screen coordinates [0, clusX/clusY]
    // let x: u32 = u32(clamp((in.fragPos.x / camera.width) * f32(clusX), 0.0, f32(clusX - 1u)));
    // let y: u32 = u32(clamp((in.fragPos.y / camera.height) * f32(clusY), 0.0, f32(clusY - 1u)));

    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }


    var totalLightContrib = vec3f(0, 0, 0);

    let clusterIdx: u32 = x + y * clusX + z * (clusX * clusY);
    //check if x,y,z are in range of determined cluster's min and max. if not draw debug purple:
    let min = clusterSet.lightsPerCluster[clusterIdx].min;
    let max = clusterSet.lightsPerCluster[clusterIdx].max;
    if (viewSpacePos.x < min.x){
        return vec4(1,0,1,1);
    }


    for (var cLightIdx = 0u; cLightIdx < clusterSet.lightsPerCluster[clusterIdx].numLights; cLightIdx = cLightIdx + 1u) {
        let light = lightSet.lights[clusterSet.lightsPerCluster[clusterIdx].lights[cLightIdx]];
        totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
    }

    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1);
   // return vec4(f32(x) / f32(clusX), f32(y) / f32(clusY), f32(z) / f32(clusZ), 1);
}
