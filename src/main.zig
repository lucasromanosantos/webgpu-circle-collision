const std = @import("std");
const mach = @import("mach");
const gpu = @import("gpu");

const Circle = @import("circle.zig").Circle;

const Vertex = @import("geometry.zig").Vertex;
const Geometry = @import("geometry.zig").Geometry;
const CircleGeometry = @import("geometry.zig").CircleGeometry;

const colors = @import("colors.zig").colors;

queue: gpu.Queue,
frame_counter: usize,

// geometry
circle_geometry: Geometry,

// buffers
colors_buffer: gpu.Buffer,
circle_list_head_buffer: gpu.Buffer,
circle_list_buffer: gpu.Buffer,
circle_buffers: [2]gpu.Buffer,
circle_vertex_buffer: gpu.Buffer,
circle_index_buffer: gpu.Buffer,

// pipelines & bg
circle_list_clean_compute_pipeline: gpu.ComputePipeline,
circle_list_clean_bind_group: gpu.BindGroup,
circle_list_compute_pipeline: gpu.ComputePipeline,
circle_list_bind_groups: [2]gpu.BindGroup,
compute_pipeline: gpu.ComputePipeline,
circle_bind_groups: [2]gpu.BindGroup,
render_pipeline: gpu.RenderPipeline,
render_bind_group: gpu.BindGroup,

pub const App = @This();

const circle_segments: u32 = 12;
const circles_amount = 50;
const radius: f32 = 0.025;
const grid_width = 1.0 / radius;
const grid_height = grid_width;
const grid_total_length = grid_width * grid_height;

pub fn init(app: *App, core: *mach.Core) !void {
    const queue = core.device.getQueue();

    try core.setOptions(.{
        .size_min = .{ .width = 20, .height = 20 },
    });

    var circles: [circles_amount]Circle = undefined;
    var i: usize = 0;
    while (i < circles_amount) : (i += 1) {
        circles[i] = Circle.init(radius);
    }

    var circle_buffers: [2]gpu.Buffer = undefined;
    i = 0;
    while (i < 2) : (i += 1) {
        const buf = core.device.createBuffer(&.{
            .usage = .{ .vertex = true, .storage = true, .copy_dst = true },
            .size = circles.len * @sizeOf(Circle),
            .mapped_at_creation = true,
        });
        const buf_mapped = buf.getMappedRange(Circle, 0, circles.len);
        std.mem.copy(Circle, buf_mapped, &circles);
        buf.unmap();
        circle_buffers[i] = buf;
    }

    const circle_list_head_buffer = core.device.createBuffer(&.{
        .usage = .{ .storage = true, .copy_dst = true },
        .size = grid_total_length * @sizeOf(i32),
    });

    const circle_list_buffer = core.device.createBuffer(&.{
        .usage = .{ .storage = true, .copy_dst = true },
        .size = circles.len * @sizeOf(i32),
    });

    const circle_geometry = try CircleGeometry(&core.allocator, circle_segments);
    const circle_vertex_buffer = core.device.createBuffer(&.{
        .usage = .{ .vertex = true, .copy_dst = true },
        .size = @sizeOf(Vertex) * circle_geometry.vertices.len,
        .mapped_at_creation = true,
    });
    const circle_vertex_buffer_mapped = circle_vertex_buffer.getMappedRange(Vertex, 0, circle_geometry.vertices.len);
    std.mem.copy(Vertex, circle_vertex_buffer_mapped, circle_geometry.vertices[0..]);
    circle_vertex_buffer.unmap();

    const circle_index_buffer = core.device.createBuffer(&.{
        .usage = .{ .index = true, .copy_dst = true },
        .size = @sizeOf(u32) * circle_geometry.indices.len,
        .mapped_at_creation = true,
    });
    const circle_index_buffer_mapped = circle_index_buffer.getMappedRange(u32, 0, circle_geometry.indices.len);
    std.mem.copy(u32, circle_index_buffer_mapped, circle_geometry.indices[0..]);
    circle_index_buffer.unmap();

    const colors_buffer = core.device.createBuffer(&.{
        .usage = .{ .vertex = true, .storage = true, .copy_dst = true },
        .size = colors.len * @sizeOf(@Vector(3, f32)),
        .mapped_at_creation = true,
    });
    const colors_buffer_mapped = colors_buffer.getMappedRange(@Vector(3, f32), 0, colors.len);
    std.mem.copy(@Vector(3, f32), colors_buffer_mapped, &colors);
    colors_buffer.unmap();

    const circle_list_clean_compute_pipeline = core.device.createComputePipeline(&gpu.ComputePipeline.Descriptor{
        .compute = gpu.ProgrammableStageDescriptor{
            .module = core.device.createShaderModule(&.{
                .label = "clean circle list module",
                .code = .{ .wgsl = @embedFile("headers.wgsl") ++ @embedFile("list_clean_compute.wgsl") },
            }),
            .entry_point = "main",
        },
    });

    const circle_list_clean_bind_group = core.device.createBindGroup(&gpu.BindGroup.Descriptor{ .layout = circle_list_clean_compute_pipeline.getBindGroupLayout(0), .entries = &[_]gpu.BindGroup.Entry{
        gpu.BindGroup.Entry.buffer(0, circle_list_head_buffer, 0, grid_total_length * @sizeOf(i32)),
    } });

    const circle_list_compute_pipeline = core.device.createComputePipeline(&gpu.ComputePipeline.Descriptor{
        .compute = gpu.ProgrammableStageDescriptor{
            .module = core.device.createShaderModule(&.{
                .label = "build circle lists module",
                .code = .{ .wgsl = @embedFile("headers.wgsl") ++ @embedFile("list_compute.wgsl") },
            }),
            .entry_point = "main",
        },
    });

    var circle_list_bind_groups: [2]gpu.BindGroup = undefined;
    i = 0;
    while (i < 2) : (i += 1) {
        circle_list_bind_groups[i] = core.device.createBindGroup(&gpu.BindGroup.Descriptor{ .layout = circle_list_compute_pipeline.getBindGroupLayout(0), .entries = &[_]gpu.BindGroup.Entry{
            gpu.BindGroup.Entry.buffer(0, circle_list_head_buffer, 0, grid_total_length * @sizeOf(i32)),
            gpu.BindGroup.Entry.buffer(1, circle_list_buffer, 0, circles.len * @sizeOf(u32)),
            gpu.BindGroup.Entry.buffer(2, circle_buffers[i], 0, circles.len * @sizeOf(Circle)),
        } });
    }

    const compute_pipeline = core.device.createComputePipeline(&gpu.ComputePipeline.Descriptor{ .compute = gpu.ProgrammableStageDescriptor{
        .module = core.device.createShaderModule(&.{
            .label = "collision compute module",
            .code = .{ .wgsl = @embedFile("headers.wgsl") ++ @embedFile("collision_compute.wgsl") },
        }),
        .entry_point = "main",
    } });

    var circle_bind_groups: [2]gpu.BindGroup = undefined;
    i = 0;
    while (i < 2) : (i += 1) {
        circle_bind_groups[i] = core.device.createBindGroup(&gpu.BindGroup.Descriptor{
            .layout = compute_pipeline.getBindGroupLayout(0),
            .entries = &[_]gpu.BindGroup.Entry{
                gpu.BindGroup.Entry.buffer(0, circle_buffers[i], 0, circles.len * @sizeOf(Circle)),
                gpu.BindGroup.Entry.buffer(1, circle_buffers[(i + 1) % 2], 0, circles.len * @sizeOf(Circle)),
                gpu.BindGroup.Entry.buffer(2, circle_list_head_buffer, 0, grid_total_length * @sizeOf(i32)),
                gpu.BindGroup.Entry.buffer(3, circle_list_buffer, 0, circles.len * @sizeOf(u32)),
            },
        });
    }

    const color_target = gpu.ColorTargetState{
        .format = core.swap_chain_format,
        .blend = &gpu.BlendState{
            .color = .{
                .operation = .add,
                .src_factor = .one,
                .dst_factor = .zero,
            },
            .alpha = .{
                .operation = .add,
                .src_factor = .one,
                .dst_factor = .zero,
            },
        },
        .write_mask = gpu.ColorWriteMask.all,
    };

    const circle_buffer_attributes = [_]gpu.VertexAttribute{
        .{
            .shader_location = 0,
            .offset = @offsetOf(Circle, "radius"),
            .format = .float32,
        },
        .{
            .shader_location = 1,
            .offset = @offsetOf(Circle, "collisions"),
            .format = .uint32,
        },
        .{
            .shader_location = 2,
            .offset = @offsetOf(Circle, "position"),
            .format = .float32x2,
        },
        .{
            .shader_location = 3,
            .offset = @offsetOf(Circle, "velocity"),
            .format = .float32x2,
        },
    };

    const circle_vertex_attributes = [_]gpu.VertexAttribute{
        .{
            .shader_location = 4,
            .offset = @offsetOf(Vertex, "pos"),
            .format = .float32x4,
        },
    };

    const render_pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .layout = null,
        .fragment = &gpu.FragmentState{
            .module = core.device.createShaderModule(&.{
                .label = "fragment vertex shader",
                .code = .{ .wgsl = @embedFile("render.wgsl") },
            }),
            .entry_point = "frag_main",
            .targets = &.{color_target},
            .constants = null,
        },
        .vertex = .{
            .module = core.device.createShaderModule(&.{
                .label = "render vertex shader",
                .code = .{ .wgsl = @embedFile("render.wgsl") },
            }),
            .entry_point = "vert_main",
            .buffers = &[_]gpu.VertexBufferLayout{
                .{
                    // attributes
                    .array_stride = @sizeOf(Circle),
                    .step_mode = .instance,
                    .attribute_count = circle_buffer_attributes.len,
                    .attributes = &circle_buffer_attributes,
                },
                .{
                    // vertices
                    .array_stride = @sizeOf(Vertex),
                    .step_mode = .vertex,
                    .attribute_count = circle_vertex_attributes.len,
                    .attributes = &circle_vertex_attributes,
                },
            },
        },
    };

    const render_pipeline = core.device.createRenderPipeline(&render_pipeline_descriptor);

    const render_bind_group = core.device.createBindGroup(&gpu.BindGroup.Descriptor{
        .layout = render_pipeline.getBindGroupLayout(0),
        .entries = &[_]gpu.BindGroup.Entry{
            gpu.BindGroup.Entry.buffer(0, colors_buffer, 0, colors.len * @sizeOf(@Vector(3, f32))),
        },
    });

    app.queue = queue;
    app.frame_counter = 0;
    app.colors_buffer = colors_buffer;
    app.circle_geometry = circle_geometry;
    app.circle_buffers = circle_buffers;
    app.circle_vertex_buffer = circle_vertex_buffer;
    app.circle_index_buffer = circle_index_buffer;
    // 1st pipeline
    app.circle_list_clean_compute_pipeline = circle_list_clean_compute_pipeline;
    app.circle_list_clean_bind_group = circle_list_clean_bind_group;
    // 2st pipeline
    app.circle_list_bind_groups = circle_list_bind_groups;
    app.circle_list_compute_pipeline = circle_list_compute_pipeline;
    // 3nd pipeline
    app.compute_pipeline = compute_pipeline;
    app.circle_bind_groups = circle_bind_groups;
    // render
    app.render_pipeline = render_pipeline;
    app.render_bind_group = render_bind_group;
}

pub fn deinit(_: *App, _: *mach.Core) void {}

pub fn update(app: *App, core: *mach.Core) !void {
    const back_buffer_view = core.swap_chain.?.getCurrentTextureView();

    const color_attachment = gpu.RenderPassColorAttachment{
        .view = back_buffer_view,
        .resolve_target = null,
        .clear_value = std.mem.zeroes(gpu.Color),
        .load_op = .clear,
        .store_op = .store,
    };

    const encoder = core.device.createCommandEncoder(null);

    const circle_list_clean_compute_pass = encoder.beginComputePass(null);
    circle_list_clean_compute_pass.setPipeline(app.circle_list_clean_compute_pipeline);
    circle_list_clean_compute_pass.setBindGroup(0, app.circle_list_clean_bind_group, null);
    circle_list_clean_compute_pass.dispatch(try std.math.divCeil(u32, grid_total_length, 64), 1, 1);
    circle_list_clean_compute_pass.end();
    circle_list_clean_compute_pass.release();

    const circle_list_compute_pass = encoder.beginComputePass(null);
    circle_list_compute_pass.setPipeline(app.circle_list_compute_pipeline);
    circle_list_compute_pass.setBindGroup(0, app.circle_list_bind_groups[app.frame_counter % 2], null);
    circle_list_compute_pass.dispatch(try std.math.divCeil(u32, circles_amount, 64), 1, 1);
    circle_list_compute_pass.end();
    circle_list_compute_pass.release();

    const compute_pass = encoder.beginComputePass(null);
    compute_pass.setPipeline(app.compute_pipeline);
    compute_pass.setBindGroup(0, app.circle_bind_groups[app.frame_counter % 2], null);
    compute_pass.dispatch(try std.math.divCeil(u32, circles_amount, 64), 1, 1);
    compute_pass.end();
    compute_pass.release();

    const render_pass = encoder.beginRenderPass(&gpu.RenderPassEncoder.Descriptor{ .color_attachments = &[_]gpu.RenderPassColorAttachment{
        color_attachment,
    } });
    render_pass.setPipeline(app.render_pipeline);
    render_pass.setBindGroup(0, app.render_bind_group, null);
    render_pass.setVertexBuffer(0, app.circle_buffers[(app.frame_counter + 1) % 2], 0, @sizeOf(Circle) * circles_amount);
    render_pass.setVertexBuffer(1, app.circle_vertex_buffer, 0, @sizeOf(Vertex) * app.circle_geometry.vertices.len);
    render_pass.setIndexBuffer(app.circle_index_buffer, gpu.IndexFormat.uint32, 0, @sizeOf(u32) * app.circle_geometry.indices.len);
    render_pass.drawIndexed(@intCast(u32, app.circle_geometry.indices.len), circles_amount, 0, 0, 0);
    render_pass.end();
    render_pass.release();

    app.frame_counter += 1;

    var command = encoder.finish(null);
    encoder.release();
    app.queue.submit(&.{command});
    command.release();

    core.swap_chain.?.present();
    back_buffer_view.release();
}
