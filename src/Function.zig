const Self = @This();

const std = @import("std");
const Value = @import("Value.zig");
const BasicBlock = @import("BasicBlock.zig");

blocks: std.ArrayList(BasicBlock),
entry_block: BasicBlock.Index = @fromBackingInt(0),

pub const empty: Self = .{
    .blocks = .empty,
};

pub fn deinit(self: *Self, gpa: std.mem.Allocator) void {
    self.blocks.deinit(gpa);
    self.* = undefined;
}

// TODO: wrapper in context? it is the one who manages the allocator
pub fn addBlock(self: *Self, gpa: std.mem.Allocator, bb: BasicBlock) !BasicBlock.Index {
    const res: BasicBlock.Index = @fromBackingInt(@intCast(self.blocks.items.len));
    try self.blocks.append(gpa, bb);
    return res;
}
