const std = @import("std");

pub fn index(comptime Marker: type, comptime Repr: type) type {
    return enum(Repr) {
        _,

        const marker = Marker;

        pub fn toInt(self: @This()) Repr {
            return @backingInt(self);
        }
    };
}

pub fn indexAndIndexOpt(comptime Marker: type, comptime Repr: type) struct { type, type } {
    const Tmp = struct {
        pub const Index = enum(Repr) {
            _,

            const marker = Marker;

            pub fn toInt(self: @This()) Repr {
                return @backingInt(self);
            }

            pub fn toIndexOpt(self: @This()) IndexOpt {
                std.debug.assert(@backingInt(self) != @backingInt(IndexOpt.none));
                return @fromBackingInt(@backingInt(self));
            }
        };

        pub const IndexOpt = enum(Repr) {
            none = std.math.maxInt(Repr),
            _,

            const marker = Marker;

            pub fn toInt(self: @This()) ?Repr {
                if (self == .none) {
                    return null;
                }
                return @backingInt(self);
            }

            pub fn toIndex(self: @This()) ?Index {
                if (self == .none) {
                    return null;
                }
                return @fromBackingInt(@backingInt(self));
            }
        };
    };

    return .{ Tmp.Index, Tmp.IndexOpt };
}
