import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ClusteredDeferredRenderer extends renderer.Renderer {
    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;

    secondBindGroupLayout: GPUBindGroupLayout;
    secondBindGroup: GPUBindGroup;

    albedo: GPUTexture;
    albedoView: GPUTextureView;
    normal: GPUTexture;
    normalView: GPUTextureView;
    depth: GPUTexture;
    depthView: GPUTextureView;
    position: GPUTexture;
    positionView: GPUTextureView;


    firstPass: GPURenderPipeline;
    secondPass: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);

        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "scene uniforms bind group layout",
            entries: [
                {
                    binding :0,
                    visibility : GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer : { type: "uniform" }
                }]
        });

        this.sceneUniformsBindGroup = renderer.device.createBindGroup({
            label: "scene uniforms bind group",
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer}
                }
            ]
        });

        this.normal = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.normalView = this.normal.createView();

        this.albedo = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba8unorm",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.albedoView = this.albedo.createView();

        this.depth = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.depthView = this.depth.createView();


        this.position = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.positionView = this.position.createView();

this.firstPass = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "first pass pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "vert shader",
                    code: shaders.naiveVertSrc
                }),
                buffers: [ renderer.vertexBufferLayout ]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred fragment",
                    code: shaders.clusteredDeferredFragSrc,
                }),
                targets: [
                    { format: 'rgba8unorm' },
                    { format: 'rgba16float' },
                    { format: 'rgba16float' }
                    // TODO-3: add formats for albedo, normal, and position textures
//                     { format: 'rgba16float' }
                ]
            }
        });

         this.secondBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "second pass bind group layout",
            entries: [
                {
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: {type: "read-only-storage"}
                },
                {
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: 'float'
                    }
                },
                {
                    binding: 4,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: 'float'
                    }
                },
                {
                    binding: 5,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: 'float'
                    }
                }]
        });

        this.secondBindGroup = renderer.device.createBindGroup({
            label: "second pass bind group",
            layout: this.secondBindGroupLayout,
            entries: [
                {
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer }
                },
                {
                    binding: 2,
                    resource: {buffer: this.lights.clusterBuffer}
                },
                {
                    binding: 3,
                    resource: this.albedoView
                },
                {
                    binding: 4,
                    resource: this.normalView
                },
                {
                    binding: 5,
                    resource: this.positionView
                }
            ]
        });

        this.secondPass = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "clustered 2nd pass pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout,
                    this.secondBindGroupLayout
                ]
            }),
                depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },


            vertex: {
                module: renderer.device.createShaderModule({
                    label: "clustered full screen vertex quad",
                    code: shaders.clusteredDeferredFullscreenVertSrc
                }),
                buffers: [renderer.vertexBufferLayout]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "clustered full screen fragment",
                    code: shaders.clusteredDeferredFullscreenFragSrc,
                }),
                entryPoint: "main",
                targets: [
                    {format: renderer.canvasFormat}
                ]
            }
        });

    }
            first()
    {
        const firstPassDescriptor: GPURenderPassDescriptor = {
            label: "cluster first pass descriptor",
            colorAttachments: [
                {
                    view: this.albedoView,
                    clearValue: {r:0, g:0, b:0, a:0},
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.normalView,
                    clearValue: {r:0, g:0, b:0, a:0},
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.positionView,
                    clearValue: {r:0, g:0, b:0, a:0},
                    loadOp: "clear",
                    storeOp: "store"
                }
            ],
            depthStencilAttachment: {
                view: this.depthView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store"
            }
       };

       const commandEncoder = renderer.device.createCommandEncoder();
       const passEncoder = commandEncoder.beginRenderPass(firstPassDescriptor);

       passEncoder.setPipeline(this.firstPass);
       passEncoder.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);

       this.scene.iterate(
        node => {
            passEncoder.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        },
        material => {
            passEncoder.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        },
        primitive => {
            passEncoder.setVertexBuffer(0, primitive.vertexBuffer);
            passEncoder.setIndexBuffer(primitive.indexBuffer, "uint32");
            passEncoder.drawIndexed(primitive.numIndices);
        }
       );
      passEncoder.end();
       renderer.device.queue.submit([commandEncoder.finish()]);
    }


    second() {
        const cmdEncoder = renderer.device.createCommandEncoder();
        const textureView = renderer.context.getCurrentTexture().createView();

        const renderPass = cmdEncoder.beginRenderPass({
            label: "cluster 2nd render pass",
            colorAttachments: [
                {
                    view: textureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                }
            ],
            depthStencilAttachment: {
                view: this.depthView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store"
            }
        });

        renderPass.setPipeline(this.secondPass);

        renderPass.setBindGroup(shaders.constants.bindGroup_GBUFFER, this.secondBindGroup);

        renderPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);
        this.scene.iterate(
            node => {
                renderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
            },
            material => {
                renderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
            },
            primitive => {  
                renderPass.setVertexBuffer(0, primitive.vertexBuffer);
                renderPass.setIndexBuffer(primitive.indexBuffer, "uint32");
                renderPass.drawIndexed(primitive.numIndices);
            }
        );

        renderPass.end();
        renderer.device.queue.submit([cmdEncoder.finish()]);
    }

    
        // TODO-3: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        // you'll need two pipelines: one for the G-buffer pass and one for the fullscreen pass
    

    override draw() {
        const computeEncoder = renderer.device.createCommandEncoder();
        this.lights.doLightClustering(computeEncoder);
        const computeCommands = computeEncoder.finish();
        renderer.device.queue.submit([computeCommands]);
        this.first();
        this.second();
    }
}
