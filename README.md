WebGL Forward+ and Clustered Deferred Shading
======================

* Eli Asimow
* [LinkedIn](https://www.linkedin.com/in/eli-asimow/), [personal website](https://easimow.com)
* Tested on: Windows 11, AMD Ryzen 7 7435HS @ 2.08GHz 16GB, Nvidia GeForce RTX 4060 GPU

### Live Demo

[![](img/thumb.png)](http://TODO.github.io/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred)

### Demo Video/GIF


https://github.com/user-attachments/assets/0a22a8a0-832d-4f36-8875-49ddd37f3a55

Hello! Welcome to my study of different rendering techniques. Here you will find three different approaches to rendering a scene filled with a high number of dynamic light sources. They differ largely in how they optimize the process of determining light effect on each fragment in the frag shader. I’ve implemented them with WebGPU, so you can test them out for yourself right here in your browser. Give them a go before continuing through the readme.

The three lighting implementations are as follows:

## Naive

For the naive technique, we simply loop over each light in the scene for each fragment. This is rather computationally expensive, but it’s as straightforward as the process gets. Fragments determine their lighting by considering every source, even when the source is known to be far away, or even when the fragment will soon be overridden by a fragment that is closer to the camera in the z axis.

## Forward+

Forward+ makes a big improvement over naive by breaking the scene into a grid of light clusters. Oriented in camera view space, these clusters partition the lights into in range collections during a parallel compute shader. Then, when a frag needs to compute its lighting, it can simply index into its view space cluster to find a list of all affecting lights. There are several optimizations I skipped in my implementation here that I’d like to revisit when I have the time. For one, while the x and y axis of the cluster grid are linear partitions, we should have a logarithmic z partition to account for camera perspective; as is, further back z grid clusters cover far too much geographic area.

## Deferred

Lastly, Deferred shading pushes the optimization even further by completely separating the lighting stage from the geometry pass. Instead of calculating lighting as each fragment is drawn, we first store surface information like position, normal, and albedo into what’s called a G-buffer. Once that data is written, a second pass runs over the screen and computes lighting just once per visible pixel. This means we avoid shading any fragments that end up hidden behind others, saving a huge amount of unnecessary work compared to the naive and Forward+ approaches. However, this comes at a cost: the G-buffers consume a lot of memory bandwidth. While working through my implementation, I also noticed some extra overhead from my compute-based clustering step that could definitely be trimmed down later. Still, when the scene gets dense with geometry or has a large number of lights, the performance gains from Deferred shading really start to show.


## Performance Testing

<img width="600" height="371" alt="Naive, Forward+, Deferred renderers vs  Light Count" src="https://github.com/user-attachments/assets/ad4352a0-d050-44ce-8884-6f872d887650" />

I expected Clustered Deferred to be the superior approach to rendering this scene, as it saves a good bit of time in overhead for unnecessary fragment shading. When I began to profile though,  I was surprised by the magnitude of that difference. Deferred crushes its peers consistently at any light count! This is a result of a linear optimization effect: the buried fragments that deferred skips lighting are necessary costs for naive and Forward+, and the cost of these fragments only goes up as the count of scene lights increases. On the other hand, in very simple scenes with just a few lights, Forward+ actually held its own. The deferred path carries a lot of extra overhead, including writing out multiple G-buffers and additional shader calls. For lightweight – or lightless! – scenes, this meant that my Naive and Forward+ could actually outperform my Deferred. 

| Light Count | Naive       | Forward Plus | Deferred    |
|------------:|------------:|-------------:|------------:|
| 200         | 21.73913043 MS | 18.18181818 MS  | 6.944444444 MS |
| 400         | 43.47826087 MS| 34.48275862 MS  | 7.352941176 MS |
| 800         | 83.33333333 MS| 55.55555556 MS  | 14.28571429 MS |
| 1600        | 251.23 MS      | 125.2 MS        | 27.77777778 MS |

As I began profiling, I realized there was some unnecessary overhead in my compute clustering stage: two compute shaders for calculating cluster grid bounds and lights located within the bounds separately, when they could be optimized into one! It’s worth noting that this isn’t necessarily a strict optimization; when the camera is stationary, we really only need to calculate our cluster grid bounds once. But because my initial implementation was calling both compute shaders on every draw frame, the removal of an extra compute call & unnecessary cluster buffer parameters’ min and max aabb, this ended up being a flat improvement to performance of about ~2fps for Forward+ with 500 lights. All other performance tests here were made with this enhancement.

One notable downside to the Forward+ and Deferred approach is the cluster grid box artifacts. This is especially noticeable when the sum lights in the scene are increased. Because we hit the 255 limit on lights per cluster rather quickly, some lights that should affect our cluster grid are ignored, and the variance of which lights are ignored from cell to cell is what produces the artifact. Now, there are several things we could do to fix this in later work. The best would be to produce some single array that contains all cluster to light assignments, such that clusters can use variable space, and even be ignored when their light count is zero. Other bandaid solutions, like increasing the limit, have a noticeable impact on performance. 

<img width="600" height="371" alt="Execution Time (MS) vs  Max Cluster Lights" src="https://github.com/user-attachments/assets/d480478f-6ddc-437d-9528-1b897c37b8ab" />

| Max Cluster Lights | 123  | 255  | 511  | 1023  |
|------------------:|:----:|:----:|:----:|:-----:|
| Execution Time    | 52.63 ms | 58.82 ms | 76.92 ms | 109.65 ms |


For the purposes of this paper, I’ve limited the count to 255 as a tradeoff between visuals and performance.


<img width="600" height="371" alt="Forward+ Cluster Square Grid Size VS Execution Time" src="https://github.com/user-attachments/assets/ac945812-37c7-42e8-b104-4160d9fa2bcd" />


### Credits

- [Forward+ Guide](https://www.aortiz.me/2018/12/21/CG.html#part-2)
- [Vite](https://vitejs.dev/)
- [loaders.gl](https://loaders.gl/)
- [dat.GUI](https://github.com/dataarts/dat.gui)
- [stats.js](https://github.com/mrdoob/stats.js)
- [wgpu-matrix](https://github.com/greggman/wgpu-matrix)
