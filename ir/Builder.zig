//! IR builder
//!
//! General conventions:
//!
//!
//! `create*` methods create a new value and add it to the appropriate container.
//! For example:
//! `createStackSlot` creates a slot and appends it to the slot of the function.
//! `createAdd` creates an addition and puts it at the insertion point of the builder, advancing the insertion point.
//!
//! `new*` methods create a new value and only store it in context.
//! For example:
//! `newBasicBlock` creates an empty basic block and nothing more.
//! `newConstantInt` creates an constant and stores it in context, not adding it anywhere.

const Builder = @This();

const std = @import("std");
const Context = @import("Context.zig");
const Type = @import("types.zig").Type;
const Value = @import("Value.zig");
const Function = @import("Function.zig");
const BasicBlock = @import("BasicBlock.zig");
const ValueList = @import("ValueList.zig");

/// Current IR context
ctx: *Context,

/// Basic block being operated on.
/// This field may be read freely, but writes should only be done using `positionAt*` methods
block: BasicBlock.Index,

/// Index of instruction AFTER which new instructions are inserted
/// `.none` means prepending an instruction
insertion_point: Value.IndexOpt,

/// Create a function with a single empty block and a builder, setting builder's insertion point at the block
pub fn initWithNewFunction(ctx: *Context, function_name: []const u8) !struct { Builder, Function.Index } {
    const function = try ctx.createFunctionWithOneBlock(function_name);
    const entry = ctx.functions.values()[function.toU32()].entry_block;

    return .{ initAtEnd(ctx, entry), function };
}

/// Create builder with insertion point before the first instruction of `block`
pub fn initAtStart(ctx: *Context, block: BasicBlock.Index) Builder {
    var res: Builder = .{
        .ctx = ctx,
        .block = undefined,
        .insertion_point = undefined,
    };
    res.positionAtStart(block);
    return res;
}

/// Create builder with insertion point after the last instruction of `block`
pub fn initAtEnd(ctx: *Context, block: BasicBlock.Index) Builder {
    var res: Builder = .{
        .ctx = ctx,
        .block = undefined,
        .insertion_point = undefined,
    };
    res.positionAtEnd(block);
    return res;
}

/// Create builder with insertion point after `instruction`.
/// `instruction` must be inside `block`
pub fn initAfter(ctx: *Context, block: BasicBlock.Index, instruction: Value.Index) Builder {
    var res: Builder = .{
        .ctx = ctx,
        .block = undefined,
        .insertion_point = undefined,
    };
    res.positionAfter(block, instruction);
    return res;
}

/// Create builder with insertion point before `instruction`.
/// `instruction` must be inside `block`
pub fn initBefore(ctx: *Context, block: BasicBlock.Index, instruction: Value.Index) Builder {
    var res: Builder = .{
        .ctx = ctx,
        .block = undefined,
        .insertion_point = undefined,
    };
    res.positionBefore(block, instruction);
    return res;
}

/// Set insertion point before the first instruction of `block`
pub fn positionAtStart(self: *Builder, block: BasicBlock.Index) void {
    self.block = block;
    self.insertion_point = self.getBlockPtr().instructions.first;
}

/// Set insertion point after the last instruction of `block`
pub fn positionAtEnd(self: *Builder, block: BasicBlock.Index) void {
    self.block = block;
    self.insertion_point = self.getBlockPtr().instructions.last;
}

/// Set insertion point after `instruction`.
/// `instruction` must be inside `block`
pub fn positionAfter(self: *Builder, block: BasicBlock.Index, instruction: Value.Index) void {
    self.block = block;

    std.debug.assert(self.getBlockPtr().instructions.contains(self.ctx.values.slice(), instruction));

    self.insertion_point = instruction.toIndexOpt();
}

/// Set insertion point before `instruction`.
/// `instruction` must be inside `block`
pub fn positionBefore(self: *Builder, block: BasicBlock.Index, instruction: Value.Index) void {
    self.block = block;

    std.debug.assert(self.getBlockPtr().instructions.contains(self.ctx.values.slice(), instruction));

    self.insertion_point = self.ctx.values.items(.prev)[instruction.toU32()];
}

fn createAndInsert(self: *Builder, value: Value) !Value.Index {
    return self.insert(try self.ctx.createValue(value));
}

fn getValueType(self: Builder, idx: Value.Index) Type {
    return self.ctx.values.items(.ty)[idx.toU32()];
}

fn getBlockPtr(self: Builder) *BasicBlock {
    return &self.ctx.blocks.items[self.block.toU32()];
}

fn insert(self: *Builder, value: Value.Index) Value.Index {
    const nodes = self.ctx.values.slice();
    const kind = nodes.items(.kind)[value.toU32()];

    if (kind.isInstruction()) {
        const instruction_list = &self.getBlockPtr().instructions;
        if (self.insertion_point.toIndex()) |after| {
            instruction_list.insertAfter(nodes, after, value);
        } else {
            instruction_list.prepend(nodes, value);
        }
        self.insertion_point = value.toIndexOpt();
    }

    return value;
}

pub fn newBasicBlock(self: *Builder) !BasicBlock.Index {
    return self.ctx.createBasicBlock(.empty);
}

pub fn createBlockArgument(self: *Builder, ty: Type) !Value.Index {
    const res = try self.ctx.createValue(.{ .kind = .block_argument, .ty = ty });
    const arguments = &self.getBlockPtr().arguments;
    arguments.append(self.ctx.values.slice(), res);
    return res;
}

pub fn createStackSlot(self: *Builder, in: Function.Index, ty: Type) !Value.Index {
    const res = try self.ctx.createValue(.{ .kind = .stack_slot, .ty = ty });
    const function: *Function = &self.ctx.functions.values()[in.toU32()];
    function.stack_slots.append(self.ctx.values.slice(), res);
    return res;
}

pub fn newConstantInt(self: *Builder, ty: Type, value: u64) !Value.Index {
    return self.ctx.createValue(.{ .kind = .constant, .ty = ty, .data = .{ .constant = value } });
}

pub fn createTruncate(self: *Builder, value: Value.Index, to: Type) !Value.Index {
    return self.createAndInsert(.{
        .kind = .truncate,
        .ty = to,
        .data = .{ .unary = value },
    });
}

pub fn createSignExtend(self: *Builder, value: Value.Index, to: Type) !Value.Index {
    return self.createAndInsert(.{
        .kind = .sign_extend,
        .ty = to,
        .data = .{ .unary = value },
    });
}

pub fn createZeroExtend(self: *Builder, value: Value.Index, to: Type) !Value.Index {
    return self.createAndInsert(.{
        .kind = .zero_extend,
        .ty = to,
        .data = .{ .unary = value },
    });
}

pub fn createNegate(self: *Builder, value: Value.Index) !Value.Index {
    const ty = self.getValueType(value);
    return self.createAndInsert(.{
        .kind = .negate,
        .ty = ty,
        .data = .{ .unary = value },
    });
}

pub fn createAdd(self: *Builder, lhs: Value.Index, rhs: Value.Index) !Value.Index {
    const ty = self.getValueType(lhs);
    return self.createAndInsert(.{
        .kind = .add,
        .ty = ty,
        .data = .{ .binary = .{ .lhs = lhs, .rhs = rhs } },
    });
}

pub fn createSub(self: *Builder, lhs: Value.Index, rhs: Value.Index) !Value.Index {
    const ty = self.getValueType(lhs);
    return self.createAndInsert(.{
        .kind = .add,
        .ty = ty,
        .data = .{ .binary = .{ .lhs = lhs, .rhs = rhs } },
    });
}

pub fn createMul(self: *Builder, lhs: Value.Index, rhs: Value.Index) !Value.Index {
    const ty = self.getValueType(lhs);
    return self.createAndInsert(.{
        .kind = .add,
        .ty = ty,
        .data = .{ .binary = .{ .lhs = lhs, .rhs = rhs } },
    });
}

pub fn createDivSigned(self: *Builder, lhs: Value.Index, rhs: Value.Index) !Value.Index {
    const ty = self.getValueType(lhs);
    return self.createAndInsert(.{
        .kind = .sdiv,
        .ty = ty,
        .data = .{ .binary = .{ .lhs = lhs, .rhs = rhs } },
    });
}

pub fn createDivUnsigned(self: *Builder, lhs: Value.Index, rhs: Value.Index) !Value.Index {
    const ty = self.getValueType(lhs);
    return self.createAndInsert(.{
        .kind = .udiv,
        .ty = ty,
        .data = .{ .binary = .{ .lhs = lhs, .rhs = rhs } },
    });
}

pub const CmpPredicate = enum { eq, ne, slt, sgt, sle, sge, ult, ugt, ule, uge };

pub fn createCmp(self: *Builder, predicate: CmpPredicate, lhs: Value.Index, rhs: Value.Index) !Value.Index {
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

pub fn createStackLoad(self: *Builder, slot: Value.Index) !Value.Index {
    const ty = self.getValueType(slot);
    return self.createAndInsert(.{
        .kind = .stack_load,
        .ty = ty,
        .data = .{ .unary = slot },
    });
}

pub fn createStackStore(self: *Builder, slot: Value.Index, value: Value.Index) !Value.Index {
    return self.createAndInsert(.{
        .kind = .stack_store,
        .ty = .{ .kind = .unit },
        .data = .{ .store = .{ .dest = slot, .src = value } },
    });
}

pub fn createStackAddress(self: *Builder, slot: Value.Index) !Value.Index {
    return self.createAndInsert(.{
        .kind = .stack_address,
        .ty = .{ .kind = .ptr },
        .data = .{ .unary = slot },
    });
}

pub fn createLoad(self: *Builder, ty: Type, from: Value.Index) !Value.Index {
    return self.createAndInsert(.{
        .kind = .load,
        .ty = ty,
        .data = .{ .unary = from },
    });
}

pub fn createStore(self: *Builder, dest: Value.Index, src: Value.Index) !Value.Index {
    return self.createAndInsert(.{
        .kind = .store,
        .ty = .{ .kind = .unit },
        .data = .{ .store = .{ .dest = dest, .src = src } },
    });
}

pub fn createJump(self: *Builder, dest: BasicBlock.Index, arguments: []const Value.Index) !Value.Index {
    const prev_extras_len = self.ctx.extras.items.len;

    try self.ctx.reserveExtras(arguments.len);
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
    self: *Builder,
    cond: Value.Index,
    on_true: BasicBlock.Index,
    on_true_args: []const Value.Index,
    on_false: BasicBlock.Index,
    on_false_args: []const Value.Index,
) !Value.Index {
    const prev_extras_len = self.ctx.extras.items.len;

    const added_extras = 2 + on_false_args.len + on_false_args.len;
    try self.ctx.reserveExtras(added_extras);
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

pub fn createRet(self: *Builder, value: Value.Index) !Value.Index {
    return self.createAndInsert(.{
        .kind = .ret,
        .ty = .{ .kind = .unit },
        .data = .{ .unary_opt = value.toIndexOpt() },
    });
}

pub fn createRetVoid(self: *Builder) !Value.Index {
    return self.createAndInsert(.{
        .kind = .ret,
        .ty = .{ .kind = .unit },
        .data = .{ .unary_opt = .none },
    });
}

test "basic usage" {
    const gpa = std.testing.allocator;

    var ctx: Context = .init(gpa);
    defer ctx.deinit();

    var builder, _ = try Builder.initWithNewFunction(&ctx, "main");
    const entry_block_idx = builder.block;

    const int32: Type = .{ .kind = .int32 };

    const a = try builder.createBlockArgument(int32);
    const b = try builder.createBlockArgument(int32);
    const add = try builder.createAdd(a, b);

    const const2 = try builder.newConstantInt(int32, 2);
    const udiv = try builder.createDivUnsigned(add, const2);
    const ret = try builder.createRet(udiv);

    const expected_instructions: []const Value = &.{
        .{
            .kind = .add,
            .ty = int32,
            .data = .{ .binary = .{ .lhs = a, .rhs = b } },
            .prev = .none,
            .next = udiv.toIndexOpt(),
        },
        .{
            .kind = .udiv,
            .ty = int32,
            .data = .{ .binary = .{ .lhs = add, .rhs = const2 } },
            .prev = add.toIndexOpt(),
            .next = ret.toIndexOpt(),
        },
        .{
            .kind = .ret,
            .ty = .{ .kind = .unit },
            .data = .{ .unary_opt = udiv.toIndexOpt() },
            .prev = udiv.toIndexOpt(),
            .next = .none,
        },
    };

    var actual_inst_idx = ctx.blocks.items[entry_block_idx.toU32()].instructions.first;
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

            try std.testing.expectEqual(expected.prev, actual.prev);
            try std.testing.expectEqual(expected.next, actual.next);

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
