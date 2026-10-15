const std = @import("std");

const types = @import("types.zig");
pub const Type = types.Type;

pub const Context = @import("Context.zig");
pub const Builder = @import("Builder.zig");
pub const BasicBlock = @import("BasicBlock.zig");
pub const Function = @import("Function.zig");
pub const Value = @import("Value.zig");
pub const ValueList = @import("ValueList.zig");

// TODO: validation function to run in debug mode

test {
    _ = types;
    _ = Context;
    _ = Builder;
    _ = BasicBlock;
    _ = Function;
    _ = Value;
    _ = ValueList;
}
