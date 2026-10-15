const Self = @This();

const std = @import("std");
const Context = @import("Context.zig");
const Type = @import("types.zig").Type;
const Value = @import("Value.zig");
const Function = @import("Function.zig");
const BasicBlock = @import("BasicBlock.zig");
const ValueList = @import("ValueList.zig");

/// current IR context
ctx: *Context,

/// function being operated on
function: *Function,

/// basic block being operated on
block: BasicBlock.Index,

/// index of instruction AFTER which new instructions are inserted
/// `.none` means prepending an instruction
insertion_point: Value.IndexOpt,

pub fn initAtStart(ctx: *Context, function: *Function, block: BasicBlock.Index) Self {
    var res: Self = .{
        .ctx = ctx,
        .function = undefined,
        .block = undefined,
        .insertion_point = undefined,
    };
    res.positionAtStart(function, block);
    return res;
}

pub fn initAtEnd(ctx: *Context, function: *Function, block: BasicBlock.Index) Self {
    var res: Self = .{
        .ctx = ctx,
        .function = undefined,
        .block = undefined,
        .insertion_point = undefined,
    };
    res.positionAtEnd(function, block);
    return res;
}

pub fn initAfter(ctx: *Context, function: *Function, block: BasicBlock.Index, instruction_index: Value.Index) Self {
    var res: Self = .{
        .ctx = ctx,
        .function = function,
        .block = block,
        .insertion_point = undefined,
    };
    res.positionAfter(function, block, instruction_index);
    return res;
}

pub fn initBefore(ctx: *Context, function: *Function, block: BasicBlock.Index, instruction_index: Value.Index) Self {
    var res: Self = .{
        .ctx = ctx,
        .function = function,
        .block = block,
        .insertion_point = undefined,
    };
    res.positionBefore(function, block, instruction_index);
    return res;
}

pub fn positionAtStart(self: *Self, function: *Function, block: BasicBlock.Index) void {
    self.function = function;
    self.block = block;
    self.insertion_point = function.blocks.items[@backingInt(block)].instructions.first;
}

pub fn positionAtEnd(self: *Self, function: *Function, block: BasicBlock.Index) void {
    self.function = function;
    self.block = block;
    self.insertion_point = function.blocks.items[@backingInt(block)].instructions.last;
}

pub fn positionAfter(self: *Self, function: *Function, block: BasicBlock.Index, instruction_index: Value.Index) void {
    self.function = function;
    self.block = block;
    self.insertion_point = instruction_index.toIndexOpt();
}

pub fn positionBefore(self: *Self, function: *Function, block: BasicBlock.Index, instruction_index: Value.Index) void {
    self.function = function;
    self.block = block;
    self.insertion_point = self.ctx.values.items(.prev)[instruction_index.toU32()];
}

fn createAndInsert(self: *Self, value: Value) !Value.Index {
    return self.insert(try self.ctx.createValue(value));
}

fn getValueType(self: Self, idx: Value.Index) Type {
    return self.ctx.values.items(.ty)[idx.toU32()];
}

pub fn insert(self: *Self, idx: Value.Index) Value.Index {
    const nodes = self.ctx.values.slice();
    const kind = nodes.items(.kind)[idx.toU32()];
    if (kind.isInstruction()) {
        const instruction_list = &self.function.blocks.items[@backingInt(self.block)].instructions;
        if (self.insertion_point.toIndex()) |after| {
            instruction_list.insertAfter(nodes, after, idx);
        } else {
            instruction_list.prepend(nodes, idx);
        }
        self.insertion_point = idx.toIndexOpt();
    }

    return idx;
}

pub fn createBlockArgument(self: *Self, ty: Type) !Value.Index {
    const res = try self.ctx.createValue(.{ .kind = .block_argument, .ty = ty, .prev = .none, .next = .none });
    self.function.blocks.items[@backingInt(self.block)].arguments.append(self.ctx.values.slice(), res);
    return res;
}

pub fn newStackSlot(self: *Self, ty: Type) !Value.Index {
    return self.ctx.createValue(.{ .kind = .stack_slot, .ty = ty });
}

pub fn newConstantInt(self: *Self, ty: Type, value: u64) !Value.Index {
    return self.ctx.createValue(.{ .kind = .constant, .ty = ty, .data = .{ .constant = value } });
}

pub fn createTruncate(self: *Self, value: Value.Index, to: Type) !Value.Index {
    return self.createAndInsert(.{
        .kind = .truncate,
        .ty = to,
        .data = .{ .unary = value },
    });
}

pub fn createSignExtend(self: *Self, value: Value.Index, to: Type) !Value.Index {
    return self.createAndInsert(.{
        .kind = .sign_extend,
        .ty = to,
        .data = .{ .unary = value },
    });
}

pub fn createZeroExtend(self: *Self, value: Value.Index, to: Type) !Value.Index {
    return self.createAndInsert(.{
        .kind = .zero_extend,
        .ty = to,
        .data = .{ .unary = value },
    });
}

pub fn createNegate(self: *Self, value: Value.Index) !Value.Index {
    const ty = self.getValueType(value);
    return self.createAndInsert(.{
        .kind = .negate,
        .ty = ty,
        .data = .{ .unary = value },
    });
}

pub fn createAdd(self: *Self, lhs: Value.Index, rhs: Value.Index) !Value.Index {
    const ty = self.getValueType(lhs);
    return self.createAndInsert(.{
        .kind = .add,
        .ty = ty,
        .data = .{ .binary = .{ .lhs = lhs, .rhs = rhs } },
    });
}

pub fn createSub(self: *Self, lhs: Value.Index, rhs: Value.Index) !Value.Index {
    const ty = self.getValueType(lhs);
    return self.createAndInsert(.{
        .kind = .add,
        .ty = ty,
        .data = .{ .binary = .{ .lhs = lhs, .rhs = rhs } },
    });
}

pub fn createMul(self: *Self, lhs: Value.Index, rhs: Value.Index) !Value.Index {
    const ty = self.getValueType(lhs);
    return self.createAndInsert(.{
        .kind = .add,
        .ty = ty,
        .data = .{ .binary = .{ .lhs = lhs, .rhs = rhs } },
    });
}

pub fn createDivSigned(self: *Self, lhs: Value.Index, rhs: Value.Index) !Value.Index {
    const ty = self.getValueType(lhs);
    return self.createAndInsert(.{
        .kind = .sdiv,
        .ty = ty,
        .data = .{ .binary = .{ .lhs = lhs, .rhs = rhs } },
    });
}

pub fn createDivUnsigned(self: *Self, lhs: Value.Index, rhs: Value.Index) !Value.Index {
    const ty = self.getValueType(lhs);
    return self.createAndInsert(.{
        .kind = .udiv,
        .ty = ty,
        .data = .{ .binary = .{ .lhs = lhs, .rhs = rhs } },
    });
}

pub const CmpPredicate = enum { eq, ne, slt, sgt, sle, sge, ult, ugt, ule, uge };

pub fn createCmp(self: *Self, predicate: CmpPredicate, lhs: Value.Index, rhs: Value.Index) !Value.Index {
    const kind: Value.Kind = switch (predicate) {
        .eq => .cmp_eq,
        .ne => .cmp_ne,
        .slt => .cmp_slt,
        .sgt => .cmp_sgt,
        .sle => .cmp_sle,
        .sge => .cmp_sge,
        .ult => .cmp_ult,
        .ugt => .cmp_ugt,
        .ule => .cmp_ule,
        .uge => .cmp_uge,
    };
    return self.createAndInsert(.{
        .kind = kind,
        .ty = .{ .kind = .bit },
        .data = .{ .binary = .{ .lhs = lhs, .rhs = rhs } },
    });
}

pub fn createStackLoad(self: *Self, slot: Value.Index) !Value.Index {
    const ty = self.getValueType(slot);
    return self.createAndInsert(.{
        .kind = .stack_load,
        .ty = ty,
        .data = .{ .unary = slot },
    });
}

pub fn createStackStore(self: *Self, slot: Value.Index, value: Value.Index) !Value.Index {
    return self.createAndInsert(.{
        .kind = .stack_store,
        .ty = .{ .kind = .unit },
        .data = .{ .store = .{ .dest = slot, .src = value } },
    });
}

pub fn createStackAddress(self: *Self, slot: Value.Index) !Value.Index {
    return self.createAndInsert(.{
        .kind = .stack_address,
        .ty = .{ .kind = .ptr },
        .data = .{ .unary = slot },
    });
}

pub fn createLoad(self: *Self, ty: Type, from: Value.Index) !Value.Index {
    return self.createAndInsert(.{
        .kind = .load,
        .ty = ty,
        .data = .{ .unary = from },
    });
}

pub fn createStore(self: *Self, dest: Value.Index, src: Value.Index) !Value.Index {
    return self.createAndInsert(.{
        .kind = .store,
        .ty = .{ .kind = .unit },
        .data = .{ .store = .{ .dest = dest, .src = src } },
    });
}

pub fn createJump(self: *Self, dest: BasicBlock.Index, arguments: []const Value.Index) !Value.Index {
    const prev_extras_len = self.ctx.extras.items.len;

    try self.ctx.reserveExtras(self.ctx.gpa, arguments.len);
    errdefer self.ctx.extras.shrinkRetainingCapacity(prev_extras_len);

    self.ctx.extras.appendSliceAssumeCapacity(@ptrCast(arguments));

    return self.createAndInsert(.{
        .kind = .jump,
        .ty = .{ .kind = .unit },
        .data = .{ .jump = .{
            .dest = dest,
            .first_arg = @fromBackingInt(@intCast(prev_extras_len)),
        } },
    });
}

pub fn createBr(
    self: *Self,
    cond: Value.Index,
    on_true: BasicBlock.Index,
    on_true_args: []const Value.Index,
    on_false: BasicBlock.Index,
    on_false_args: []const Value.Index,
) !Value.Index {
    const prev_extras_len = self.ctx.extras.items.len;

    const added_extras = 2 + on_false_args.len + on_false_args.len;
    try self.ctx.reserveExtras(self.ctx.gpa, added_extras);
    errdefer self.ctx.extras.shrinkRetainingCapacity(prev_extras_len);

    self.ctx.extras.appendAssumeCapacity(@bitCast(on_true));
    self.ctx.extras.appendSliceAssumeCapacity(@ptrCast(on_true_args));
    self.ctx.extras.appendAssumeCapacity(@bitCast(on_false));
    self.ctx.extras.appendSliceAssumeCapacity(@ptrCast(on_false_args));

    return self.createAndInsert(.{
        .kind = .br,
        .ty = .{ .kind = .unit },
        .data = .{ .br = .{
            .cond = cond,
            .extras_begin = @fromBackingInt(@intCast(prev_extras_len)),
        } },
    });
}

pub fn createRet(self: *Self, value: Value.Index) !Value.Index {
    return self.createAndInsert(.{
        .kind = .ret,
        .ty = .{ .kind = .unit },
        .data = .{ .unary_opt = value.toIndexOpt() },
    });
}

pub fn createRetVoid(self: *Self) !Value.Index {
    return self.createAndInsert(.{
        .kind = .ret,
        .ty = .{ .kind = .unit },
        .data = .{ .unary_opt = .none },
    });
}

test "basic usage" {
    const ir = @import("ir.zig");
    const gpa = std.testing.allocator;

    var ctx: ir.Context = .init(gpa);
    defer ctx.deinit();

    var function: ir.Function = .empty;
    defer function.deinit(ctx);

    const entry_block_idx = try function.addBlock(ctx, .empty);

    var builder: ir.Builder = .initAtStart(&ctx, &function, entry_block_idx);

    const int32: ir.Type = .{ .kind = .int32 };

    const a = try builder.createBlockArgument(int32);
    const b = try builder.createBlockArgument(int32);
    const add = try builder.createAdd(a, b);

    const const2 = try builder.newConstantInt(int32, 2);
    const udiv = try builder.createDivUnsigned(add, const2);
    _ = try builder.createRet(udiv);

    const expected_instructions: []const ir.Value = &.{
        .{ .kind = .add, .ty = int32, .data = .{ .binary = .{ .lhs = a, .rhs = b } } },
        .{ .kind = .udiv, .ty = int32, .data = .{ .binary = .{ .lhs = add, .rhs = const2 } } },
        .{ .kind = .ret, .ty = .{ .kind = .unit }, .data = .{ .unary_opt = udiv.toIndexOpt() } },
    };

    var actual_inst_idx = function.blocks.items[@backingInt(entry_block_idx)].instructions.first;
    for (expected_instructions, 0..) |expected, i| {
        if (actual_inst_idx.toU32()) |inst_index| {
            const actual = ctx.values.get(inst_index);

            try std.testing.expectEqual(expected.kind, actual.kind);
            try std.testing.expectEqual(expected.ty, actual.ty);

            switch (actual.kind) {
                .add, .udiv => try std.testing.expectEqualDeep(expected.data.binary, actual.data.binary),
                .ret => try std.testing.expectEqual(expected.data.unary_opt, actual.data.unary_opt),
                else => unreachable,
            }

            actual_inst_idx = actual.next;
        } else {
            std.testing.failPrint(
                "actual function body is shorter than expected: {d} < {d}",
                .{ i, expected_instructions.len },
            );
            return;
        }
    }
}
