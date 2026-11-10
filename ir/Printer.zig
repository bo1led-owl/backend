const Self = @This();

const std = @import("std");
const Context = @import("Context.zig");
const Type = @import("Type.zig");
const Value = @import("Value.zig");
const Function = @import("Function.zig");
const BasicBlock = @import("BasicBlock.zig");

ctx: *const Context,
writer: *std.Io.Writer,
depth: u32 = 0,
cur_block_args: ?Value.List = null,
indentation: u8 = 2,

pub const Error = std.Io.Writer.Error;

pub const IndentationOption = union(enum) {
    default,
    custom: u8,
};
pub fn init(ctx: *const Context, writer: *std.Io.Writer, indent: IndentationOption) Self {
    return .{
        .ctx = ctx,
        .writer = writer,
        .indentation = switch (indent) {
            .default => 2,
            .custom => |n| n,
        },
    };
}

fn makeIndentation(self: *Self) !void {
    try self.writer.splatByteAll(' ', self.depth * self.indentation);
}

pub fn printFunction(self: *Self, name: []const u8, function: Function) Error!void {
    try self.writer.print("{s}(", .{name});

    const full_type = self.ctx.getFullType(function.ty).data.function;
    for (self.ctx.getTypeExtras(full_type.params), 0..) |param_type, i| {
        if (i != 0) {
            try self.writer.writeAll(", ");
        }
        try self.printType(param_type);
    }
    try self.writer.writeAll(") -> ");
    try self.printType(full_type.rettype);
    try self.writer.writeAll(" {\n");

    self.depth += 1;
    defer self.depth -= 1;

    try self.makeIndentation();
    try self.writer.writeAll("stack slots: [");

    if (!function.stack_slots.isEmpty()) {
        var iter = function.stack_slots.iterator(self.ctx.values.slice());
        var first = true;
        while (iter.next()) |value_idx| {
            defer first = false;
            if (!first) {
                try self.writer.writeAll(", ");
            }

            const slot_type = self.ctx.values.items(.ty)[value_idx.toInt()];
            try self.writer.print("v{d}: ", .{value_idx.toInt()});
            try self.printType(slot_type);
        }
    }
    try self.writer.writeAll("]\n");

    var block_iter = function.blocks.iterator(self.ctx.blocks.slice());
    while (block_iter.next()) |bb_index| {
        try self.makeIndentation();
        try self.writer.print("b{d}(", .{bb_index.toInt()});
        const bb = self.ctx.blocks.get(bb_index.toInt());
        {
            var iter = bb.arguments.iterator(self.ctx.values.slice());
            var first = true;
            while (iter.next()) |value_idx| {
                defer first = false;
                if (!first) {
                    try self.writer.writeAll(", ");
                }

                const arg_type = self.ctx.values.items(.ty)[value_idx.toInt()];
                try self.writer.print("v{d}: ", .{value_idx.toInt()});
                try self.printType(arg_type);
            }
            try self.writer.writeAll("):\n");
        }

        self.cur_block_args = bb.arguments;
        defer self.cur_block_args = null;

        self.depth += 1;
        defer self.depth -= 1;

        var iter = bb.instructions.iterator(self.ctx.values.slice());
        while (iter.next()) |value_idx| {
            try self.makeIndentation();
            try self.printInstruction(value_idx);
            try self.writer.writeByte('\n');
        }
    }

    try self.writer.writeAll("}\n");
}

pub fn printOperand(self: *Self, v: Value.Index) Error!void {
    switch (self.ctx.values.items(.kind)[v.toInt()]) {
        .constant => {
            const value = self.ctx.values.items(.data)[v.toInt()].constant;
            try self.writer.print("{d}", .{value});
        },
        .function_ref => {
            const function_index = self.ctx.values.items(.data)[v.toInt()].function;
            const function_name = self.ctx.functions.keys()[function_index.toInt()];
            try self.writer.print("{s}", .{function_name});
        },
        else => try self.writer.print("v{d}", .{v.toInt()}),
    }
}

pub fn printInstruction(self: *Self, value_index: Value.Index) Error!void {
    const value_type = self.ctx.values.items(.ty)[value_index.toInt()];
    if (value_type.kind != .unit) {
        try self.writer.print("v{d}: ", .{value_index.toInt()});
        try self.printType(value_type);
        try self.writer.writeAll(" = ");
    }

    const value_kind = self.ctx.values.items(.kind)[value_index.toInt()];

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
            .call => "call",
            .function_ref, .block_argument, .stack_slot, .constant => unreachable,
        };

    try self.writer.writeAll(mnemonic);

    const value_data = self.ctx.values.items(.data)[value_index.toInt()];
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
            const info = Value.info.jump(self.ctx.*, value_index);
            try self.writer.print(" b{d}(", .{info.dest.toInt()});
            for (info.args, 0..) |arg_index, i| {
                if (i != 0) {
                    try self.writer.writeAll(", ");
                }
                try self.printOperand(arg_index);
            }
            try self.writer.writeByte(')');
        },
        .call => {
            const info = Value.info.call(self.ctx.*, value_index);

            try self.writer.writeByte(' ');
            try self.printOperand(info.callee);

            try self.writer.writeAll(" (");
            for (info.args, 0..) |arg_index, i| {
                if (i != 0) {
                    try self.writer.writeAll(", ");
                }
                try self.printOperand(arg_index);
            }
            try self.writer.writeByte(')');
        },
        .br => {
            const info = Value.info.br(self.ctx.*, value_index);
            try self.writer.writeByte(' ');
            try self.printOperand(info.cond);
            try self.writer.print(" then b{d}(", .{info.on_true.dest.toInt()});
            for (info.on_true.args, 0..) |arg_index, i| {
                if (i != 0) {
                    try self.writer.writeAll(", ");
                }
                try self.printOperand(arg_index);
            }
            try self.writer.print(") else b{d}(", .{info.on_false.dest.toInt()});
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
        .function_ref, .block_argument, .stack_slot, .constant => unreachable,
    }
}

pub fn printType(self: *Self, ty: Type.Handle) Error!void {
    switch (ty.kind) {
        .unit => try self.writer.writeAll("unit"),
        .ptr => try self.writer.writeAll("ptr"),
        .bit => try self.writer.writeAll("bit"),
        .int8 => try self.writer.writeAll("int8"),
        .int16 => try self.writer.writeAll("int16"),
        .int32 => try self.writer.writeAll("int32"),
        .int64 => try self.writer.writeAll("int64"),
        .function => {
            const full_ty = self.ctx.getFullFunctionType(ty.aggregate_index);
            const params = self.ctx.getTypeExtras(full_ty.params);

            try self.writer.writeByte('(');
            for (params, 0..) |param, i| {
                if (i > 0) {
                    try self.writer.writeAll(", ");
                }

                try self.printType(param);
            }
            try self.writer.writeAll(") -> ");
            try self.printType(full_ty.rettype);
        },
        .@"struct" => {
            const full_ty = self.ctx.getFullStructType(ty.aggregate_index);

            if (full_ty.fields.len == 0) {
                try self.writer.writeAll("struct {}");
                return;
            }

            const fields = self.ctx.getTypeExtras(full_ty.fields);

            try self.writer.writeAll("struct { ");
            for (fields, 0..) |field, i| {
                if (i > 0) {
                    try self.writer.writeAll(", ");
                }

                try self.printType(field);
            }
            try self.writer.writeAll(" }");
        },
        .array => {
            const full_ty = self.ctx.getFullArrayType(ty.aggregate_index);
            try self.writer.print("[{d}]", .{full_ty.size});
            try self.printType(full_ty.element_type);
        },
    }
}
