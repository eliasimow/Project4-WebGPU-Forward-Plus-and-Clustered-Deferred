// TODO-2: implement the light clustering compute shader

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

//     For each light:
//         - Check if the light intersects with the cluster’s bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

//     - Store the number of lights assigned to this cluster.

//add binding for camera width height and resolution:
@group(${bindGroup_scene}) @binding(0) var<uniform> camera : CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> clusterSet: ClusterSet;

@compute
@workgroup_size(${clusterWorkGroupSize})
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {
    let clusterIdx = globalIdx.x;
    if (clusterIdx >= clusterSet.numCluster) {
        return;
    }

    let clusX = ${clusterX};
    let clusY = ${clusterY};
    let clusZ = ${clusterZ};

    let x = clusterIdx % clusX;
    let y = (clusterIdx / clusX) % clusY;
    let z = clusterIdx / (clusX * clusY);

    // TODO-2: calculate cluster bounds in view space
    let clusterBounds = vec4f(0.0, 0.0, 0.0, 0.0); // min.x, min.y, max.x, max.y

//cluster bounds 2d first, x and y:



    clusterSet.clusters[clusterIdx].lightCount = 0u;



}
