const BasicBlock = @This();

const std = @import("std");
const support = @import("support");
const Value = @import("Value.zig");

pub const Index = support.indexAndIndexOpt(BasicBlock, u32).@"0";
pub const IndexOpt = support.indexAndIndexOpt(BasicBlock, u32).@"1";

instructions: Value.List,
arguments: Value.List,

// to store a list of all basic blocks in functions
prev: IndexOpt = .none,
next: IndexOpt = .none,

pub const empty: BasicBlock = .{
    .instructions = .empty,
    .arguments = .empty,
};
