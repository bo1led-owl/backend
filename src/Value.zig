const Value = @This();

const std = @import("std");
const Context = @import("Context.zig");
const BasicBlock = @import("BasicBlock.zig");
const Type = @import("types.zig").Type;

pub const Index = enum(u32) {
    _,

    pub fn toIndexOpt(self: Value.Index) Value.IndexOpt {
        std.debug.assert(@backingInt(self) != @backingInt(IndexOpt.none));
        return @fromBackingInt(@intCast(@backingInt(self)));
    }
};

pub const IndexOpt = enum(u32) {
    none = std.math.maxInt(u32),
    _,

    pub fn toIndex(self: Value.IndexOpt) ?Value.Index {
        if (self == .none) {
            return null;
        }
        return @fromBackingInt(@intCast(@backingInt(self)));
    }
};

kind: Kind,
ty: Type,
data: Data = undefined,
prev: Value.IndexOpt = undefined,
next: Value.IndexOpt = undefined,

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
    /// singed extend instruction
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
    cmp_sne,
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

    // pub fn is_instruction(self: Kind) bool {
    //     return switch (self) {
    //         .truncate,
    //         .sign_extend,
    //         .zero_extend,
    //         .negate,
    //         .add,
    //         .sub,
    //         .mul,
    //         .div,
    //         .cmp_eq,
    //         .cmp_ne,
    //         .cmp_lt,
    //         .cmp_gt,
    //         .cmp_le,
    //         .cmp_ge,
    //         .stack_load,
    //         .stack_store,
    //         .stack_address,
    //         .load,
    //         .store,
    //         .jump,
    //         .br,
    //         .ret,
    //         => true,
    //         .block_argument, .stack_slot, .constant => false,
    //     };
    // }
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
