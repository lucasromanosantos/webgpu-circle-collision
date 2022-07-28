struct Circle {
  radius: f32,
  collisions: u32,
  position: vec2<f32>,
  velocity: vec2<f32>,
}

// TODO: gui + use buffers
let radius = 0.025;
let hash_grid_cell_size: f32 = 0.05;
let grid_size: u32 = 20u;

fn get_list_index(position: vec2<f32>) -> u32 {
  let list_xy = get_list_xy(position);
  return list_xy.x + (list_xy.y * grid_size);
}

fn get_list_xy(position: vec2<f32>) -> vec2<u32> {
  var x = u32(abs(position.x) / hash_grid_cell_size / 2.0);
  var y = u32(abs(position.y) / hash_grid_cell_size / 2.0);
  if (position.x > 0.0) {
    x *= 2u;
  }
  if (position.y > 0.0) {
    y *= 2u;
  }
  return vec2(x, y);
}

