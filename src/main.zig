const std = @import("std");
const builtin = @import("builtin");

const backend = @import("backend");
const ir = backend.ir;

var stdout_buffer: [4096]u8 align(std.heap.page_size_min) = undefined;

const use_safe_allocator = builtin.mode == .debug or builtin.mode == .safe;
var safe_allocator: std.heap.SafeAllocator = .init(std.heap.page_allocator, .{});

pub fn main(init: std.process.Init.Minimal) !void {
    const gpa = if (use_safe_allocator)
        safe_allocator.allocator()
    else
        std.heap.smp_allocator;
    defer if (use_safe_allocator) {
        _ = safe_allocator.deinit();
    };

    var io_impl = std.Io.Threaded.init(gpa, .{
        .argv0 = .init(init.args),
        .environ = init.environ,
    });
    defer io_impl.deinit();

    const io = io_impl.io();
    _ = io;

    var ctx: ir.Context = .init(gpa);
    defer ctx.deinit();

    var functions: std.StringHashMapUnmanaged(ir.Function) = .empty;
    defer {
        var iter = functions.valueIterator();
        while (iter.next()) |f| {
            f.deinit(gpa);
        }
        functions.deinit(gpa);
    }

    var function: ir.Function = .empty;
    try function.blocks.append(gpa, block);

    try functions.put(gpa, ctx.storeName("foo"), function);
}
