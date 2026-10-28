const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ir = b.addModule("ir", .{
        .root_source_file = b.path("ir/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const opt = b.addModule("opt", .{
        .root_source_file = b.path("opt/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .module = ir, .name = "ir" },
        },
    });

    const ir_tests = b.addTest(.{ .root_module = ir });
    const run_ir_tests = b.addRunArtifact(ir_tests);

    const opt_tests = b.addTest(.{ .root_module = opt });
    const run_opt_tests = b.addRunArtifact(opt_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_ir_tests.step);
    test_step.dependOn(&run_opt_tests.step);
}
