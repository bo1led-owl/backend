const Self = @This();

const std = @import("std");
const Value = @import("Value.zig");

pub const Index = enum(u32) { _ };

pub const ValueList = @import("ValueList.zig");

instructions: ValueList,
arguments: ValueList,

pub fn init() Self {
    return .{
        .instructions = .empty,
        .arguments = .empty,
    };
}
