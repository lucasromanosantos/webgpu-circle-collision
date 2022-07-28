const std = @import("std");
const mach = @import("libs/mach/build.zig");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const app = mach.App.init(b, .{
        .name = "app",
        .src = "src/main.zig",
        .target = target,
        .deps = &[_]std.build.Pkg{},
    });
    app.setBuildMode(mode);
    app.link(.{});
    app.install();

    const run_cmd = app.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
