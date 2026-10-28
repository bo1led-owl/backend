const Self = @This();

const std = @import("std");
const Context = @import("Context.zig");
const Type = @import("types.zig").Type;
const Value = @import("Value.zig");
const Function = @import("Function.zig");
const BasicBlock = @import("BasicBlock.zig");
const ValueList = @import("ValueList.zig");

ctx: *const Context,
writer: *std.Io.Writer,
depth: u32 = 0,
cur_block_args: ?*const ValueList = null,

const PAD_SIZE: u32 = 2;

pub const Error = std.Io.Writer.Error;

pub fn init(ctx: *const Context, writer: *std.Io.Writer) Self {
    return .{ .ctx = ctx, .writer = writer };
}

fn pad(self: *Self) !void {
    try self.writer.splatByteAll(' ', self.depth * PAD_SIZE);
}

pub fn printFunction(self: *Self, function: Function) Error!void {
    try self.writer.writeAll("stack slots: [");

    if (!function.stack_slots.isEmpty()) {
        self.depth += 1;
        defer self.depth -= 1;

        var iter = function.stack_slots.iterator(self.ctx.values.slice());
        var first = true;
        while (iter.next()) |value_idx| {
            if (!first) {
                try self.writer.writeAll(", ");
            }
            first = false;

            const slot_type = self.ctx.values.items(.ty)[value_idx.toU32()];
            try self.writer.print("v{d}: ", .{value_idx.toU32()});
            try self.printType(slot_type);
        }
    }
    try self.writer.writeAll("]\n");

    for (function.blocks.items, 0..) |bb, bb_index| {
        try self.writer.print("b{d}(", .{bb_index});
        {
            var iter = bb.arguments.iterator(self.ctx.values.slice());
            var first = true;
            while (iter.next()) |value_idx| {
                if (!first) {
                    try self.writer.writeAll(", ");
                }
                first = false;

                const arg_type = self.ctx.values.items(.ty)[value_idx.toU32()];
                try self.writer.print("v{d}: ", .{value_idx.toU32()});
                try self.printType(arg_type);
            }
            try self.writer.writeAll("):\n");
        }

        self.cur_block_args = &bb.arguments;
        defer self.cur_block_args = null;

        self.depth += 1;
        defer self.depth -= 1;

        var iter = bb.instructions.iterator(self.ctx.values.slice());
        while (iter.next()) |value_idx| {
            try self.pad();
            try self.printInstruction(function, value_idx);
            try self.writer.writeByte('\n');
        }
    }
}

pub fn printOperand(self: *Self, v: Value.Index) Error!void {
    switch (self.ctx.values.items(.kind)[v.toU32()]) {
        .constant => try self.writer.print("{d}", .{self.ctx.values.items(.data)[v.toU32()].constant}),
        else => try self.writer.print("v{d}", .{v.toU32()}),
    }
}

pub fn printInstruction(self: *Self, function: Function, value_index: Value.Index) Error!void {
    const value_type = self.ctx.values.items(.ty)[value_index.toU32()];
    if (value_type.kind != .unit) {
        try self.writer.print("v{d}: ", .{value_index.toU32()});
        try self.printType(value_type);
        try self.writer.writeAll(" = ");
    }

    const value_kind = self.ctx.values.items(.kind)[value_index.toU32()];

    const mnemonic =
        switch (value_kind) {
            .truncate => "trunc",
            .sign_extend => "sext",
            .zero_extend => "zext",
            .negate => "neg",
            .add => "add",
            .sub => "sub",
            .mul => "mul",
            .sdiv => "sdiv",
            .udiv => "udiv",
            .cmp_eq => "cmp eq",
            .cmp_ne => "cmp ne",
            .cmp_slt => "cmp slt",
            .cmp_sgt => "cmp sgt",
            .cmp_sle => "cmp sle",
            .cmp_sge => "cmp sge",
            .cmp_ult => "cmp ult",
            .cmp_ugt => "cmp ugt",
            .cmp_ule => "cmp ule",
            .cmp_uge => "cmp uge",
            .stack_load => "load stack",
            .stack_store => "store stack",
            .stack_address => "slotaddr",
            .load => "load",
            .store => "store",
            .jump => "jmp",
            .br => "br",
            .ret => "ret",
            .block_argument, .stack_slot, .constant => unreachable,
        };

    try self.writer.writeAll(mnemonic);

    const value_data = self.ctx.values.items(.data)[value_index.toU32()];
    switch (value_kind) {
        .truncate,
        .sign_extend,
        .zero_extend,
        .negate,
        .stack_address,
        .stack_load,
        .load,
        => {
            const operand = value_data.unary;
            try self.writer.writeByte(' ');
            try self.printOperand(operand);
        },
        .add,
        .sub,
        .mul,
        .sdiv,
        .udiv,
        .cmp_eq,
        .cmp_ne,
        .cmp_slt,
        .cmp_sgt,
        .cmp_sle,
        .cmp_sge,
        .cmp_ult,
        .cmp_ugt,
        .cmp_ule,
        .cmp_uge,
        => {
            const operands = value_data.binary;
            try self.writer.writeByte(' ');
            try self.printOperand(operands.lhs);
            try self.writer.writeAll(", ");
            try self.printOperand(operands.rhs);
        },
        .stack_store, .store => {
            const operands = value_data.store;
            try self.writer.writeByte(' ');
            try self.printOperand(operands.dest);
            try self.writer.writeAll(" <- ");
            try self.printOperand(operands.src);
        },
        .jump => {
            const info = Value.info.jump(self.ctx.*, function, value_index);
            try self.writer.print(" b{d}(", .{info.dest.toU32()});
            for (info.args, 0..) |arg_index, i| {
                if (i != 0) {
                    try self.writer.writeAll(", ");
                }
                try self.printOperand(arg_index);
            }
            try self.writer.writeByte(')');
        },
        .br => {
            const info = Value.info.br(self.ctx.*, function, value_index);
            try self.writer.writeByte(' ');
            try self.printOperand(info.cond);
            try self.writer.print(" then b{d}(", .{info.on_true.dest.toU32()});
            for (info.on_true.args, 0..) |arg_index, i| {
                if (i != 0) {
                    try self.writer.writeAll(", ");
                }
                try self.printOperand(arg_index);
            }
            try self.writer.print(") else b{d}(", .{info.on_false.dest.toU32()});
            for (info.on_false.args, 0..) |arg_index, i| {
                if (i != 0) {
                    try self.writer.writeAll(", ");
                }
                try self.printOperand(arg_index);
            }
            try self.writer.writeByte(')');
        },
        .ret => {
            const operand_opt = value_data.unary_opt;
            if (operand_opt.toIndex()) |operand| {
                try self.writer.writeByte(' ');
                try self.printOperand(operand);
            }
        },
        .block_argument, .stack_slot, .constant => unreachable,
    }
}

pub fn printType(self: *Self, ty: Type) Error!void {
    switch (ty.kind) {
        .unit => try self.writer.writeAll("unit"),
        .ptr => try self.writer.writeAll("ptr"),
        .bit => try self.writer.writeAll("bit"),
        .int8 => try self.writer.writeAll("int8"),
        .int16 => try self.writer.writeAll("int16"),
        .int32 => try self.writer.writeAll("int32"),
        .int64 => try self.writer.writeAll("int64"),
        .@"struct" => unreachable, // TODO
        .array => unreachable, // TODO
    }
}
