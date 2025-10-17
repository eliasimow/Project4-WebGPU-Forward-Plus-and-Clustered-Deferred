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

fn lineIntersectionToZPlane(A: vec3<f32>, B: vec3<f32>, zDistance: f32) -> vec3<f32> {
    let normal: vec3<f32> = vec3<f32>(0.0, 0.0, -1.0);
    let ab: vec3<f32> = B - A;
    let denom: f32 = dot(normal, ab);
    let t: f32 = (zDistance - dot(normal, A)) / denom;
    let result: vec3<f32> = A + t * ab;
    return result;
}

@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> clusterSet: ClusterSet;

@compute
@workgroup_size(${clusterWorkGroupSize})
fn main(@builtin(global_invocation_id) globalIdx: vec3<u32>) {
    let clusterIdx: u32 = globalIdx.x;

    let clusX: u32 = ${clusterX}u;
    let clusY: u32 = ${clusterY}u;
    let clusZ: u32 = ${clusterZ}u;

    if (clusterIdx >= clusX * clusY * clusZ) {
        return;
    }


    let x: u32 = clusterIdx % clusX;
    let y: u32 = (clusterIdx / clusX) % clusY;
    let z: u32 = clusterIdx / (clusX * clusY);

    let w: f32 = camera.width;
    let h: f32 = camera.height;
    let near: f32 = camera.near;
    let far: f32 = camera.far;

    let clusterWidth: f32 = w / f32(clusX);
    let clusterHeight: f32 = h / f32(clusY);
    let clusterDepth: f32 = (far - near) / f32(clusZ);

    let tileNear: f32 = -near * pow(far / near, f32(z) / f32(clusZ));
    let tileFar:  f32 = -near * pow(far / near, f32(z + 1u) / f32(clusZ));

    let eyePos: vec3<f32> = vec3<f32>(0.0, 0.0, 0.0);

    let maxPoint_sS: vec4<f32> = vec4<f32>(
        (f32(x) + 1.0) * clusterWidth,
        (f32(y) + 1.0) * clusterHeight,
        -1.0,
        1.0
    );

    let minPoint_sS: vec4<f32> = vec4<f32>(
        f32(x) * clusterWidth,
        f32(y) * clusterHeight,
        -1.0,
        1.0
    );

    let maxPoint_vS: vec3<f32> = screen2View(maxPoint_sS).xyz;
    let minPoint_vS: vec3<f32> = screen2View(minPoint_sS).xyz;

    let minPointNear: vec3<f32> = lineIntersectionToZPlane(eyePos, minPoint_vS, tileNear);
    let minPointFar:  vec3<f32> = lineIntersectionToZPlane(eyePos, minPoint_vS, tileFar);
    let maxPointNear: vec3<f32> = lineIntersectionToZPlane(eyePos, maxPoint_vS, tileNear);
    let maxPointFar:  vec3<f32> = lineIntersectionToZPlane(eyePos, maxPoint_vS, tileFar);

    let minPointAABB: vec3<f32> = min(min(minPointNear, minPointFar), min(maxPointNear, maxPointFar));
    let maxPointAABB: vec3<f32> = max(max(minPointNear, minPointFar), max(maxPointNear, maxPointFar));

    // track lights in this cluster; use u32 counter for indexing
    var lightCount: u32 = 0u;
    for (var lightIdx: u32 = 0u; lightIdx < lightSet.numLights; lightIdx++) {
        let light = lightSet.lights[lightIdx];
        let lightPosView: vec3<f32> = (camera.viewProjMat * vec4<f32>(light.pos, 1.0)).xyz;
        let clamped: vec3<f32> = clamp(lightPosView, minPointAABB, maxPointAABB);
        let dist: f32 = length(clamped - lightPosView);

        if (dist < f32(${lightRadius}) && lightCount < ${maxLightsPerCluster}u) {
            clusterSet.lightsPerCluster[clusterIdx].lights[lightCount] = lightIdx;
            lightCount = lightCount + 1u;
        }
    }
    clusterSet.lightsPerCluster[clusterIdx].numLights = lightCount;
    clusterSet.lightsPerCluster[clusterIdx].min = minPointAABB;
    clusterSet.lightsPerCluster[clusterIdx].max = maxPointAABB;
}
