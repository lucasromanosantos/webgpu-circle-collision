@group(0) @binding(0) var<storage, write> circle_list_head: array<i32>;

@stage(compute) @workgroup_size(64, 1, 1)
fn main(
  @builtin(global_invocation_id) global_invocation_id : vec3<u32>,
)  {
    let index = global_invocation_id.x;
    if (index < arrayLength(&circle_list_head)) {
      circle_list_head[index] = -1;
    }
}
 
