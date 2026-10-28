const Self = @This();

const std = @import("std");
const Value = @import("Value.zig");
const Context = @import("Context.zig");
const BasicBlock = @import("BasicBlock.zig");
const ValueList = @import("ValueList.zig");

pub const Index = enum(u32) {
    _,

    pub fn toU32(self: Index) u32 {
        return @backingInt(self);
    }
};

stack_slots: ValueList = .empty,
entry_block: BasicBlock.Index,
