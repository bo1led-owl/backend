const std = @import("std");

// TODO: add to context later
pub const AggregateTypeStorage = struct {
    structs: std.ArrayList([]const Type),
    arrays: std.ArrayList(struct { size: usize, element_type: Type }),
};

pub const Type = packed struct(u32) {
    kind: Kind,
    aggregate_index: u28 = undefined,

    pub const Kind = enum(u4) {
        unit,
        ptr,
        bit,
        int8,
        int16,
        int32,
        int64,
        @"struct",
        array,
    };
};
