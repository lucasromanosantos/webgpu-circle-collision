@group(0) @binding(0) var<storage, read_write> circle_list_head: array<atomic<i32>>;
@group(0) @binding(1) var<storage, write> circle_list: array<i32>;
@group(0) @binding(2) var<storage, read> input: array<Circle>;

@stage(compute) @workgroup_size(64, 1, 1)
fn main(
  @builtin(global_invocation_id) global_id : vec3<u32>,
) {
    var cur = input[global_id.x];

    let list_index = get_list_index(cur.position);

    let previous = atomicExchange(&circle_list_head[list_index], i32(global_id.x));
    circle_list[global_id.x] = previous;
}

