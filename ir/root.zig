const std = @import("std");

pub const types = @import("types.zig");
pub const Printer = @import("Printer.zig");
pub const Context = @import("Context.zig");
pub const Builder = @import("Builder.zig");
pub const BasicBlock = @import("BasicBlock.zig");
pub const Function = @import("Function.zig");
pub const Value = @import("Value.zig");
const list = @import("list.zig");
pub const List = list.List;

// TODO: validation function to run in debug mode

test {
    _ = Printer;
    _ = types;
    _ = Context;
    _ = Builder;
    _ = BasicBlock;
    _ = Function;
    _ = Value;
    _ = list;
}
