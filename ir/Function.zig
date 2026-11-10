const Self = @This();

const std = @import("std");
const support = @import("support");
const Type = @import("Type.zig");
const Value = @import("Value.zig");
const Context = @import("Context.zig");
const BasicBlock = @import("BasicBlock.zig");
const List = @import("list.zig").List;

pub const Index = support.index(Self, u32);

ty: Type.Handle,
stack_slots: Value.List = .empty,

/// entry block is the first one
/// if this list is empty, then function is considered extern
blocks: List(BasicBlock, BasicBlock.Index, BasicBlock.IndexOpt),
