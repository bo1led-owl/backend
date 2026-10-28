const Self = @This();

const std = @import("std");
const Value = @import("Value.zig");
const ValueList = @import("ValueList.zig");

pub const Index = enum(u32) {
    _,

    pub fn toU32(self: Index) u32 {
        return @backingInt(self);
    }
};

instructions: ValueList,
arguments: ValueList,

pub const empty: Self = .{
    .instructions = .empty,
    .arguments = .empty,
};
