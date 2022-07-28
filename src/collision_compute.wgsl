@group(0) @binding(0) var<storage, read> input: array<Circle>;
@group(0) @binding(1) var<storage, write> output: array<Circle>;

@group(0) @binding(2) var<storage, read> circle_list_head_buffer: array<i32>;
@group(0) @binding(3) var<storage, read> circle_list_buffer: array<i32>;

let TIME_STEP: f32 = 0.016;

@stage(compute) @workgroup_size(64, 1, 1)
fn main(
  @builtin(global_invocation_id) global_id : vec3<u32>,
) {
  if (global_id.x >= arrayLength(&output)) {
    return;
  }

  var cur = input[global_id.x];

  if ((cur.position[0] < -1.0) || (cur.position[0] > 1.0)) {
    cur.position[0] = clamp(cur.position[0], -1.0, 1.0);
    cur.velocity[0] *= -1.0;
  } else if ((cur.position[1] < -1.0) || (cur.position[1] > 1.0)) {
    cur.position[1] = clamp(cur.position[1], -1.0, 1.0);
    cur.velocity[1] *= -1.0;
  } else {

    let grid_xy = get_list_xy(cur.position);
    for (var i: u32 = max(0u, grid_xy.x - 1u); i <= min(grid_size, grid_xy.x + 1u); i++) {
      for (var j: u32 = max(0u, grid_xy.y - 1u); j <= min(grid_size, grid_xy.y + 1u); j++) {
        var target_index = circle_list_head_buffer[i + (j * grid_size)];
        loop {
          if (target_index < 0) {
            break;
          }

          if (i32(global_id.x) != target_index) {
            let target = input[target_index];
            if (overlap(cur.position[0], cur.position[1], cur.radius, target.position[0], target.position[1], target.radius)) {
              // distance
              let d = distance_of_points(cur.position[0], cur.position[1], target.position[0], target.position[1]);
              let overlap = (d - cur.radius - target.radius) / 2.0;

              // displace
              cur.position[0] -= overlap * (cur.position[0] - target.position[0]) / d;
              cur.position[1] -= overlap * (cur.position[1] - target.position[1]) / d;

              var tangent = vec2<f32>((target.position[0] - cur.position[0]) * -1.0, target.position[1] - target.position[0]);
              tangent = normalize(tangent);
              let relative_velocity = vec2<f32>(target.velocity[0] - cur.velocity[0], target.velocity[1] - cur.velocity[1]);
              let length = dot(relative_velocity, tangent);
              let velocity_tangent = tangent * length;
              let velocity_perpendicular_tangent = relative_velocity - velocity_tangent;

              cur.velocity[0] += velocity_perpendicular_tangent[0];
              cur.velocity[1] += velocity_perpendicular_tangent[1];

              cur.collisions += 1u;
            }
          }

          target_index = circle_list_buffer[target_index];
        }

      }
    }

  }

  cur.position = cur.position + cur.velocity * TIME_STEP;
  output[global_id.x] = cur;
}

fn overlap(x1: f32, y1: f32, r1: f32, x2: f32, y2: f32, r2: f32) -> bool {
  return abs((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2)) <= (r1 + r2) * (0.01 + 0.01);
}

fn distance_of_points(x1: f32, y1: f32, x2: f32, y2: f32) -> f32 {
  return sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
}
