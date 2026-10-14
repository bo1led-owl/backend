const Self = @This();

const std = @import("std");
const Context = @import("Context.zig");
const Type = @import("types.zig").Type;
const Value = @import("Value.zig");
const BasicBlock = @import("BasicBlock.zig");
const ValueList = @import("ValueList.zig");

/// current IR context
ctx: *Context,

/// instruction list being operated on
instruction_list: *ValueList,

/// index of instruction AFTER which new instructions are inserted
/// `.none` means prepending an instruction
insertion_point: Value.IndexOpt,

pub fn initAtStart(ctx: *Context, instruction_list: *ValueList) Self {
    var res: Self = .{ .ctx = ctx, .instruction_list = undefined, .insertion_point = undefined };
    res.positionAtStart(instruction_list);
    return res;
}

pub fn initAtEnd(ctx: *Context, instruction_list: *ValueList) Self {
    var res: Self = .{ .ctx = ctx, .instruction_list = undefined, .insertion_point = undefined };
    res.positionAtEnd(instruction_list);
    return res;
}

pub fn initAfter(ctx: *Context, instruction_list: *ValueList, instruction_index: Value.Index) Self {
    var res: Self = .{ .ctx = ctx, .instruction_list = undefined, .insertion_point = undefined };
    res.positionAfter(instruction_list, instruction_index);
    return res;
}

pub fn initBefore(ctx: *Context, instruction_list: *ValueList, instruction_index: Value.Index) Self {
    var res: Self = .{ .ctx = ctx, .instruction_list = undefined, .insertion_point = undefined };
    res.positionBefore(instruction_list, instruction_index);
    return res;
}

pub fn positionAtStart(self: *Self, instruction_list: *ValueList) void {
    self.instruction_list = instruction_list;
    self.insertion_point = instruction_list.first;
}

pub fn positionAtEnd(self: *Self, instruction_list: *ValueList) void {
    self.instruction_list = instruction_list;
    self.insertion_point = instruction_list.last;
}

pub fn positionAfter(self: *Self, instruction_list: *ValueList, instruction_index: Value.Index) void {
    self.instruction_list = instruction_list;
    self.insertion_point = instruction_index.toIndexOpt();
}

pub fn positionBefore(self: *Self, instruction_list: *ValueList, instruction_index: Value.Index) void {
    self.instruction_list = instruction_list;
    self.insertion_point = self.ctx.values.items(.prev)[@backingInt(instruction_index)];
}

fn createAndInsert(self: *Self, value: Value) !Value.Index {
    const idx = try self.ctx.createValue(value);
    self.insert(idx);
    return idx;
}

fn getValueType(self: Self, idx: Value.Index) Type {
    return self.ctx.values.items(.ty)[@backingInt(idx)];
}

fn insert(self: *Self, idx: Value.Index) void {
    const nodes = self.ctx.values.slice();
    if (self.insertion_point.toIndex()) |after| {
        self.instruction_list.insertAfter(nodes, after, idx);
    } else {
        self.instruction_list.prepend(nodes, idx);
    }
}

pub fn createBlockArgument(self: *Self, ty: Type) !Value.Index {
    return self.ctx.createValue(.{ .kind = .stack_slot, .ty = ty, .prev = .none, .next = .none });
}

pub fn createStackSlot(self: *Self, ty: Type) !Value.Index {
    return self.ctx.createValue(.{ .kind = .stack_slot, .ty = ty });
}

pub fn createConstantInt(self: *Self, ty: Type, value: u64) !Value.Index {
    return self.ctx.createValue(.{
        .kind = .constant,
        .ty = ty,
        .data = .{ .constant = value },
    });
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
        .ty = .unit,
        .data = .{ .store = .{ .dest = slot, .src = value } },
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
        .ty = .unit,
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
        .ty = .unit,
        .data = .{ .br = .{
            .cond = cond,
            .extras_begin = @fromBackingInt(@intCast(prev_extras_len)),
        } },
    });
}

pub fn createRet(self: *Self, value: Value.IndexOpt) !Value.Index {
    return self.createAndInsert(.{
        .kind = .ret,
        .ty = .unit,
        .data = .{ .unary_opt = value },
    });
}
