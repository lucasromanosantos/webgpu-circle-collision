const std = @import("std");

const RandomGenerator = std.rand.DefaultPrng;

var rnd = RandomGenerator.init(0);

pub const Circle = struct {
    radius: f32,
    collisions: u32,
    position: @Vector(2, f32),
    velocity: @Vector(2, f32),

    pub fn init(radius: f32) Circle {
        return Circle{
            .radius = radius,
            .collisions = 0,
            .position = @Vector(2, f32){ randomU1Float(), randomU1Float() },
            .velocity = @Vector(2, f32){ randomU1Float() / 5, randomU1Float() / 5 },
        };
    }
};

inline fn randomU1Float() f32 {
    return (rnd.random().float(f32) - 0.5) * 2;
}
