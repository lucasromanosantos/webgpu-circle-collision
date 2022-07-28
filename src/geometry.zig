const std = @import("std");

pub const Vertex = struct {
    pos: @Vector(4, f32),
};

pub const Geometry = struct {
    vertices: []Vertex,
    indices: []u32,

    pub fn deinit(self: *Geometry, allocator: *std.mem.Allocator) !void {
        return try allocator.free(self.indices);
    }
};

pub fn CircleGeometry(allocator: *std.mem.Allocator, segments: u32) !Geometry {
    const thetaLength: f32 = 2 * std.math.pi;

    var vertices = try allocator.alloc(Vertex, segments * 2 + 2);

    // center point
    vertices[0] = Vertex{
        .pos = .{ 0, 0, 0, 0 },
    };

    var s: usize = 0;
    while (s <= segments) : (s += 1) {
        const segment = @intToFloat(f32, s) / @intToFloat(f32, segments) * thetaLength;

        const pos: @Vector(4, f32) = [_]f32{
            std.math.cos(segment),
            std.math.sin(segment),
            0,
            0,
        };

        vertices[s] = Vertex{
            .pos = pos,
        };
    }

    var indices = try allocator.alloc(u32, segments * 3 + 1);
    indices[0] = 0;
    var i: usize = 1;
    var v: u32 = 1;
    while (i <= segments * 3) : (i += 3) {
        indices[i] = v;
        indices[i + 1] = v + 1;
        indices[i + 2] = 0;
        v += 1;
    }

    return Geometry{
        .vertices = vertices,
        .indices = indices,
    };
}
