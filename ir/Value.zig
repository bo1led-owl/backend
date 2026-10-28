const Value = @This();

const std = @import("std");
const Context = @import("Context.zig");
const BasicBlock = @import("BasicBlock.zig");
const Type = @import("types.zig").Type;
const Function = @import("Function.zig");

pub const Index = enum(u32) {
    _,

    pub fn toU32(self: Value.Index) u32 {
        return @backingInt(self);
    }

    pub fn toIndexOpt(self: Value.Index) Value.IndexOpt {
        std.debug.assert(@backingInt(self) != @backingInt(IndexOpt.none));
        return @fromBackingInt(@backingInt(self));
    }
};

pub const IndexOpt = enum(u32) {
    none = std.math.maxInt(u32),
    _,

    pub fn toU32(self: Value.IndexOpt) ?u32 {
        if (self == .none) {
            return null;
        }
        return @backingInt(self);
    }

    pub fn toIndex(self: Value.IndexOpt) ?Value.Index {
        if (self == .none) {
            return null;
        }
        return @fromBackingInt(@backingInt(self));
    }
};

kind: Kind,
ty: Type,
data: Data = undefined,
prev: Value.IndexOpt = .none,
next: Value.IndexOpt = .none,

pub const Kind = enum(u8) {
    /// reference to a block argument
    block_argument,
    /// a dedicated stack slot
    stack_slot,
    /// integer constant
    /// `data` is `constant`
    constant,
    /// truncation instruction
    /// `data` is `unary`
    truncate,
    /// sign extend instruction
    /// `data` is `unary`
    sign_extend,
    /// zero extend instruction
    /// `data` is `unary`
    zero_extend,
    /// negation instruction
    /// `data` is `unary`
    negate,
    /// addition instruction
    /// `data` is `binary`
    add,
    /// subtraction instruction
    /// `data` is `binary`
    sub,
    /// multiplication instruction
    /// `data` is `binary`
    mul,
    /// signed division instruction
    /// `data` is `binary`
    sdiv,
    /// unsigned division instruction
    /// `data` is `binary`
    udiv,
    /// equality comparison instruction
    /// `data` is `binary`
    cmp_eq,
    /// inequality comparison instruction
    /// `data` is `binary`
    cmp_ne,
    /// signed less-than comparison instruction
    /// `data` is `binary`
    cmp_slt,
    /// signed greater-than comparison instruction
    /// `data` is `binary`
    cmp_sgt,
    /// signed less-than-or-equal comparison instruction
    /// `data` is `binary`
    cmp_sle,
    /// signed greater-than-or-equal comparison instruction
    /// `data` is `binary`
    cmp_sge,
    /// unsigned less-than comparison instruction
    /// `data` is `binary`
    cmp_ult,
    /// unsigned greater-than comparison instruction
    /// `data` is `binary`
    cmp_ugt,
    /// unsigned less-than-or-equal comparison instruction
    /// `data` is `binary`
    cmp_ule,
    /// unsigned greater-than-or-equal comparison instruction
    /// `data` is `binary`
    cmp_uge,
    /// load from a stack slot instruction
    /// `data` is `unary`
    stack_load,
    /// store into a stack slot instruction
    /// `data` is `store`
    stack_store,
    /// take address of a stack slot instruction
    /// `data` is `unary`
    stack_address,
    /// load instruction
    /// `data` is `unary`
    load,
    /// store instruction
    /// `data` is `store`
    store,
    /// jump instruction
    /// `data` is `jump`
    jump,
    /// branch instruction
    /// `data` is `br`
    br,
    /// return instruction
    /// `data` is `unary_opt`
    ret,

    pub fn isInstruction(self: Kind) bool {
        return switch (self) {
            .truncate,
            .sign_extend,
            .zero_extend,
            .negate,
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
            .stack_load,
            .stack_store,
            .stack_address,
            .load,
            .store,
            .jump,
            .br,
            .ret,
            => true,
            .block_argument, .stack_slot, .constant => false,
        };
    }
};

pub const Data = union {
    constant: u64,
    unary: Value.Index,
    unary_opt: Value.IndexOpt,
    binary: struct { lhs: Value.Index, rhs: Value.Index },
    store: struct { dest: Value.Index, src: Value.Index },
    jump: struct {
        // extras format: [args...]
        dest: BasicBlock.Index,
        first_arg: Context.ExtraIndex,
    },
    br: struct {
        // extras format: [dest_true, args_true..., dest_false, args_false...]
        cond: Value.Index,
        extras_begin: Context.ExtraIndex,
    },
};

pub const info = struct {
    pub const Jump = struct {
        dest: BasicBlock.Index,
        args: []const Value.Index,
    };

    pub const Br = struct {
        cond: Value.Index,
        on_true: Jump,
        on_false: Jump,
    };

    pub fn jump(ctx: Context, function: Function, value: Value.Index) Jump {
        std.debug.assert(ctx.values.items(.kind)[value.toU32()] == .jump);

        const data = ctx.values.items(.data)[value.toU32()].jump;
        const dest = data.dest;
        const args: []const Value.Index = @ptrCast(ctx.getExtras(.{
            .begin = data.first_arg,
            .len = function.blocks.items[dest.toU32()].arguments.len(ctx.values.slice()),
        }));

        return .{ .dest = dest, .args = args };
    }

    pub fn br(ctx: Context, function: Function, value: Value.Index) Br {
        std.debug.assert(ctx.values.items(.kind)[value.toU32()] == .br);

        const data = ctx.values.items(.data)[value.toU32()].br;

        const on_true_dest: BasicBlock.Index = @fromBackingInt(ctx.extras.items[data.extras_begin.toU32()]);
        const on_true_n_args = function.blocks.items[on_true_dest.toU32()].arguments.len(ctx.values.slice());
        const on_true_args: []const Value.Index = @ptrCast(ctx.getExtras(.{
            .begin = @fromBackingInt(data.extras_begin.toU32() + 1),
            .len = on_true_n_args,
        }));
        const on_false_dest: BasicBlock.Index =
            @fromBackingInt(ctx.extras.items[data.extras_begin.toU32() + on_true_n_args + 1]);
        const on_false_args: []const Value.Index = @ptrCast(ctx.getExtras(.{
            .begin = @fromBackingInt(data.extras_begin.toU32() + on_true_n_args + 2),
            .len = function.blocks.items[on_false_dest.toU32()].arguments.len(ctx.values.slice()),
        }));

        return .{
            .cond = data.cond,
            .on_true = .{
                .dest = on_true_dest,
                .args = on_true_args,
            },
            .on_false = .{
                .dest = on_false_dest,
                .args = on_false_args,
            },
        };
    }
};
