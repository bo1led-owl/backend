const Self = @This();

const std = @import("std");
const Value = @import("Value.zig");
const Context = @import("Context.zig");
const BasicBlock = @import("BasicBlock.zig");

blocks: std.ArrayList(BasicBlock),
entry_block: BasicBlock.Index = @fromBackingInt(0),

pub const empty: Self = .{
    .blocks = .empty,
};

pub fn deinit(self: *Self, ctx: Context) void {
    self.blocks.deinit(ctx.gpa);
    self.* = undefined;
}

pub fn addBlock(self: *Self, ctx: Context, bb: BasicBlock) !BasicBlock.Index {
    const res: BasicBlock.Index = @fromBackingInt(@intCast(self.blocks.items.len));
    try self.blocks.append(ctx.gpa, bb);
    return res;
}
