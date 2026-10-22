const std = @import("std");

const types = @import("ir/types.zig");
pub const Type = types.Type;

pub const Printer = @import("ir/Printer.zig");
pub const Context = @import("ir/Context.zig");
pub const Builder = @import("ir/Builder.zig");
pub const BasicBlock = @import("ir/BasicBlock.zig");
pub const Function = @import("ir/Function.zig");
pub const Value = @import("ir/Value.zig");
pub const ValueList = @import("ir/ValueList.zig");

// TODO: validation function to run in debug mode

test {
    _ = Printer;
    _ = types;
    _ = Context;
    _ = Builder;
    _ = BasicBlock;
    _ = Function;
    _ = Value;
    _ = ValueList;
}
