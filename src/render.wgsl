@group(0) @binding(0) var<storage, read> colors: array<vec3<f32>>;

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @interpolate(flat)  @location(0) collisions: u32,
};

@stage(vertex) 
fn vert_main(
  @location(0) radius: f32,
  @location(1) collisions: u32,
  @location(2) position: vec2<f32>,
  @location(4) vertices_position: vec2<f32>,
) -> VertexOutput {
    var out: VertexOutput;
    out.position = vec4<f32>(vertices_position * radius + position, 0.0, 1.0);
    out.collisions = collisions;
    return out;
}

@stage(fragment)
fn frag_main(
   @interpolate(flat) @location(0) collisions: u32,
) -> @location(0) vec4<f32> {
  let color = colors[collisions % arrayLength(&colors)];
  return vec4<f32>(color, 1.0);
}

